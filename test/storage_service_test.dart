import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planova/services/storage_service.dart';

void main() {
  late Directory tempDir;
  final storage = StorageService();

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('planova_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('StorageService.writeFile', () {
    test('creates the file with the given content', () async {
      final file = File('${tempDir.path}/new.md');
      await storage.writeFile(file, 'hello');
      expect(await file.readAsString(), 'hello');
    });

    test('overwrites an existing file', () async {
      final file = File('${tempDir.path}/existing.md');
      await file.writeAsString('old');
      await storage.writeFile(file, 'new content');
      expect(await file.readAsString(), 'new content');
    });

    test('leaves no temp file behind', () async {
      final file = File('${tempDir.path}/clean.md');
      await storage.writeFile(file, 'data');
      expect(File('${file.path}.tmp').existsSync(), isFalse);
    });

    test('does not touch the target when the write location is invalid',
        () async {
      final file = File('${tempDir.path}/missing_dir/file.md');
      await expectLater(storage.writeFile(file, 'x'), throwsA(anything));
      expect(file.existsSync(), isFalse);
    });
  });

  group('StorageService.readFile', () {
    test('returns empty string for a missing file', () async {
      expect(await storage.readFile(File('${tempDir.path}/nope.md')), '');
    });

    test('round-trips written content', () async {
      final file = File('${tempDir.path}/roundtrip.md');
      await storage.writeFile(file, 'contenu accentué é à ü');
      expect(await storage.readFile(file), 'contenu accentué é à ü');
    });
  });
}
