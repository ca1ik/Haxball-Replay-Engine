// lib/services/frame_service.dart
// Calls hbr_frame_cli.js and streams per-frame position data for the match viewer.
//
// The CLI outputs JSON lines: meta → frame* → done | error
// We parse the stream progressively and report loading progress via [onProgress].

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/frame_data.dart';

class FrameService {
  /// Sample every N simulation frames (default 30 = ~0.5 s at 60fps).
  static const int defaultSampleRate = 30;

  static String get _scriptDir =>
      Platform.environment['HBR_SCRIPT_DIR'] ??
      p.normalize(
        p.join(
          p.dirname(Platform.resolvedExecutable),
          '..',
          '..',
          '..',
          '..',
          '..',
          '..',
          'EngineX',
        ),
      );

  static String get _frameScript => p.join(_scriptDir, 'hbr_frame_cli.js');

  /// Load all sampled frames for [filePath].
  ///
  /// [onProgress] receives (loadedFrames, totalFrames) whenever a new frame
  /// arrives. Called on the isolate thread — caller must marshal to UI thread
  /// if needed (use setState/Provider inside a StreamController or similar).
  static Future<ReplaySession> load(
    String filePath, {
    int sampleRate = defaultSampleRate,
    void Function(int loaded, int total)? onProgress,
  }) async {
    final process = await Process.start('node', [
      _frameScript,
      filePath,
      sampleRate.toString(),
    ], runInShell: true);

    FrameMeta? meta;
    final frames = <FrameData>[];
    int totalEstimate = 0;
    String? errorMsg;

    // Combine stdout + stderr for parsing; stderr goes to debug output
    final stderrSub = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen((_) {}); // suppress

    final completer = Completer<void>();

    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.trim().isEmpty) return;
            try {
              final json = jsonDecode(line) as Map<String, dynamic>;
              switch (json['type'] as String?) {
                case 'meta':
                  meta = FrameMeta.fromJson(json);
                  totalEstimate =
                      meta!.totalFrames ~/ sampleRate +
                      1; // approx keyframe count
                case 'frame':
                  frames.add(FrameData.fromJson(json));
                  onProgress?.call(frames.length, totalEstimate);
                case 'done':
                  completer.complete();
                case 'error':
                  errorMsg = json['message'] as String? ?? 'Frame CLI error';
                  completer.complete();
              }
            } catch (_) {
              // Ignore malformed lines
            }
          },
          onError: (e) {
            errorMsg = e.toString();
            if (!completer.isCompleted) completer.complete();
          },
          onDone: () {
            if (!completer.isCompleted) completer.complete();
          },
        );

    await completer.future;
    await stderrSub.cancel();
    await process.exitCode; // wait for process to fully exit

    if (errorMsg != null) throw Exception(errorMsg);
    if (meta == null) throw Exception('No metadata received from frame CLI');
    if (frames.isEmpty) throw Exception('No frames extracted from replay');

    // Sort frames by frame number (should already be sorted, but defensive)
    frames.sort((a, b) => a.frame.compareTo(b.frame));

    return ReplaySession(filePath: filePath, meta: meta!, frames: frames);
  }
}
