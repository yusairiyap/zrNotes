@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zrnotes/data/local_cache.dart';

void main() {
  test('HiveCache keeps values across reopen in IndexedDB', () async {
    final a = HiveCache();
    await a.open('zrnotes_test');
    await a.putAll({'notes/1': '{"id":"1"}', 'outbox': '[]'});
    await a.deleteAll(['outbox']);
    await a.close();
    final b = HiveCache();
    await b.open('zrnotes_test');
    expect(b.get('notes/1'), '{"id":"1"}');
    expect(b.keys, ['notes/1']);
  });
}
