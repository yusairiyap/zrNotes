import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zrnotes/data/demo_repository.dart';
import 'package:zrnotes/data/local_cache.dart';
import 'package:zrnotes/data/offline_repository.dart';
import 'package:zrnotes/models.dart';

/// The in-memory demo data plays the server; [down] makes every call fail
/// the way a dropped connection does.
class FakeServer extends DemoRepository {
  bool down = false;
  bool writesDown = false;
  Object? refuse;
  final calls = <String>[];

  Future<T> _call<T>(String name, Future<T> Function() run) {
    if (down || (writesDown && !name.startsWith('fetch'))) throw http.ClientException('Failed host lookup');
    if (refuse != null) throw refuse!;
    calls.add(name);
    return run();
  }

  @override
  Future<List<Folder>> fetchFolders() => _call('fetchFolders', super.fetchFolders);
  @override
  Future<List<Note>> fetchNotes() => _call('fetchNotes', super.fetchNotes);
  @override
  Future<List<Section>> fetchSections(String noteId) => _call('fetchSections', () => super.fetchSections(noteId));
  @override
  Future<List<Section>> fetchAllSections() => _call('fetchAllSections', super.fetchAllSections);
  @override
  Future<void> upsertFolder(Folder f) => _call('upsertFolder ${f.name}', () => super.upsertFolder(f));
  @override
  Future<void> upsertNote(Note n) => _call('upsertNote ${n.title}', () => super.upsertNote(n));
  @override
  Future<void> deleteNote(String id) => _call('deleteNote', () => super.deleteNote(id));
  @override
  Future<void> upsertSection(Section s) => _call('upsertSection', () => super.upsertSection(s));
}

void main() {
  late FakeServer server;
  late MemoryCache cache;
  late OfflineRepository repo;

  OfflineRepository build() => OfflineRepository(server, cache: () => cache, userId: () => 'u1', retryBase: const Duration(milliseconds: 1));

  setUp(() {
    server = FakeServer();
    cache = MemoryCache();
    repo = build();
  });

  test('notes and sections stay readable after the connection drops', () async {
    final notes = await repo.fetchNotes();
    await Future<void>.delayed(Duration.zero); // background section download
    final sprint = notes.firstWhere((n) => n.title == 'Sprint planning');
    final ideas = notes.firstWhere((n) => n.title == 'App ideas');

    server.down = true;
    final again = await repo.fetchNotes();
    expect(again.map((n) => n.id), notes.map((n) => n.id));
    expect(repo.status.offline, isTrue);
    expect(await repo.fetchSections(sprint.id), hasLength(4));
    expect(await repo.fetchSections(ideas.id), isEmpty);
  });

  test('offline edits survive a restart and are sent in order when back online', () async {
    await repo.fetchNotes();
    server.down = true;

    final folder = Folder(id: repo.newId(), name: 'Trips');
    final note = Note(id: repo.newId(), title: 'Packing', folderId: folder.id);
    final section = Section(id: repo.newId(), noteId: note.id, content: [
      {'insert': 'passport\n'},
    ]);
    await repo.upsertFolder(folder);
    await repo.upsertNote(note);
    await repo.upsertSection(section);
    note.title = 'Packing list';
    await repo.upsertNote(note);

    expect(repo.status.pending, 3);
    expect((await repo.fetchNotes()).map((n) => n.title), contains('Packing list'));

    // A new start of the app reads the same cache, outbox included.
    repo = build();
    expect((await repo.fetchNotes()).map((n) => n.title), contains('Packing list'));
    expect(repo.status.pending, 3);

    server.down = false;
    server.calls.clear();
    await repo.fetchFolders();
    expect(server.calls.take(3), ['upsertFolder Trips', 'upsertNote Packing list', 'upsertSection']);
    expect(repo.status.pending, 0);
    expect(repo.status.offline, isFalse);
    expect((await server.fetchSections(note.id)).single.content, section.content);
  });

  test('a refresh does not undo an edit that is still waiting', () async {
    final n = (await repo.fetchNotes()).first;
    final before = n.title;
    server.writesDown = true;
    n.title = 'Changed offline';
    await repo.upsertNote(n);

    // The server can be read but still has the old title.
    expect((await server.fetchNotes()).firstWhere((x) => x.id == n.id).title, before);
    expect((await repo.fetchNotes()).firstWhere((x) => x.id == n.id).title, 'Changed offline');
  });

  test('the queue retries by itself once the connection is back', () async {
    await repo.fetchNotes();
    server.down = true;
    final note = Note(id: repo.newId(), title: 'Later');
    await repo.upsertNote(note);
    expect(repo.status.pending, 1);

    server.down = false;
    for (var i = 0; i < 50 && repo.status.pending > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(repo.status.pending, 0);
    expect((await server.fetchNotes()).map((n) => n.title), contains('Later'));
  });

  test('a change the server refuses is dropped and reported', () async {
    await repo.fetchNotes();
    server.refuse = const PostgrestException(message: 'violates foreign key', code: '23503');
    await repo.upsertNote(Note(id: repo.newId(), title: 'Orphan'));
    expect(repo.status.pending, 0);
    expect(repo.status.problem, contains('foreign key'));
  });

  test('deleting a note offline removes its sections and subnotes from the cache', () async {
    final notes = await repo.fetchNotes();
    await Future<void>.delayed(Duration.zero);
    final sprint = notes.firstWhere((n) => n.title == 'Sprint planning');
    server.down = true;
    await repo.deleteNote(sprint.id);
    final left = await repo.fetchNotes();
    expect(left.where((n) => n.id == sprint.id || n.parentNoteId == sprint.id), isEmpty);
    expect(await repo.fetchSections(sprint.id), isEmpty);

    server.down = false;
    await repo.fetchNotes();
    expect((await server.fetchNotes()).where((n) => n.id == sprint.id), isEmpty);
  });

  test('server errors that may clear up keep the change', () {
    expect(OfflineRepository.isRetryable(http.ClientException('offline')), isTrue);
    expect(OfflineRepository.isRetryable(const PostgrestException(message: 'JWT expired', code: 'PGRST303')), isTrue);
    expect(OfflineRepository.isRetryable(const PostgrestException(message: 'bad gateway', code: '502')), isTrue);
    expect(OfflineRepository.isRetryable(const PostgrestException(message: 'rls', code: '42501')), isFalse);
  });
}
