// lib/services/analyzer_service.dart
// Wraps hbr_analyze_cli.js to extract full match statistics

import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/match_stats.dart';

class AnalyzerService {
  static String get _scriptDir =>
      Platform.environment['HBR_SCRIPT_DIR'] ??
      p.join(
        p.dirname(Platform.resolvedExecutable),
        '..',
        '..',
        '..',
        '..',
        '..',
        'HBR',
      );

  static String get _analyzeScript => p.join(_scriptDir, 'hbr_analyze_cli.js');

  /// Analyze a replay file and return full match stats.
  static Future<MatchStats> analyze(String filePath) async {
    final result = await Process.run(
      'node',
      [_analyzeScript, filePath],
      runInShell: true,
      stdoutEncoding: const Utf8Codec(allowMalformed: true),
      stderrEncoding: const Utf8Codec(allowMalformed: true),
    );

    final lines = (result.stdout as String).trim().split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, dynamic>;
        if (json['type'] == 'stats') {
          return MatchStats.fromJson(json);
        }
        if (json['type'] == 'error') {
          throw Exception(json['message'] as String? ?? 'Analyzer error');
        }
      } catch (e) {
        if (e is Exception) rethrow;
        // skip malformed lines
      }
    }
    throw Exception('No stats output from analyzer');
  }
}
