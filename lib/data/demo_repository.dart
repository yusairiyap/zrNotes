import 'dart:convert';
import 'dart:typed_data';

import '../models.dart';
import 'repository.dart';

/// An in-memory stand-in for Supabase, used when the app is started with
/// `--dart-define=DEMO=true`. Nothing is saved and no account is needed, which
/// makes it handy for trying the UI and for automated UI checks.
class DemoRepository extends Repository {
  final _folders = <String, Folder>{};
  final _notes = <String, Note>{};
  final _sections = <String, Section>{};
  Map<String, dynamic>? _settings;

  DemoRepository() {
    final work = Folder(id: newId(), name: 'Work', sortOrder: 0);
    final personal = Folder(id: newId(), name: 'Personal', sortOrder: 1, icon: 'emoji:🏠');
    _folders[work.id] = work;
    _folders[personal.id] = personal;

    final sprint = Note(id: newId(), title: 'Sprint planning', folderId: work.id, sortOrder: 0, todoTotal: 3, todoDone: 1,
        description: 'Draft the sync conflict rules Review Markdown preview on tablet Ship the Windows tray build');
    final api = Note(id: newId(), title: 'API integration notes', folderId: work.id, sortOrder: 1, icon: 'icon:code');
    final ideas = Note(id: newId(), title: 'App ideas', folderId: personal.id, sortOrder: 2, icon: 'icon:idea', pinned: true);
    final sub = Note(id: newId(), title: 'Widget sketches', parentNoteId: sprint.id, sortOrder: 3);
    for (final n in [sprint, api, ideas, sub]) {
      _notes[n.id] = n;
    }

    void add(Section s) => _sections[s.id] = s;
    add(Section(
      id: newId(),
      noteId: sprint.id,
      title: 'This sprint',
      headerKind: HeaderKind.icon,
      headerValue: 'check',
      x: 48,
      y: 40,
      width: 370,
      content: [
        {'insert': 'Draft the sync conflict rules'},
        {'insert': '\n', 'attributes': {'list': 'checked'}},
        {'insert': 'Review '},
        {'insert': 'Markdown preview', 'attributes': {'background': '#FFE4EE5B'}},
        {'insert': ' on tablet'},
        {'insert': '\n', 'attributes': {'list': 'unchecked'}},
        {'insert': 'Ship the '},
        {'insert': 'Windows tray', 'attributes': {'bold': true}},
        {'insert': ' build'},
        {'insert': '\n', 'attributes': {'list': 'unchecked'}},
      ],
    ));
    add(Section(
      id: newId(),
      noteId: sprint.id,
      title: 'Estimates',
      color: 0xFFEAF3FF,
      x: 470,
      y: 40,
      width: 430,
      zIndex: 1,
      content: [
        {'insert': {'x-embed-table': '| Task | Days |\n| --- | --- |\n| Canvas sections | 3 |\n| Subnote popups | 2 |'}},
        {'insert': '\n'},
      ],
    ));
    add(Section(
      id: newId(),
      noteId: sprint.id,
      title: 'Ideas',
      headerKind: HeaderKind.emoji,
      headerValue: '💡',
      color: 0xFFFFF4D6,
      x: 70,
      y: 300,
      width: 330,
      zIndex: 2,
      content: [
        {'insert': 'Double-tap empty space to drop a new section. Drag its tab to move it.\n'},
      ],
    ));
    add(Section(
      id: newId(),
      noteId: sprint.id,
      x: 470,
      y: 330,
      width: 300,
      zIndex: 3,
      content: [
        {'insert': 'A section with no title or tab.\n'},
      ],
    ));
  }

  @override
  Future<List<Folder>> fetchFolders() async => _folders.values.toList();
  @override
  Future<List<Note>> fetchNotes() async => _notes.values.toList();
  @override
  Future<List<Section>> fetchSections(String noteId) async =>
      _sections.values.where((s) => s.noteId == noteId).toList();

  @override
  Future<void> upsertFolder(Folder f) async => _folders[f.id] = f;
  @override
  Future<void> deleteFolder(String id) async => _folders.remove(id);
  @override
  Future<void> upsertNote(Note n) async => _notes[n.id] = n;
  @override
  Future<void> deleteNote(String id) async {
    _notes.remove(id);
    _sections.removeWhere((_, s) => s.noteId == id);
  }

  @override
  Future<void> upsertSection(Section s) async => _sections[s.id] = s;
  @override
  Future<void> deleteSection(String id) async => _sections.remove(id);

  @override
  Future<Map<String, dynamic>?> fetchSettings() async => _settings;
  @override
  Future<void> saveSettings(Map<String, dynamic> data) async => _settings = data;

  @override
  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    final ext = fileName.split('.').last.toLowerCase();
    return 'data:image/${ext == 'jpg' ? 'jpeg' : ext};base64,${base64Encode(bytes)}';
  }
}
