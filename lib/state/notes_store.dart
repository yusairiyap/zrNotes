import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repository.dart';
import '../models.dart';

/// Which big view the main area is showing.
enum MainView { note, overview, mindMap }

/// Holds every folder, note and loaded section in memory and keeps Supabase
/// in step. Widgets listen to it through `provider`; it plays the same role
/// as a view model with INotifyPropertyChanged in .NET.
///
/// Edits are optimistic: the UI changes first, then the save runs. Saves that
/// fire often (typing, dragging) are debounced per row.
class NotesStore extends ChangeNotifier {
  NotesStore(this._repo);
  final Repository _repo;

  List<Folder> folders = [];
  List<Note> notes = [];
  final Map<String, List<Section>> _sections = {};
  final Map<String, Timer> _timers = {};

  String? selectedNoteId;

  /// The section that was just added, so its editor can take the cursor.
  String? newSectionId;
  MainView view = MainView.note;
  bool loading = false;
  bool saving = false;
  String? error;
  String query = '';

  Note? get selectedNote => noteById(selectedNoteId);

  Note? noteById(String? id) {
    if (id == null) return null;
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Folder? folderById(String? id) {
    if (id == null) return null;
    for (final f in folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  bool _matches(Note n) =>
      query.isEmpty ||
      n.title.toLowerCase().contains(query.toLowerCase()) ||
      n.description.toLowerCase().contains(query.toLowerCase());

  /// Top-level notes of a folder (null = notes outside any folder), pinned first.
  List<Note> notesIn(String? folderId) {
    final list = notes.where((n) => n.parentNoteId == null && n.folderId == folderId && _matches(n)).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return list;
  }

  List<Note> subnotesOf(String noteId) => notes.where((n) => n.parentNoteId == noteId).toList();

  List<Folder> childFolders(String? parentId) => folders.where((f) => f.parentId == parentId).toList();

  List<Section> sectionsOf(String noteId) => _sections[noteId] ?? const [];
  bool sectionsLoaded(String noteId) => _sections.containsKey(noteId);

  // ---- loading -----------------------------------------------------------

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await flush();
      final results = await Future.wait([_repo.fetchFolders(), _repo.fetchNotes()]);
      folders = results[0] as List<Folder>;
      notes = results[1] as List<Note>;
      // Reload sections of notes that are already open.
      for (final id in _sections.keys.toList()) {
        if (noteById(id) == null) {
          _sections.remove(id);
        } else {
          _sections[id] = await _repo.fetchSections(id);
        }
      }
      if (noteById(selectedNoteId) == null) {
        selectedNoteId = notes.where((n) => !n.isSubnote).firstOrNull?.id;
      }
      if (selectedNoteId != null) await loadSections(selectedNoteId!);
    } catch (e) {
      error = 'Could not sync: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadSections(String noteId, {bool force = false}) async {
    if (_sections.containsKey(noteId) && !force) return;
    try {
      _sections[noteId] = await _repo.fetchSections(noteId);
    } catch (e) {
      error = 'Could not load the note: $e';
    }
    notifyListeners();
  }

  void clear() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    folders = [];
    notes = [];
    _sections.clear();
    selectedNoteId = null;
    view = MainView.note;
    notifyListeners();
  }

  // ---- saving helpers ----------------------------------------------------

  final Map<String, Future<void> Function()> _pending = {};

  void _debounce(String key, Future<void> Function() save) {
    _timers[key]?.cancel();
    _pending[key] = save;
    saving = true;
    _timers[key] = Timer(const Duration(milliseconds: 700), () => _run(key));
  }

  Future<void> _run(String key) async {
    _timers.remove(key)?.cancel();
    final save = _pending.remove(key);
    if (save == null) return;
    try {
      await save();
      error = null;
    } catch (e) {
      error = 'Could not save: $e';
    }
    saving = _pending.isNotEmpty;
    notifyListeners();
  }

  /// Number of notes in a folder and the folders inside it (subnotes not counted).
  int noteCount(String folderId) {
    var n = notes.where((x) => x.folderId == folderId && !x.isSubnote).length;
    for (final c in childFolders(folderId)) {
      n += noteCount(c.id);
    }
    return n;
  }

  /// Runs every waiting save now. Called before a refresh and on sign-out.
  Future<void> flush() async {
    for (final key in _pending.keys.toList()) {
      await _run(key);
    }
  }

  Future<void> _now(Future<void> Function() save) async {
    try {
      await save();
      error = null;
    } catch (e) {
      error = 'Could not save: $e';
      notifyListeners();
    }
  }

  // ---- navigation --------------------------------------------------------

  void selectNote(String id) {
    selectedNoteId = id;
    view = MainView.note;
    notifyListeners();
    loadSections(id);
  }

  void setView(MainView v) {
    view = v;
    notifyListeners();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  // ---- folders -----------------------------------------------------------

  Future<Folder> addFolder({String name = 'New folder', String? parentId}) async {
    final f = Folder(id: _repo.newId(), name: name, parentId: parentId, sortOrder: folders.length.toDouble());
    folders.add(f);
    notifyListeners();
    await _now(() => _repo.upsertFolder(f));
    return f;
  }

  void updateFolder(Folder f) {
    notifyListeners();
    _now(() => _repo.upsertFolder(f));
  }

  /// Deletes a folder. Its notes are kept and move out of the folder.
  void deleteFolder(Folder f) {
    final removed = <String>{f.id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final c in folders) {
        if (c.parentId != null && removed.contains(c.parentId) && removed.add(c.id)) grew = true;
      }
    }
    folders.removeWhere((x) => removed.contains(x.id));
    for (final n in notes) {
      if (removed.contains(n.folderId)) n.folderId = null;
    }
    notifyListeners();
    _now(() => _repo.deleteFolder(f.id));
  }

  // ---- notes -------------------------------------------------------------

  Future<Note> addNote({String? folderId, String? parentNoteId, String title = 'Untitled', bool select = true}) async {
    final n = Note(
      id: _repo.newId(),
      title: title,
      folderId: folderId,
      parentNoteId: parentNoteId,
      sortOrder: notes.length.toDouble(),
    );
    notes.add(n);
    _sections[n.id] = [];
    if (select && parentNoteId == null) {
      selectedNoteId = n.id;
      view = MainView.note;
    }
    notifyListeners();
    await _now(() => _repo.upsertNote(n));
    return n;
  }

  void updateNote(Note n, {bool debounce = false}) {
    n.updatedAt = DateTime.now();
    notifyListeners();
    if (debounce) {
      _debounce('note:${n.id}', () => _repo.upsertNote(n));
    } else {
      _now(() => _repo.upsertNote(n));
    }
  }

  void deleteNote(Note n) {
    final removed = <String>{n.id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final c in notes) {
        if (c.parentNoteId != null && removed.contains(c.parentNoteId) && removed.add(c.id)) grew = true;
      }
    }
    notes.removeWhere((x) => removed.contains(x.id));
    for (final id in removed) {
      _sections.remove(id);
    }
    if (removed.contains(selectedNoteId)) {
      selectedNoteId = notes.where((x) => !x.isSubnote).firstOrNull?.id;
      if (selectedNoteId != null) loadSections(selectedNoteId!);
    }
    notifyListeners();
    _now(() => _repo.deleteNote(n.id)); // the database cascades to subnotes and sections
  }

  // ---- sections ----------------------------------------------------------

  Future<Section> addSection(String noteId, double x, double y) async {
    final list = _sections.putIfAbsent(noteId, () => []);
    final s = Section(
      id: _repo.newId(),
      noteId: noteId,
      x: x,
      y: y,
      zIndex: list.isEmpty ? 0 : list.map((e) => e.zIndex).reduce((a, b) => a > b ? a : b) + 1,
    );
    list.add(s);
    newSectionId = s.id;
    notifyListeners();
    await _now(() => _repo.upsertSection(s));
    return s;
  }

  /// Saves layout or style changes (position, size, colour, header).
  void updateSection(Section s, {bool notify = true}) {
    if (notify) notifyListeners();
    _debounce('section:${s.id}', () => _repo.upsertSection(s));
  }

  /// Saves edited text, and refreshes the note's short description that the
  /// overview and the zoomed-out canvas show.
  void updateSectionContent(Section s, List<dynamic> delta, String plainText) {
    s.content = delta;
    _debounce('section:${s.id}', () => _repo.upsertSection(s));
    final note = noteById(s.noteId);
    if (note == null) return;
    var changed = false;
    final all = sectionsOf(s.noteId);
    if (all.firstOrNull?.id == s.id) {
      final text = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
      final desc = text.length > 160 ? '${text.substring(0, 160)}…' : text;
      if (desc != note.description) {
        note.description = desc;
        changed = true;
      }
    }
    // Count checklist lines: Quill marks them with a list attribute.
    var total = 0, done = 0;
    for (final sec in all) {
      for (final op in sec.content ?? const []) {
        final list = op is Map && op['attributes'] is Map ? (op['attributes'] as Map)['list'] : null;
        if (list != 'checked' && list != 'unchecked') continue;
        final lines = op['insert'] is String ? (op['insert'] as String).length : 1;
        total += lines;
        if (list == 'checked') done += lines;
      }
    }
    if (total != note.todoTotal || done != note.todoDone) {
      note.todoTotal = total;
      note.todoDone = done;
      changed = true;
    }
    if (changed) {
      notifyListeners();
      _debounce('note:${note.id}', () => _repo.upsertNote(note));
    }
  }

  void bringToFront(Section s) {
    final list = sectionsOf(s.noteId);
    final top = list.map((e) => e.zIndex).fold(0, (a, b) => a > b ? a : b);
    if (s.zIndex == top && list.where((e) => e.zIndex == top).length == 1) return;
    s.zIndex = top + 1;
    updateSection(s);
  }

  void deleteSection(Section s) {
    _timers.remove('section:${s.id}')?.cancel();
    _pending.remove('section:${s.id}');
    _sections[s.noteId]?.remove(s);
    notifyListeners();
    _now(() => _repo.deleteSection(s.id));
  }

  Future<String> uploadImage(Uint8List bytes, String name) => _repo.uploadImage(bytes, name);
}
