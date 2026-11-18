import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zrnotes/data/markdown.dart';
import 'package:zrnotes/theme/vibes.dart';

void main() {
  test('Markdown survives a round trip through the editor format', () {
    const source = '# Title\n- [x] done\n- [ ] todo\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n\nplain **bold** text.';
    final delta = markdownToDelta(source);
    final back = deltaToMarkdown(delta);
    expect(back, contains('# Title'));
    expect(back, contains('- [x] done'));
    expect(back, contains('- [ ] todo'));
    expect(back, contains('| a | b |'));
    expect(back, contains('plain **bold** text.'));
  });

  test('empty Markdown gives a valid empty document', () {
    expect(markdownToDelta('   ').toJson(), [
      {'insert': '\n'},
    ]);
  });

  test('tables are parsed and written back', () {
    final rows = parseMarkdownTable('| Task | Days |\n| --- | --- |\n| Canvas | 3 |\n| Popups |');
    expect(rows, [
      ['Task', 'Days'],
      ['Canvas', '3'],
      ['Popups', ''],
    ]);
    expect(writeMarkdownTable(rows), '| Task | Days |\n| --- | --- |\n| Canvas | 3 |\n| Popups |  |');
  });

  test('every vibe has a unique id', () {
    expect(vibes.map((v) => v.id).toSet().length, vibes.length);
    expect(vibeById('nope').id, 'default');
  });

  test('subnote links survive a Markdown round trip', () {
    const id = '0b6f1c2e-1111-4222-8333-444455556666';
    final delta = Delta()
      ..insert('See ')
      ..insert({subnoteEmbedType: id})
      ..insert(' for details\n');
    final text = deltaToMarkdown(delta);
    expect(text, contains('[[subnote:$id]]'));
    final back = markdownToDelta(text).toJson();
    expect(back.any((op) => op['insert'] is Map && op['insert'][subnoteEmbedType] == id), isTrue);
  });

  test('Mermaid diagrams survive a Markdown round trip', () {
    const source = 'flowchart LR\n  A[Start] --> B{Ok?}\n\n  B -->|yes| C';
    final delta = Delta()
      ..insert('Before\n')
      ..insert({mermaidEmbedType: source})
      ..insert('After\n');
    final text = deltaToMarkdown(delta);
    expect(text, contains('```mermaid\n$source\n```'));
    final back = markdownToDelta(text).toJson();
    expect(back.where((op) => op['insert'] is Map).map((op) => op['insert'][mermaidEmbedType]), [source]);
    expect(deltaToMarkdown(Delta.fromJson(back)), text);
  });

  test('other fenced code blocks stay code', () {
    final back = markdownToDelta('```dart\nvoid main() {}\n```').toJson();
    expect(back.any((op) => op['insert'] is Map), isFalse);
  });
}
