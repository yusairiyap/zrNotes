import 'package:flutter_test/flutter_test.dart';
import 'package:zrnotes/models.dart';
import 'package:zrnotes/platform/home_widgets.dart';

void main() {
  test('widget picks pinned first, then newest, and skips subnotes', () {
    final notes = [
      Note(id: 'old', updatedAt: DateTime(2026, 1, 1)),
      Note(id: 'new', updatedAt: DateTime(2026, 3, 1)),
      Note(id: 'pin', pinned: true, updatedAt: DateTime(2025, 1, 1)),
      Note(id: 'sub', parentNoteId: 'new', updatedAt: DateTime(2026, 4, 1)),
    ];
    expect(HomeWidgets.pick(notes).map((n) => n.id), ['pin', 'new', 'old']);
    expect(HomeWidgets.pick(notes, max: 2).map((n) => n.id), ['pin', 'new']);
  });
}
