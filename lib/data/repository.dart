
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../models.dart';

/// All database and storage calls live here, so the rest of the app never
/// talks to Supabase directly. Row Level Security scopes every query to the
/// signed-in user, which is why there are no `user_id` filters below.
class Repository {
  SupabaseClient get _db => Supabase.instance.client;
  static const _uuid = Uuid();

  String newId() => _uuid.v4();

  /// Connection state for the UI. Only the offline layer ever changes it.
  final SyncStatus status = SyncStatus();

  Future<List<Folder>> fetchFolders() async {
    final rows = await _db.from('folders').select().order('sort_order').order('created_at');
    return rows.map(Folder.fromRow).toList();
  }

  Future<List<Note>> fetchNotes() async {
    final rows = await _db.from('notes').select().order('sort_order').order('created_at');
    return rows.map(Note.fromRow).toList();
  }

  Future<List<Section>> fetchSections(String noteId) async {
    final rows = await _db.from('sections').select().eq('note_id', noteId).order('z_index');
    return rows.map(Section.fromRow).toList();
  }

  /// Every section of every note, so notes can be read offline later.
  Future<List<Section>> fetchAllSections() async {
    final rows = await _db.from('sections').select().order('z_index');
    return rows.map(Section.fromRow).toList();
  }

  Future<void> upsertFolder(Folder f) => _db.from('folders').upsert(f.toRow());
  Future<void> deleteFolder(String id) => _db.from('folders').delete().eq('id', id);

  Future<void> upsertNote(Note n) => _db.from('notes').upsert(n.toRow());
  Future<void> deleteNote(String id) => _db.from('notes').delete().eq('id', id);

  Future<void> upsertSection(Section s) => _db.from('sections').upsert(s.toRow());
  Future<void> deleteSection(String id) => _db.from('sections').delete().eq('id', id);

  Future<Map<String, dynamic>?> fetchSettings() async {
    final row = await _db.from('user_settings').select('data').maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row['data'] as Map);
  }

  Future<void> saveSettings(Map<String, dynamic> data) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    await _db.from('user_settings').upsert({'user_id': uid, 'data': data});
  }

  /// Uploads an image and returns its public URL.
  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    final uid = _db.auth.currentUser!.id;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'png';
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    final path = '$uid/${newId()}.$ext';
    await _db.storage
        .from(AppConfig.imageBucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime));
    return _db.storage.from(AppConfig.imageBucket).getPublicUrl(path);
  }
}

/// Whether the server can be reached and how many local changes still wait
/// to be sent. [problem] holds a change the server refused, once.
class SyncStatus extends ChangeNotifier {
  bool offline = false;
  int pending = 0;
  String? problem;

  void update({bool? offline, int? pending, String? problem}) {
    final changed = (offline != null && offline != this.offline) ||
        (pending != null && pending != this.pending) ||
        problem != null;
    this.offline = offline ?? this.offline;
    this.pending = pending ?? this.pending;
    this.problem = problem ?? this.problem;
    if (changed) notifyListeners();
  }
}
