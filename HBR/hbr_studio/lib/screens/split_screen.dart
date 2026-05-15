import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/node_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

// ── Recent clip record ────────────────────────────────────────────────────
class _RecentClip {
  final String name;
  final String path;
  final String duration;
  final String sourceName;
  final DateTime createdAt;
  _RecentClip({
    required this.name,
    required this.path,
    required this.duration,
    required this.sourceName,
    required this.createdAt,
  });
}

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  String? _inputPath;
  Map<String, dynamic>? _fileInfo;
  bool _probing = false;
  bool _dragging = false;
  bool _dropHover = false;
  bool _running = false;

  // Trim time controllers — START
  final _minCtrl = TextEditingController(text: '0');
  final _secCtrl = TextEditingController(text: '50');

  // END time controllers
  final _endMinCtrl = TextEditingController(text: '1');
  final _endSecCtrl = TextEditingController(text: '15');

  String? _outputDir; // selected output directory
  String? _lastOutputPath; // last written file (for "open folder")
  final List<String> _logLines = [];
  final List<_RecentClip> _recentClips = [];
  double _progress = 0;
  String? _resultMessage;
  bool _success = false;

  @override
  void dispose() {
    _minCtrl.dispose();
    _secCtrl.dispose();
    _endMinCtrl.dispose();
    _endSecCtrl.dispose();
    super.dispose();
  }

  int get _splitFrame {
    final m = int.tryParse(_minCtrl.text) ?? 0;
    final s = int.tryParse(_secCtrl.text) ?? 0;
    return durationToFrame(m, s);
  }

  int get _endFrame {
    final m = int.tryParse(_endMinCtrl.text) ?? 0;
    final s = int.tryParse(_endSecCtrl.text) ?? 0;
    return durationToFrame(m, s);
  }

  int get _totalFrames => _fileInfo?['totalFrames'] as int? ?? 0;

  double get _startRatio =>
      _totalFrames > 0 ? (_splitFrame / _totalFrames).clamp(0.0, 1.0) : 0.0;

  double get _endRatio =>
      _totalFrames > 0 ? (_endFrame / _totalFrames).clamp(0.0, 1.0) : 0.0;

  // ── File loading ──────────────────────────────────────────────────────────
  void _loadFile(String path) async {
    if (!path.toLowerCase().endsWith('.hbr2')) return;
    setState(() {
      _inputPath = path;
      _fileInfo = null;
      _probing = true;
      _logLines.clear();
      _resultMessage = null;
    });
    final info = await NodeService.probeFile(path);
    if (mounted)
      setState(() {
        _fileInfo = info;
        _probing = false;
      });
  }

  Future<void> _pickInput() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['hbr2'],
    );
    if (result?.files.first.path != null) _loadFile(result!.files.first.path!);
  }

  Future<void> _pickOutput() async {
    final downloadsDir = (await getDownloadsDirectory())?.path;
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose output folder...',
      initialDirectory: downloadsDir,
    );
    if (result != null) setState(() => _outputDir = result);
  }

  Future<void> _runSplit() async {
    if (_inputPath == null || _totalFrames == 0 || _running) return;
    final sf = _splitFrame;
    final ef = _endFrame;
    if (sf < 0 || ef <= sf || ef > _totalFrames) return;

    final downloadsDir =
        (await getDownloadsDirectory())?.path ??
        (await getTemporaryDirectory()).path;
    final outDir = _outputDir ?? downloadsDir;
    final base = p.basenameWithoutExtension(_inputPath!);
    final out = p.join(outDir, '${base}_clip.hbr2');

    setState(() {
      _running = true;
      _logLines.clear();
      _progress = 0;
      _resultMessage = null;
      _success = false;
    });

    int step = 0;
    const totalSteps = 4; // read, decode, trim, write

    await for (final evt in NodeService.trim(
      inputPath: _inputPath!,
      outputPath: out,
      startFrame: sf,
      endFrame: ef,
    )) {
      if (!mounted) break;
      setState(() {
        final type = evt['type'] as String? ?? '';
        switch (type) {
          case 'progress':
            step++;
            _progress = step / totalSteps;
            _logLines.add(_progressLabel(evt));
            break;
          case 'info':
            final tf = evt['totalFrames'];
            if (tf != null) {
              _logLines.add(
                '  Source: $tf frames (${framesToDuration(tf as int)})',
              );
            } else if (evt['events'] != null) {
              _logLines.add(
                '  Events: ${evt['events']} · Goals: ${evt['goals']}',
              );
            }
            break;
          case 'done':
            _progress = 1.0;
            _success = true;
            _lastOutputPath = evt['output'] as String?;
            final size = ((evt['bytes'] as int? ?? 0) / 1024).toStringAsFixed(
              1,
            );
            _resultMessage =
                'Clip (${framesToDuration(sf)}–${framesToDuration(ef)}) → ${size} KB';
            _logLines.add(
              'Done! ${evt['frames']} frames · ${evt['goals']} goals',
            );
            if (_lastOutputPath != null) {
              _recentClips.insert(
                0,
                _RecentClip(
                  name: p.basename(_lastOutputPath!),
                  path: _lastOutputPath!,
                  duration: '${framesToDuration(sf)} – ${framesToDuration(ef)}',
                  sourceName: p.basename(_inputPath!),
                  createdAt: DateTime.now(),
                ),
              );
            }
            break;
          case 'error':
            _success = false;
            _resultMessage = evt['message'] as String? ?? 'Unknown error';
            _logLines.add('Error: $_resultMessage');
            break;
        }
      });
    }

    if (mounted) setState(() => _running = false);
  }

  String _progressLabel(Map<String, dynamic> evt) {
    final step = evt['step'] as String? ?? '';
    switch (step) {
      case 'reading':
        return 'Reading ${evt['name']}...';
      case 'decoding':
        return 'Decoding payload...';
      case 'trimming':
        return 'Extracting segment...';
      case 'building_part1':
        return 'Building Part 1...';
      case 'building_part2':
        return 'Building Part 2...';
      case 'writing':
        return 'Writing ${p.basename(evt['output'] as String? ?? '')}...';
      default:
        return step;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildLeftPanel()),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _buildRightPanel()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppTheme.purpleGrad,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.content_cut_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Split Replay',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimOf(context),
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            'Cut a time range from a .hbr2 replay and save it as a new clip',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecOf(context),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
      const Spacer(),
      if (_fileInfo != null)
        StatusBadge(
          label: framesToDuration(_totalFrames),
          color: AppTheme.purple,
        ).animate().fadeIn(duration: 300.ms),
    ],
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);

  Widget _buildLeftPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildDropZone(),
      if (_fileInfo != null) ...[
        const SizedBox(height: 20),
        _buildFileInfo(),
        const SizedBox(height: 20),
        _buildSplitControls(),
        const SizedBox(height: 20),
        _buildOutputSelector(),
        const SizedBox(height: 16),
        _buildExtractButton(),
      ],
    ],
  );

  Widget _buildDropZone() => DropTarget(
    onDragDone: (detail) {
      if (detail.files.isNotEmpty) _loadFile(detail.files.first.path);
    },
    onDragEntered: (_) => setState(() => _dragging = true),
    onDragExited: (_) => setState(() => _dragging = false),
    child: MouseRegion(
      onEnter: (_) => setState(() => _dropHover = true),
      onExit: (_) => setState(() => _dropHover = false),
      child: AnimatedScale(
        scale: _dropHover ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: _running ? null : _pickInput,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _dragging
                  ? AppTheme.purple.withOpacity(0.06)
                  : (_inputPath != null
                        ? AppTheme.surfaceOf(context)
                        : AppTheme.surfaceOf(context)),
              border: Border.all(
                color: _dragging
                    ? AppTheme.purple
                    : (_dropHover
                          ? AppTheme.purple.withOpacity(0.7)
                          : (_inputPath != null
                                ? AppTheme.purple.withOpacity(0.4)
                                : AppTheme.borderOf(context))),
                width: _dragging
                    ? 2
                    : (_dropHover ? 1.8 : (_inputPath != null ? 1.5 : 1)),
              ),
              boxShadow: _dropHover
                  ? [
                      BoxShadow(
                        color: AppTheme.purple.withOpacity(0.30),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFF4A6CF7).withOpacity(0.18),
                        blurRadius: 30,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Center(
          child: _inputPath != null
              ? _probing
                    ? const CircularProgressIndicator(
                        color: AppTheme.purple,
                        strokeWidth: 2,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.movie_rounded,
                              color: AppTheme.purple,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Click to change file',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textHintOf(context),
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _dragging
                          ? Icons.file_download_rounded
                          : Icons.add_circle_outline_rounded,
                      size: 32,
                      color: _dragging ? AppTheme.purple : AppTheme.textHint,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dragging ? 'Drop file here' : 'Drag & drop a .hbr2 file',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _dragging
                            ? AppTheme.purple
                            : AppTheme.textSecOf(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'or click to browse',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textHintOf(context),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
        ),
          ),
        ),
      ),
    ),
  ).animate().fadeIn(duration: 500.ms, delay: 100.ms);

  Widget _buildFileInfo() {
    final info = _fileInfo!;
    return Row(
      children: [
        InfoChip(
          icon: Icons.timer_outlined,
          label: 'Duration',
          value: framesToDuration(info['totalFrames'] as int),
        ),
        const SizedBox(width: 8),
        InfoChip(
          icon: Icons.sports_soccer_rounded,
          label: 'Goals',
          value: '${info['goals']}',
        ),
        const SizedBox(width: 8),
        InfoChip(
          icon: Icons.event_note_rounded,
          label: 'Frames',
          value: '${info['totalFrames']}',
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSplitControls() => Material(
    type: MaterialType.transparency,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Trim range'),
        const SizedBox(height: 12),
        // START time
        Row(
          children: [
            Text(
              'Start',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 12),
            _timeField(_minCtrl, 'min', 0, 999),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSec,
                ),
              ),
            ),
            _timeField(_secCtrl, 'sec', 0, 59),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Text(
                'Frame $_splitFrame',
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // END time
        Row(
          children: [
            Text(
              'End  ',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.purple,
              ),
            ),
            const SizedBox(width: 12),
            _timeField(_endMinCtrl, 'min', 0, 999),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSec,
                ),
              ),
            ),
            _timeField(_endSecCtrl, 'sec', 0, 59),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.purple.withOpacity(0.3)),
              ),
              child: Text(
                'Frame $_endFrame',
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  color: AppTheme.purple,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_totalFrames > 0) _buildTimeline(),
      ],
    ),
  ).animate().fadeIn(duration: 300.ms, delay: 100.ms);

  Widget _timeField(
    TextEditingController ctrl,
    String label,
    int min,
    int max,
  ) => SizedBox(
    width: 72,
    child: TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimOf(context),
        decoration: TextDecoration.none,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 10,
          color: AppTheme.textHintOf(context),
          decoration: TextDecoration.none,
        ),
        filled: true,
        fillColor: AppTheme.surfaceOf(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.borderOf(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppTheme.borderOf(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.purple, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      ),
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _buildTimeline() {
    final startRatio = _startRatio;
    final endRatio = _endRatio;
    final startMin = _minCtrl.text.padLeft(2, '0');
    final startSec = _secCtrl.text.padLeft(2, '0');
    final endMin = _endMinCtrl.text.padLeft(2, '0');
    final endSec = _endSecCtrl.text.padLeft(2, '0');
    final totalDur = framesToDuration(_totalFrames);
    final clipFrames = (_endFrame - _splitFrame).clamp(0, _totalFrames);
    final clipDur = framesToDuration(clipFrames);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Start slider
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbColor: AppTheme.accent,
            activeTrackColor: AppTheme.accent,
            inactiveTrackColor: AppTheme.border,
            overlayColor: AppTheme.accent.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: startRatio,
            onChanged: (v) {
              final frame = (v * _totalFrames).round();
              final totalSec = (frame / 60).round();
              setState(() {
                _minCtrl.text = (totalSec ~/ 60).toString();
                _secCtrl.text = (totalSec % 60).toString().padLeft(2, '0');
              });
            },
          ),
        ),
        // End slider
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbColor: AppTheme.purple,
            activeTrackColor: AppTheme.purple,
            inactiveTrackColor: AppTheme.border,
            overlayColor: AppTheme.purple.withOpacity(0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: endRatio,
            onChanged: (v) {
              final frame = (v * _totalFrames).round();
              final totalSec = (frame / 60).round();
              setState(() {
                _endMinCtrl.text = (totalSec ~/ 60).toString();
                _endSecCtrl.text = (totalSec % 60).toString().padLeft(2, '0');
              });
            },
          ),
        ),
        // Time labels row
        Row(
          children: [
            Text(
              '00:00',
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textHint),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$startMin:$startSec',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$endMin:$endSec',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.purple,
                ),
              ),
            ),
            const Spacer(),
            Text(
              totalDur,
              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textHint),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Visual segment bar
        LayoutBuilder(
          builder: (_, c) => Stack(
            children: [
              Container(
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
              ),
              if (endRatio > startRatio)
                Positioned(
                  left: c.maxWidth * startRatio,
                  width: c.maxWidth * (endRatio - startRatio),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withOpacity(0.25),
                          AppTheme.purple.withOpacity(0.25),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        'Clip  $clipDur',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrim,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutputSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Output Folder'),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _running ? null : _pickOutput,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _outputDir != null
                  ? AppTheme.purple.withOpacity(0.3)
                  : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_rounded,
                size: 15,
                color: _outputDir != null ? AppTheme.purple : AppTheme.textHint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _outputDir ?? 'Downloads (default)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _outputDir != null
                        ? AppTheme.textPrim
                        : AppTheme.textHint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Browse',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ).animate().fadeIn(duration: 300.ms, delay: 150.ms);

  Widget _buildExtractButton() => Row(
    children: [
      Expanded(
        child: GradientButton(
          label: _running ? 'Extracting...' : 'Extract Clip',
          icon: Icons.cut_rounded,
          onPressed:
              (_inputPath != null &&
                  _totalFrames > 0 &&
                  _endFrame > _splitFrame &&
                  _endFrame <= _totalFrames &&
                  !_running)
              ? _runSplit
              : null,
          loading: _running,
          secondary: true,
        ),
      ),
    ],
  );

  static const _guideSteps = [
    (
      AppTheme.purple,
      'Drop your .hbr2 file',
      'Drag a single replay file onto the left panel. The app reads total frame count and duration — no guessing needed.',
    ),
    (
      AppTheme.accent,
      'Set the split point',
      'Enter MM:SS in the time field or drag the timeline divider. At 60 fps, "45:00" maps to frame 162,000 exactly.',
    ),
    (
      Color(0xFF4A6CF7),
      'Pick output folder',
      'Set where to save Part 1 and Part 2. Defaults to your Downloads folder.',
    ),
    (
      Color(0xFFFF8C42),
      'Click Split Replay',
      'Events are partitioned at the split frame. Part 2 frame numbers are re-offset to start at 0. Both files are valid standalone HBR2 replays.',
    ),
  ];

  Widget _buildRightPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GradientSectionLabel(_logLines.isNotEmpty ? 'Output Log' : 'Process Steps'),
      const SizedBox(height: 8),
      if (_logLines.isNotEmpty)
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260, minHeight: 60),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: _logLines.length,
              itemBuilder: (_, i) => LogLine(_logLines[i]),
            ),
          ),
        )
      else
        ..._guideSteps.asMap().entries.map(
          (e) => StepCard(
            index: e.key + 1,
            title: e.value.$2,
            description: e.value.$3,
            color: e.value.$1,
          ),
        ),
      const SizedBox(height: 16),
      if (_running || _progress > 0) _buildProgressBar(),
      if (_resultMessage != null) ...[
        const SizedBox(height: 12),
        _buildResultBanner(),
      ],
      _buildRecentClips(),
    ],
  ).animate().fadeIn(duration: 500.ms, delay: 200.ms);

  Widget _buildRecentClips() {
    if (_recentClips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SectionLabel('Recent Clips'),
        const SizedBox(height: 8),
        ..._recentClips.map(_buildRecentClipCard),
      ],
    );
  }

  Widget _buildRecentClipCard(_RecentClip clip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => _loadFile(clip.path),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.video_file_rounded,
                size: 15,
                color: AppTheme.purple,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clip.name,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimOf(context),
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    clip.duration,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppTheme.textHint,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Source: ${clip.sourceName}',
              child: const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 250.ms),
    );
  }

  Widget _buildProgressBar() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const SectionLabel('Progress'),
          const Spacer(),
          Text(
            '${(_progress * 100).toInt()}%',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.purple,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _progress,
          backgroundColor: AppTheme.border,
          valueColor: const AlwaysStoppedAnimation(AppTheme.purple),
          minHeight: 6,
        ),
      ),
    ],
  );

  Widget _buildResultBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: (_success ? AppTheme.success : AppTheme.danger).withOpacity(0.08),
      border: Border.all(
        color: (_success ? AppTheme.success : AppTheme.danger).withOpacity(0.3),
      ),
    ),
    child: Row(
      children: [
        Icon(
          _success
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          size: 16,
          color: _success ? AppTheme.success : AppTheme.danger,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _resultMessage!,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _success ? AppTheme.success : AppTheme.danger,
            ),
          ),
        ),
        if (_success)
          GestureDetector(
            onTap: () {
              final dir = _lastOutputPath != null
                  ? p.dirname(_lastOutputPath!)
                  : _outputDir;
              if (dir != null) Process.run('explorer', [dir]);
            },
            child: Text(
              'Open folder',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.accent,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    ),
  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
}
