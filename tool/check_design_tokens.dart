import 'dart:io';

final _forbidden = <(String, RegExp)>[
  ('Color literal', RegExp(r'Color\s*\(\s*0x[0-9A-Fa-f]+\s*\)')),
  (
    'hard-coded fontSize',
    RegExp(r'\bfontSize\s*:\s*(?:\d+(?:\.\d+)?|[^,\n?]+\?\s*\d+(?:\.\d+)?)'),
  ),
  ('fontFamily declaration', RegExp(r'\bfontFamily\s*:')),
];

void main() {
  final lib = Directory('lib');
  if (!lib.existsSync()) {
    stderr.writeln('Không tìm thấy thư mục lib/. Hãy chạy từ gốc dự án.');
    exitCode = 2;
    return;
  }

  final violations = <String>[];
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final normalized = entity.path.replaceAll('\\', '/');
    if (normalized.startsWith('lib/core/design/')) continue;
    final lines = entity.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      for (final (label, pattern) in _forbidden) {
        if (pattern.hasMatch(lines[index])) {
          violations.add('${entity.path}:${index + 1}: $label');
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('DESIGN TOKENS: PASS');
    return;
  }
  stderr.writeln('DESIGN TOKENS: FAIL (${violations.length} vi phạm)');
  for (final violation in violations) {
    stderr.writeln(violation);
  }
  exitCode = 1;
}
