import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/services/file_store/file_store.dart';
import 'package:planova/services/file_store/io_file_store.dart';

void main() {
  late Directory tempDir;
  late IoFileStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('planova_test_');
    store = IoFileStore(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('IoFileStore.write', () {
    test('creates the file with the given content', () async {
      await store.write('new.md', 'hello');
      expect(await File('${tempDir.path}/new.md').readAsString(), 'hello');
    });

    test('creates parent directories as needed', () async {
      await store.write('a/b/deep.md', 'nested');
      expect(
          await File('${tempDir.path}/a/b/deep.md').readAsString(), 'nested');
    });

    test('overwrites an existing file', () async {
      await store.write('existing.md', 'old');
      await store.write('existing.md', 'new content');
      expect(await File('${tempDir.path}/existing.md').readAsString(),
          'new content');
    });

    test('leaves no temp file behind', () async {
      await store.write('clean.md', 'data');
      expect(File('${tempDir.path}/clean.md.tmp').existsSync(), isFalse);
    });

    test('rejects paths escaping the root', () async {
      await expectLater(
          store.write('../escape.md', 'x'), throwsA(isA<ArgumentError>()));
    });
  });

  group('IoFileStore.read', () {
    test('returns null for a missing file', () async {
      expect(await store.read('nope.md'), isNull);
    });

    test('round-trips written content', () async {
      await store.write('roundtrip.md', 'contenu accentué é à ü');
      expect(await store.read('roundtrip.md'), 'contenu accentué é à ü');
    });
  });

  group('IoFileStore.list', () {
    test('lists matching files with mtimes', () async {
      await store.write('dailies/20260713.md', 'today');
      await store.write('dailies/20260712.md', 'yesterday');
      await store.write('dailies/ignore.txt', 'nope');

      final entries = await store.list('dailies');
      final paths = entries.map((e) => e.relPath).toSet();
      expect(paths,
          {'dailies/20260713.md', 'dailies/20260712.md'});
      expect(entries.every((e) => e.modified != null), isTrue);
    });

    test('recursive listing includes subdirectories', () async {
      await store.write('notes/a.md', '1');
      await store.write('notes/sub/b.md', '2');

      final flat = await store.list('notes');
      expect(flat.map((e) => e.relPath).toSet(), {'notes/a.md'});

      final deep = await store.list('notes', recursive: true);
      expect(deep.map((e) => e.relPath).toSet(),
          {'notes/a.md', 'notes/sub/b.md'});
    });

    test('returns empty list for a missing directory', () async {
      expect(await store.list('absent'), isEmpty);
    });
  });

  group('IoFileStore misc', () {
    test('exists / modified / delete', () async {
      await store.write('x.md', 'x');
      expect(await store.exists('x.md'), isTrue);
      expect(await store.modified('x.md'), isNotNull);

      await store.delete('x.md');
      expect(await store.exists('x.md'), isFalse);
      expect(await store.modified('x.md'), isNull);
    });

    test('rename moves a file across directories', () async {
      await store.write('notes/old.md', 'content');
      await store.rename('notes/old.md', 'notes/sub/new.md');
      expect(await store.exists('notes/old.md'), isFalse);
      expect(await store.read('notes/sub/new.md'), 'content');
    });
  });

  group('normalizeRelPath', () {
    test('normalises separators and empty segments', () {
      expect(normalizeRelPath('a//b/./c.md'), 'a/b/c.md');
      expect(normalizeRelPath('/a/b.md/'), 'a/b.md');
      expect(normalizeRelPath(r'a\b.md'), 'a/b.md');
    });

    test('rejects parent-directory traversal', () {
      expect(() => normalizeRelPath('../x.md'), throwsArgumentError);
      expect(() => normalizeRelPath('a/../../x.md'), throwsArgumentError);
    });
  });
}
