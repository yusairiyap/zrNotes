import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

/// A small string key-value store on the device. Reads are synchronous
/// because the whole box is held in memory once it is open.
abstract class LocalCache {
  Future<void> open(String name);
  String? get(String key);
  Iterable<String> get keys;
  Future<void> putAll(Map<String, String> entries);
  Future<void> deleteAll(Iterable<String> keys);
  Future<void> close();
}

/// Hive keeps the box in IndexedDB on the web and in a file in the app's
/// support folder everywhere else, so the same code works on every platform.
class HiveCache implements LocalCache {
  static Future<void>? _init;
  Box<String>? _box;

  static Future<void> _initOnce() => _init ??= () async {
        if (!kIsWeb) Hive.init((await getApplicationSupportDirectory()).path);
      }();

  @override
  Future<void> open(String name) async {
    await _initOnce();
    _box = await Hive.openBox<String>(name);
  }

  @override
  String? get(String key) => _box!.get(key);

  @override
  Iterable<String> get keys => _box!.keys.cast<String>();

  @override
  Future<void> putAll(Map<String, String> entries) => _box!.putAll(entries);

  @override
  Future<void> deleteAll(Iterable<String> keys) => _box!.deleteAll(keys);

  @override
  Future<void> close() async => _box?.close();
}

/// In-memory stand-in for tests.
class MemoryCache implements LocalCache {
  final Map<String, String> data = {};

  @override
  Future<void> open(String name) async {}

  @override
  String? get(String key) => data[key];

  @override
  Iterable<String> get keys => data.keys.toList();

  @override
  Future<void> putAll(Map<String, String> entries) async => data.addAll(entries);

  @override
  Future<void> deleteAll(Iterable<String> keys) async => keys.toList().forEach(data.remove);

  @override
  Future<void> close() async {}
}
