/// Plain data classes that mirror the Supabase tables.
library;

class Folder {
  Folder({required this.id, required this.name, this.parentId, this.icon, this.sortOrder = 0});
  final String id;
  String name;
  String? parentId;

  /// `icon:name` or `emoji:character`; null shows the default folder icon.
  String? icon;
  double sortOrder;

  factory Folder.fromRow(Map<String, dynamic> r) => Folder(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '',
        parentId: r['parent_id'] as String?,
        icon: r['icon'] as String?,
        sortOrder: (r['sort_order'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toRow() => {'id': id, 'name': name, 'parent_id': parentId, 'icon': icon, 'sort_order': sortOrder};
}

class Note {
  Note({
    required this.id,
    this.title = 'Untitled',
    this.description = '',
    this.folderId,
    this.parentNoteId,
    this.color,
    this.icon,
    this.pinned = false,
    this.sortOrder = 0,
    this.todoTotal = 0,
    this.todoDone = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String description;
  String? folderId;
  String? parentNoteId;
  int? color;
  String? icon;
  bool pinned;
  double sortOrder;

  /// Checklist items across the note's sections, kept here so lists can show progress.
  int todoTotal;
  int todoDone;
  DateTime updatedAt;

  bool get isSubnote => parentNoteId != null;

  factory Note.fromRow(Map<String, dynamic> r) => Note(
        id: r['id'] as String,
        title: (r['title'] as String?) ?? '',
        description: (r['description'] as String?) ?? '',
        folderId: r['folder_id'] as String?,
        parentNoteId: r['parent_note_id'] as String?,
        color: (r['color'] as num?)?.toInt(),
        icon: r['icon'] as String?,
        pinned: (r['pinned'] as bool?) ?? false,
        sortOrder: (r['sort_order'] as num?)?.toDouble() ?? 0,
        todoTotal: (r['todo_total'] as num?)?.toInt() ?? 0,
        todoDone: (r['todo_done'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse((r['updated_at'] as String?) ?? ''),
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'title': title,
        'description': description,
        'folder_id': folderId,
        'parent_note_id': parentNoteId,
        'color': color,
        'icon': icon,
        'pinned': pinned,
        'sort_order': sortOrder,
        'todo_total': todoTotal,
        'todo_done': todoDone,
      };
}

/// What sits on a section's tab beside its title.
enum HeaderKind { none, icon, emoji, image }

/// A draggable box on a note's canvas. [content] is a Quill Delta (JSON list).
class Section {
  Section({
    required this.id,
    required this.noteId,
    this.title = '',
    this.headerKind = HeaderKind.none,
    this.headerValue,
    this.color,
    this.x = 0,
    this.y = 0,
    this.width = 360,
    this.zIndex = 0,
    this.content,
  });

  final String id;
  final String noteId;
  String title;
  HeaderKind headerKind;
  String? headerValue;
  int? color;
  double x;
  double y;
  double width;
  int zIndex;
  List<dynamic>? content;

  bool get hasHeader => title.isNotEmpty || headerKind != HeaderKind.none;

  factory Section.fromRow(Map<String, dynamic> r) => Section(
        id: r['id'] as String,
        noteId: r['note_id'] as String,
        title: (r['title'] as String?) ?? '',
        headerKind: HeaderKind.values.firstWhere(
          (k) => k.name == r['header_kind'],
          orElse: () => HeaderKind.none,
        ),
        headerValue: r['header_value'] as String?,
        color: (r['color'] as num?)?.toInt(),
        x: (r['x'] as num?)?.toDouble() ?? 0,
        y: (r['y'] as num?)?.toDouble() ?? 0,
        width: (r['width'] as num?)?.toDouble() ?? 360,
        zIndex: (r['z_index'] as num?)?.toInt() ?? 0,
        content: r['content'] as List<dynamic>?,
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'note_id': noteId,
        'title': title,
        'header_kind': headerKind.name,
        'header_value': headerValue,
        'color': color,
        'x': x,
        'y': y,
        'width': width,
        'z_index': zIndex,
        'content': content,
      };
}
