import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'local_cache.dart';
import 'repository.dart';

/// Wraps [Repository] with a copy of the user's data on the device, so notes
/// open and save without a connection.
///
/// Every write lands in the local cache first and goes into an outbox. The
/// outbox is sent to Supabase in order (a folder before the notes in it, a
/// note before its sections); if the server cannot be reached the changes
/// wait and are retried with a growing delay. Reads ask the server first and
/// fall back to the cache. Rows with changes still waiting keep the local
/// version, so a refresh never undoes an offline edit: the last edit wins.
class OfflineRepository extends Repository {
  OfflineRepository(
    this._remote, {
    LocalCache Function()? cache,
    String? Function()? userId,
    this.retryBase = const Duration(seconds: 5),
  })  : _newCache = cache ?? HiveCache.new,
        _userId = userId ?? _signedInUser;

  static String? _signedInUser() => Supabase.instance.client.auth.currentUser?.id;

  final Repository _remote;
  final LocalCache Function() _newCache;
  final String? Function() _userId;
  final Duration retryBase;

  // One cache per account, so two people on one device never see each other's notes.
  LocalCache? _cache;
  String? _cacheUser;
  Future<LocalCache?>? _opening;

  List<_Op> _outbox = [];
  // One counter orders outbox entries and local writes. A fetch that started
  // before a local write must not overwrite that write in the cache.
  int _seq = 0;
  final Map<String, int> _touched = {};

  Future<void>? _draining;
  Timer? _retry;
  int _failures = 0;
  Future<void>? _prefetching;

  static const _outboxKey = 'outbox';

  @override
  String newId() => _remote.newId();

  /// Changes the server refused are dropped; anything else (no network, a
  /// timeout, an expired token, a server error) keeps the change for later.
  static bool isRetryable(Object e) {
    if (e is Error) return false;
    if (e is PostgrestException) {
      final code = e.code ?? '';
      if (code.startsWith('PGRST3')) return true; // JWT problems, fixed by the next token refresh
      // Three digits is an HTTP status; five is a Postgres error, which retrying will not fix.
      final http = code.length == 3 ? int.tryParse(code) : null;
      return http != null && (http >= 500 || http == 401 || http == 408 || http == 429);
    }
    return true;
  }

  // ---- cache lifecycle ---------------------------------------------------

  Future<LocalCache?> _open() {
    final uid = _userId();
    if (uid == null) return Future.value(null);
    if (uid == _cacheUser && _opening != null) return _opening!;

    _retry?.cancel();
    _retry = null;
    _failures = 0;
    _touched.clear();
    _outbox = [];
    final previous = _cache;
    _cache = null;
    _cacheUser = uid;
    return _opening = () async {
      await previous?.close();
      try {
        final c = _newCache();
        await c.open('zrnotes_$uid');
        final raw = c.get(_outboxKey);
        _outbox = raw == null
            ? []
            : (jsonDecode(raw) as List).map((e) => _Op.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        _seq = _outbox.fold(_seq, (a, o) => math.max(a, o.seq));
        _cache = c;
        status.update(offline: false, pending: _outbox.length);
        return c;
      } catch (e) {
        // Without a cache the app still works, it just needs the connection.
        debugPrint('Offline cache unavailable: $e');
        return null;
      }
    }();
  }

  Iterable<Map<String, dynamic>> _rows(LocalCache c, String table) sync* {
    for (final k in c.keys) {
      if (!k.startsWith('$table/')) continue;
      final raw = c.get(k);
      if (raw != null) yield Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }
  }

  Map<String, dynamic>? _row(LocalCache c, String key) {
    final raw = c.get(key);
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  bool _hasPending(String key) => _outbox.any((o) => o.key == key);
  bool _protected(String key, int since) => (_touched[key] ?? 0) > since || _hasPending(key);

  /// Writes local edits: a row map to save, or null to delete.
  Future<void> _store(LocalCache c, Map<String, Map<String, dynamic>?> changes) async {
    final puts = <String, String>{};
    final deletes = <String>[];
    changes.forEach((key, row) {
      _touched[key] = ++_seq;
      if (row == null) {
        deletes.add(key);
      } else {
        // Keep the server's order for rows that came from it.
        final pos = _row(c, key)?['_pos'];
        puts[key] = jsonEncode({...row, '_pos': ?pos});
      }
    });
    if (deletes.isNotEmpty) await c.deleteAll(deletes);
    if (puts.isNotEmpty) await c.putAll(puts);
  }

  /// Replaces cached rows of [table] (limited to [scope]) with what the
  /// server returned, except rows edited locally since [since].
  Future<void> _replace(
    LocalCache c,
    String table,
    List<Map<String, dynamic>> fresh, {
    required int since,
    bool Function(Map<String, dynamic> row)? scope,
  }) async {
    final ids = {for (final r in fresh) r['id'] as String};
    final stale = <String>[];
    for (final k in c.keys.toList()) {
      if (!k.startsWith('$table/') || ids.contains(k.substring(table.length + 1))) continue;
      if (_protected(k, since)) continue;
      if (scope != null) {
        final row = _row(c, k);
        if (row == null || !scope(row)) continue;
      }
      stale.add(k);
    }
    final puts = <String, String>{};
    for (var i = 0; i < fresh.length; i++) {
      final key = '$table/${fresh[i]['id']}';
      if (_protected(key, since)) continue;
      puts[key] = jsonEncode({...fresh[i], '_pos': i});
    }
    if (stale.isNotEmpty) await c.deleteAll(stale);
    if (puts.isNotEmpty) await c.putAll(puts);
  }

  static int _byPos(Map<String, dynamic> a, Map<String, dynamic> b) =>
      ((a['_pos'] as num?) ?? 1 << 30).compareTo((b['_pos'] as num?) ?? 1 << 30);

  // ---- outbox ------------------------------------------------------------

  void _enqueue(String table, String id, Map<String, dynamic>? row) {
    final op = _Op(table, id, row, ++_seq);
    final i = _outbox.indexWhere((o) => o.key == op.key);
    if (row != null && i >= 0 && _outbox[i].row != null) {
      // Same place in the queue, so the order against other rows is kept.
      _outbox[i] = op;
    } else {
      if (row == null) _outbox.removeWhere((o) => o.key == op.key);
      _outbox.add(op);
    }
  }

  Future<void> _saveOutbox(LocalCache c) async {
    await c.putAll({_outboxKey: jsonEncode(_outbox.map((o) => o.toJson()).toList())});
    status.update(pending: _outbox.length);
  }

  Future<void> _send(_Op op) {
    final row = op.row;
    return switch (op.table) {
      'folders' => row == null ? _remote.deleteFolder(op.id) : _remote.upsertFolder(Folder.fromRow(row)),
      'notes' => row == null ? _remote.deleteNote(op.id) : _remote.upsertNote(Note.fromRow(row)),
      'sections' => row == null ? _remote.deleteSection(op.id) : _remote.upsertSection(Section.fromRow(row)),
      _ => _remote.saveSettings(row ?? const {}),
    };
  }

  /// Sends waiting changes, oldest first. Never throws.
  Future<void> _drain() => _draining ??= _drainLoop().whenComplete(() => _draining = null);

  Future<void> _drainLoop() async {
    final c = _cache;
    if (c == null) return;
    while (_outbox.isNotEmpty && identical(c, _cache)) {
      final op = _outbox.first;
      try {
        await _send(op);
      } catch (e) {
        if (isRetryable(e)) return _wentOffline();
        status.update(problem: '$e');
      }
      // A newer edit of the same row may have replaced it meanwhile; that one still has to go.
      _outbox.removeWhere((o) => o.key == op.key && o.seq == op.seq);
      await _saveOutbox(c);
    }
    _failures = 0;
    _retry?.cancel();
    _retry = null;
    status.update(offline: false);
  }

  void _wentOffline() {
    status.update(offline: true);
    if (_retry != null) return;
    final wait = retryBase * math.pow(2, math.min(_failures, 4)).toInt();
    _failures++;
    _retry = Timer(wait < const Duration(minutes: 1) ? wait : const Duration(minutes: 1), () {
      _retry = null;
      _drain();
    });
  }

  /// Saves locally, queues the change, then tries to send the queue.
  Future<void> _mutate(String table, String id, Map<String, dynamic>? row,
      [Map<String, Map<String, dynamic>?> extra = const {}]) async {
    final c = await _open();
    if (c == null) return _send(_Op(table, id, row, 0));
    await _store(c, {'$table/$id': row, ...extra});
    _enqueue(table, id, row);
    await _saveOutbox(c);
    await _drain();
  }

  /// Runs a fetch against the server and records whether it was reachable.
  Future<T?> _fetch<T>(Future<T> Function() load) async {
    try {
      final result = await load();
      if (status.offline) unawaited(_drain());
      return result;
    } catch (e) {
      if (!isRetryable(e)) rethrow;
      _wentOffline();
      return null;
    }
  }

  // ---- reads -------------------------------------------------------------

  @override
  Future<List<Folder>> fetchFolders() async {
    final c = await _open();
    if (c == null) return _remote.fetchFolders();
    await _drain();
    final since = _seq;
    final fresh = await _fetch(_remote.fetchFolders);
    if (fresh != null) await _replace(c, 'folders', [for (final f in fresh) f.toRow()], since: since);
    final rows = _rows(c, 'folders').toList()
      ..sort((a, b) {
        final o = ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0);
        return o != 0 ? o : _byPos(a, b);
      });
    return rows.map(Folder.fromRow).toList();
  }

  @override
  Future<List<Note>> fetchNotes() async {
    final c = await _open();
    if (c == null) return _remote.fetchNotes();
    await _drain();
    final since = _seq;
    final fresh = await _fetch(_remote.fetchNotes);
    if (fresh != null) {
      await _replace(c, 'notes', [for (final n in fresh) _noteRow(n)], since: since);
      unawaited(_prefetch(c));
    }
    final rows = _rows(c, 'notes').toList()
      ..sort((a, b) {
        final o = ((a['sort_order'] as num?) ?? 0).compareTo((b['sort_order'] as num?) ?? 0);
        return o != 0 ? o : _byPos(a, b);
      });
    return rows.map(Note.fromRow).toList();
  }

  @override
  Future<List<Section>> fetchSections(String noteId) async {
    final c = await _open();
    if (c == null) return _remote.fetchSections(noteId);
    await _drain();
    final since = _seq;
    final fresh = await _fetch(() => _remote.fetchSections(noteId));
    if (fresh != null) {
      await _replace(c, 'sections', [for (final s in fresh) s.toRow()],
          since: since, scope: (r) => r['note_id'] == noteId);
    }
    return _sectionsOf(c, (r) => r['note_id'] == noteId);
  }

  @override
  Future<List<Section>> fetchAllSections() async {
    final c = await _open();
    if (c == null) return _remote.fetchAllSections();
    return _sectionsOf(c, (_) => true);
  }

  List<Section> _sectionsOf(LocalCache c, bool Function(Map<String, dynamic>) where) {
    final rows = _rows(c, 'sections').where(where).toList()
      ..sort((a, b) {
        final o = ((a['z_index'] as num?) ?? 0).compareTo((b['z_index'] as num?) ?? 0);
        return o != 0 ? o : _byPos(a, b);
      });
    return rows.map(Section.fromRow).toList();
  }

  /// Downloads every note's sections in the background, so a note that was
  /// never opened on this device can still be read offline.
  Future<void> _prefetch(LocalCache c) => _prefetching ??= () async {
        try {
          final since = _seq;
          final all = await _remote.fetchAllSections();
          if (identical(c, _cache)) await _replace(c, 'sections', [for (final s in all) s.toRow()], since: since);
        } catch (_) {
          // Only a head start; the note still loads when opened.
        } finally {
          _prefetching = null;
        }
      }();

  @override
  Future<Map<String, dynamic>?> fetchSettings() async {
    final c = await _open();
    if (c == null) return _remote.fetchSettings();
    await _drain();
    const key = 'user_settings/me';
    for (final o in _outbox) {
      if (o.key == key) return o.row;
    }
    final since = _seq;
    final fresh = await _fetch(_remote.fetchSettings);
    if (fresh != null && !_protected(key, since)) await c.putAll({key: jsonEncode(fresh)});
    return _row(c, key);
  }

  // ---- writes ------------------------------------------------------------

  static Map<String, dynamic> _noteRow(Note n) => {...n.toRow(), 'updated_at': n.updatedAt.toUtc().toIso8601String()};

  @override
  Future<void> upsertFolder(Folder f) => _mutate('folders', f.id, f.toRow());

  @override
  Future<void> deleteFolder(String id) async {
    final c = await _open();
    if (c == null) return _mutate('folders', id, null);
    // Mirror the database: subfolders go too, notes inside move out of the folder.
    final folders = _rows(c, 'folders').toList();
    final gone = <String>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final f in folders) {
        if (gone.contains(f['parent_id']) && gone.add(f['id'] as String)) grew = true;
      }
    }
    final extra = <String, Map<String, dynamic>?>{
      for (final f in gone) 'folders/$f': null,
      for (final n in _rows(c, 'notes'))
        if (gone.contains(n['folder_id'])) 'notes/${n['id']}': {...n, 'folder_id': null},
    };
    return _mutate('folders', id, null, extra);
  }

  @override
  Future<void> upsertNote(Note n) => _mutate('notes', n.id, _noteRow(n));

  @override
  Future<void> deleteNote(String id) async {
    final c = await _open();
    if (c == null) return _mutate('notes', id, null);
    final notes = _rows(c, 'notes').toList();
    final gone = <String>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final n in notes) {
        if (gone.contains(n['parent_note_id']) && gone.add(n['id'] as String)) grew = true;
      }
    }
    final extra = <String, Map<String, dynamic>?>{
      for (final n in gone) 'notes/$n': null,
      for (final s in _rows(c, 'sections'))
        if (gone.contains(s['note_id'])) 'sections/${s['id']}': null,
    };
    return _mutate('notes', id, null, extra);
  }

  @override
  Future<void> upsertSection(Section s) => _mutate('sections', s.id, s.toRow());

  @override
  Future<void> deleteSection(String id) => _mutate('sections', id, null);

  @override
  Future<void> saveSettings(Map<String, dynamic> data) => _mutate('user_settings', 'me', data);

  @override
  Future<String> uploadImage(Uint8List bytes, String fileName) => _remote.uploadImage(bytes, fileName);
}

/// One waiting change. [row] is null for a delete.
class _Op {
  _Op(this.table, this.id, this.row, this.seq);

  final String table;
  final String id;
  final Map<String, dynamic>? row;
  final int seq;

  String get key => '$table/$id';

  Map<String, dynamic> toJson() => {'table': table, 'id': id, 'row': row, 'seq': seq};

  factory _Op.fromJson(Map<String, dynamic> j) => _Op(
        j['table'] as String,
        j['id'] as String,
        j['row'] == null ? null : Map<String, dynamic>.from(j['row'] as Map),
        (j['seq'] as num).toInt(),
      );
}
