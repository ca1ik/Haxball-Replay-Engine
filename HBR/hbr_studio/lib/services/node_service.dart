import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/// NodeService: Calls Node.js CLI scripts and parses JSON progress lines.
class NodeService {
  // Path to the HBR folder (parent of the scripts)
  static String get _scriptDir {
    // In development the scripts are siblings of this Flutter project
    // Debug/release: executable is deep inside build/windows/
    // So we resolve relative to the script directory via an env var set at launch,
    // or fallback to the hardcoded path next to the project folder.
    return Platform.environment['HBR_SCRIPT_DIR'] ??
        p.normalize(p.join(p.dirname(Platform.script.toFilePath()), '..'));
  }

  /// Merge [filePaths] into [outputPath].
  /// Yields progress events as parsed Maps.
  static Stream<Map<String, dynamic>> merge({
    required List<String> filePaths,
    required String outputPath,
  }) {
    final scriptPath = p.join(_scriptDir, 'hbr_merge_cli.js');
    return _runScript(scriptPath, [outputPath, ...filePaths]);
  }

  /// Split [inputPath] at [splitFrame] → [output1Path] and [output2Path].
  static Stream<Map<String, dynamic>> split({
    required String inputPath,
    required String output1Path,
    required String output2Path,
    required int splitFrame,
  }) {
    final scriptPath = p.join(_scriptDir, 'hbr_split_cli.js');
    return _runScript(scriptPath, [
      inputPath,
      output1Path,
      output2Path,
      splitFrame.toString(),
    ]);
  }

  /// Runs [scriptPath] with [args] via `node`, yields JSON event maps.
  static Stream<Map<String, dynamic>> _runScript(
    String scriptPath,
    List<String> args,
  ) async* {
    Process process;
    try {
      process = await Process.start('node', [
        scriptPath,
        ...args,
      ], runInShell: true);
    } catch (e) {
      yield {'type': 'error', 'message': 'Failed to start node.js: $e'};
      return;
    }

    await for (final line
        in process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final json = jsonDecode(trimmed);
        if (json is Map<String, dynamic>) yield json;
      } catch (_) {
        // Non-JSON line — emit as raw info
        yield {'type': 'raw', 'message': trimmed};
      }
    }

    // Capture stderr for error reporting
    final stderrBuf = StringBuffer();
    await for (final chunk in process.stderr.transform(utf8.decoder)) {
      stderrBuf.write(chunk);
    }

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      yield {
        'type': 'error',
        'message': stderrBuf.toString().trim().isNotEmpty
            ? stderrBuf.toString().trim()
            : 'Process exited with code $exitCode',
      };
    }
  }

  /// Quick probe: read file header to get totalFrames (for the UI info display).
  /// Returns null if not a valid HBR2 file.
  static Future<Map<String, dynamic>?> probeFile(String filePath) async {
    final scriptPath = p.join(_scriptDir, 'hbr_probe_cli.js');
    Map<String, dynamic>? result;
    await for (final evt in _runScript(scriptPath, [filePath])) {
      if (evt['type'] == 'info') {
        result = evt;
        break;
      }
      if (evt['type'] == 'error') break;
    }
    return result;
  }
}

/// Converts HaxBall frames to a human-readable duration string.
/// HaxBall runs at 60 steps/second.
String framesToDuration(int frames) {
  final totalSec = (frames / 60).round();
  final m = totalSec ~/ 60;
  final s = totalSec % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Converts MM:SS string to frame number.
int durationToFrame(int minutes, int seconds) => (minutes * 60 + seconds) * 60;
