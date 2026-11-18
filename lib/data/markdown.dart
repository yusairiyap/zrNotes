import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

/// Embed type of a subnote link inside a section. Its data is the subnote's id.
const subnoteEmbedType = 'x-subnote';

final _subnoteLink = RegExp(r'\[\[subnote:([0-9a-fA-F-]+)\]\]');

/// Converts between the rich-text format the editor stores (a Quill "Delta")
/// and GitLab/GitHub-flavoured Markdown.
///
/// Markdown cannot express text colour, highlight or font size, so those are
/// lost if a section is edited as Markdown. The app only converts back when
/// the Markdown text was actually changed.
String deltaToMarkdown(Delta delta) {
  try {
    return DeltaToMarkdown(
      customEmbedHandlers: {
        EmbeddableTable.tableType: EmbeddableTable.toMdSyntax,
        // A subnote link is written as [[subnote:<id>]] so it survives the trip.
        subnoteEmbedType: (embed, out) => out.write('[[subnote:${embed.value.data}]]'),
      },
      // Write text as typed. The default handler escapes every dot and dash.
      customContentHandler: (text, out) => out.write(text.value),
    ).convert(delta).trimRight();
  } catch (_) {
    return Document.fromDelta(delta).toPlainText().trimRight();
  }
}

Delta markdownToDelta(String source) {
  if (source.trim().isEmpty) return Delta()..insert('\n');
  final doc = md.Document(
    encodeHtml: false,
    extensionSet: md.ExtensionSet.gitHubFlavored,
    blockSyntaxes: [const EmbeddableTableSyntax()],
  );
  final delta = MarkdownToDelta(
    markdownDocument: doc,
    customElementToEmbeddable: {EmbeddableTable.tableType: EmbeddableTable.fromMdSyntax},
  ).convert(source);
  if (delta.isEmpty) return Delta()..insert('\n');
  final last = delta.last.data;
  if (last is! String || !last.endsWith('\n')) delta.insert('\n');
  return _restoreSubnotes(delta);
}

/// Turns each [[subnote:<id>]] back into a subnote link.
Delta _restoreSubnotes(Delta delta) {
  final out = Delta();
  for (final op in delta.toList()) {
    final data = op.data;
    if (data is! String || !data.contains('[[subnote:')) {
      out.push(op);
      continue;
    }
    var at = 0;
    for (final m in _subnoteLink.allMatches(data)) {
      if (m.start > at) out.insert(data.substring(at, m.start), op.attributes);
      out.insert({subnoteEmbedType: m.group(1)});
      at = m.end;
    }
    if (at < data.length) out.insert(data.substring(at), op.attributes);
  }
  return out;
}

/// A Markdown table split into rows of cells (first row is the header).
List<List<String>> parseMarkdownTable(String data) {
  final rows = <List<String>>[];
  final lines = data.split('\n').where((l) => l.trim().isNotEmpty).toList();
  for (var i = 0; i < lines.length; i++) {
    if (i == 1 && RegExp(r'^[\s|:\-]+$').hasMatch(lines[i])) continue; // the |---|---| divider
    var line = lines[i].trim();
    if (line.startsWith('|')) line = line.substring(1);
    if (line.endsWith('|')) line = line.substring(0, line.length - 1);
    rows.add(line.split('|').map((c) => c.trim().replaceAll(r'\|', '|')).toList());
  }
  if (rows.isEmpty) rows.add(['', '']);
  final width = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  for (final r in rows) {
    while (r.length < width) {
      r.add('');
    }
  }
  return rows;
}

String writeMarkdownTable(List<List<String>> rows) {
  String line(List<String> cells) => '| ${cells.map((c) => c.replaceAll('|', r'\|').replaceAll('\n', ' ')).join(' | ')} |';
  final out = <String>[line(rows.first), '| ${rows.first.map((_) => '---').join(' | ')} |'];
  for (final r in rows.skip(1)) {
    out.add(line(r));
  }
  return out.join('\n');
}
