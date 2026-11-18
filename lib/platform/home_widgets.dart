import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models.dart';
import '../state/notes_store.dart';

/// Android home-screen widgets. The native side (Kotlin, `android/app/src/main`)
/// can only read plain key/value data, so this class copies the few notes a
/// widget shows into that store and asks Android to redraw. On every other
/// platform every call does nothing, so callers never check the platform.
class HomeWidgets {
  HomeWidgets(this._store);
  final NotesStore _store;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _recentWidget = 'dev.zr.zrnotes.RecentNotesWidget';
  static const _quickAddWidget = 'dev.zr.zrnotes.QuickAddWidget';

  /// How many notes the "recent notes" widget has rows for. Keep in step with
  /// the row ids in `notes_widget.xml` and `RecentNotesWidget.kt`.
  static const rows = 5;

  Timer? _debounce;
  StreamSubscription<Uri?>? _clicks;
  bool _started = false;

  /// Starts mirroring the store to the widgets and handling widget taps.
  /// Call once the signed-in shell is on screen.
  Future<void> start() async {
    if (!supported || _started) return;
    _started = true;
    _store.addListener(_schedule);
    _clicks = HomeWidget.widgetClicked.listen(_open);
    // A tap that started the app from cold has to wait for the notes to load.
    final initial = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (initial != null) _launchUri = initial;
    _schedule();
  }

  Uri? _launchUri;

  void dispose() {
    _debounce?.cancel();
    _clicks?.cancel();
    if (_started) _store.removeListener(_schedule);
    _started = false;
  }

  /// Blanks the widgets, used on sign-out so notes do not linger on the home screen.
  static Future<void> clear() async {
    if (!supported) return;
    try {
      await HomeWidget.saveWidgetData<int>('count', 0);
      await _redraw();
    } catch (e) {
      debugPrint('Widget clear failed: $e');
    }
  }

  // Typing fires the store many times a second; one update every 2 s is enough.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _push);
    final uri = _launchUri;
    if (uri != null && _store.notes.isNotEmpty) {
      _launchUri = null;
      _open(uri);
    }
  }

  /// The notes a widget lists: pinned first, then newest edit first. Subnotes
  /// live inside other notes, so they are left out.
  static List<Note> pick(Iterable<Note> notes, {int max = rows}) {
    final list = notes.where((n) => !n.isSubnote).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return list.take(max).toList();
  }

  Future<void> _push() async {
    try {
      final picked = pick(_store.notes);
      await HomeWidget.saveWidgetData<int>('count', picked.length);
      for (var i = 0; i < rows; i++) {
        final n = i < picked.length ? picked[i] : null;
        await HomeWidget.saveWidgetData<String>('id_$i', n?.id ?? '');
        await HomeWidget.saveWidgetData<String>('title_$i', n == null ? '' : (n.title.isEmpty ? 'Untitled' : n.title));
        await HomeWidget.saveWidgetData<String>('desc_$i', n?.description ?? '');
      }
      await _redraw();
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }

  static Future<void> _redraw() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: _recentWidget);
    await HomeWidget.updateWidget(qualifiedAndroidName: _quickAddWidget);
  }

  /// `zrnotes://note?id=<id>` opens a note, `zrnotes://new` starts a new one.
  void _open(Uri? uri) {
    if (uri == null || uri.scheme != 'zrnotes') return;
    if (uri.host == 'new') {
      _store.addNote();
    } else if (uri.host == 'note') {
      final id = uri.queryParameters['id'];
      if (id != null && _store.noteById(id) != null) _store.selectNote(id);
    }
  }
}
