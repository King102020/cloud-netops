// Line coverage of hand-written code from coverage/lcov.info (STANDARDS §6:
// >= 70%). Generated code (API client, *.g.dart, l10n) is excluded.
// Usage: dart run tool/coverage_check.dart [minPercent]
import 'dart:io';

const excluded = [
  'lib/generated/',
  '.g.dart',
  'lib/l10n/gen/',
  'lib/main.dart',
];

void main(List<String> args) {
  final min = args.isEmpty ? 70.0 : double.parse(args.first);
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found: run flutter test --coverage first',
    );
    exit(2);
  }
  var file = '';
  var hit = 0;
  var total = 0;
  final perFile = <String, (int, int)>{};
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      file = line.substring(3).replaceAll(r'\', '/');
    } else if (line.startsWith('DA:') && !excluded.any(file.contains)) {
      final count = int.parse(line.split(',')[1]);
      total++;
      if (count > 0) {
        hit++;
      }
      final (h, t) = perFile[file] ?? (0, 0);
      perFile[file] = (h + (count > 0 ? 1 : 0), t + 1);
    }
  }
  final pct = total == 0 ? 0 : hit * 100 / total;
  final worst = perFile.entries.toList()
    ..sort(
      (a, b) => (a.value.$1 / a.value.$2).compareTo(b.value.$1 / b.value.$2),
    );
  for (final e in worst.take(5)) {
    stdout.writeln(
      '  ${(e.value.$1 * 100 / e.value.$2).toStringAsFixed(0).padLeft(3)}%  ${e.key}',
    );
  }
  stdout.writeln(
    'Coverage (hand-written code): ${pct.toStringAsFixed(1)}% ($hit/$total lines), minimum $min%',
  );
  if (pct < min) {
    exit(1);
  }
}
