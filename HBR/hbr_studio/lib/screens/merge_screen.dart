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

class ReplayFile {
  final String path;
  final String name;
  Map<String, dynamic>? info;
  bool probing = true;

  ReplayFile({required this.path}) : name = p.basename(path);
}

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<ReplayFile> _files = [];
  bool _dragging = false;
  bool _running = false;
  String? _outputDir; // selected directory
  String? _lastOutputPath; // last written file
  final List<String> _logLines = [];
  double _progress = 0;
  String? _resultMessage;
  bool _success = false;

  // ── File handling ─────────────────────────────────────────────────────────
  void _addFiles(List<String> paths) async {
    final newFiles = paths
        .where((p) => p.toLowerCase().endsWith('.hbr2'))
        .map((p) => ReplayFile(path: p))
        .toList();
    if (newFiles.isEmpty) return;

    // Enforce maximum 2 files
    final slots = 2 - _files.length;
    if (slots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2 files — remove one first.')),
      );
      return;
    }
    final toAdd = newFiles.take(slots).toList();
    setState(() => _files.addAll(toAdd));
    for (final f in toAdd) {
      _probeFile(f);
    }
  }

  Future<void> _probeFile(ReplayFile f) async {
    final info = await NodeService.probeFile(f.path);
    if (mounted)
      setState(() {
        f.info = info;
        f.probing = false;
      });
  }

  Future<void> _pickFiles() async {
    if (_files.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2 files — remove one first.')),
      );
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: _files.isEmpty, // pick 2 at once only when empty
      type: FileType.custom,
      allowedExtensions: ['hbr2'],
    );
    if (result != null) {
      _addFiles(result.files.map((f) => f.path!).toList());
    }
  }

  Future<void> _pickOutput() async {
    final downloadsDir = (await getDownloadsDirectory())?.path;
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose output folder...',
      initialDirectory: downloadsDir,
    );
    if (result != null) setState(() => _outputDir = result);
  }

  Future<void> _runMerge() async {
    if (_files.length < 2) return;
    final outPath = await _buildOutPath();

    setState(() {
      _running = true;
      _logLines.clear();
      _progress = 0;
      _resultMessage = null;
      _success = false;
    });

    int totalSteps = _files.length + 1; // reading + merging pairs + writing
    int step = 0;

    await for (final evt in NodeService.merge(
      filePaths: _files.map((f) => f.path).toList(),
      outputPath: outPath,
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
            _logLines.add(
              '  File ${evt['file']}: ${evt['frames']} frames, ${evt['goals']} goals',
            );
            break;
          case 'done':
            _progress = 1.0;
            _success = true;
            _lastOutputPath = evt['output'] as String?;
            final size = ((evt['bytes'] as int? ?? 0) / 1024).toStringAsFixed(
              1,
            );
            _resultMessage =
                'Merged ${_files.length} files → ${p.basename(_lastOutputPath!)}  (${size} KB)';
            _logLines.add(
              'Done! ${evt['frames']} frames · ${evt['events']} events · ${evt['goals']} goals',
            );
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
        return 'Reading file ${evt['file']}/${evt['total']}: ${evt['name']}';
      case 'merging':
        return 'Merging pair ${evt['pair']}/${evt['total']}...';
      case 'writing':
        return 'Writing ${p.basename(evt['output'] as String? ?? '')}...';
      default:
        return step;
    }
  }

  Future<String> _buildOutPath() async {
    final dir = _outputDir ?? await _defaultOutputDir();
    return p.join(dir, 'merged_${DateTime.now().millisecondsSinceEpoch}.hbr2');
  }

  Future<String> _defaultOutputDir() async {
    final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
    return dir.path;
  }

  void _removeFile(int index) => setState(() => _files.removeAt(index));

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _files.removeAt(oldIndex);
      _files.insert(newIndex, item);
    });
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
          gradient: AppTheme.accentGrad,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.merge_type_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Merge Replays',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimOf(context),
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            'Combine 2 .hbr2 replays into one continuous file',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecOf(context),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
      const Spacer(),
      StatusBadge(
        label: _files.length >= 2
            ? '2 / 2 ready'
            : '${_files.length} / 2 loaded',
        color: _files.length >= 2 ? AppTheme.accent : AppTheme.textHint,
      ).animate().fadeIn(duration: 300.ms),
    ],
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1);

  Widget _buildLeftPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildDropZone(),
      if (_files.isNotEmpty) ...[const SizedBox(height: 16), _buildFileList()],
      const SizedBox(height: 16),
      _buildOutputSelector(),
      const SizedBox(height: 16),
      _buildMergeButton(),
    ],
  );

  Widget _buildDropZone() => DropTarget(
    onDragDone: (detail) => _addFiles(detail.files.map((f) => f.path).toList()),
    onDragEntered: (_) => setState(() => _dragging = true),
    onDragExited: (_) => setState(() => _dragging = false),
    child: GestureDetector(
      onTap: _running ? null : _pickFiles,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _dragging
              ? AppTheme.accent.withOpacity(0.06)
              : AppTheme.surfaceOf(context),
          border: Border.all(
            color: _dragging ? AppTheme.accent : AppTheme.borderOf(context),
            width: _dragging ? 2 : 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _dragging
                    ? Icons.file_download_rounded
                    : Icons.add_circle_outline_rounded,
                size: 36,
                color: _dragging ? AppTheme.accent : AppTheme.textHint,
              ),
              const SizedBox(height: 10),
              Text(
                _dragging
                    ? 'Drop .hbr2 file here'
                    : _files.isEmpty
                    ? 'Drag & drop 2 .hbr2 files'
                    : 'Drop the 2nd .hbr2 file',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _dragging
                      ? AppTheme.accent
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
  ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.05);

  Widget _buildFileList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SectionLabel('Files  ·  exactly 2 required'),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _files.clear()),
              child: Text(
                'Clear all',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.danger),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _files.length,
          onReorder: _reorder,
          proxyDecorator: (child, _, __) =>
              Material(color: Colors.transparent, child: child),
          itemBuilder: (ctx, i) => _buildFileCard(_files[i], i),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildFileCard(ReplayFile f, int index) {
    final info = f.info;
    final frames = info?['totalFrames'] as int?;
    final goals = info?['goals'] as int?;

    return Padding(
      key: ValueKey(f.path),
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: AppTheme.cardGradOf(context),
          border: Border.all(color: AppTheme.borderOf(context)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 6,
            ),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accentGrad.colors.first.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ),
            title: Text(
              f.name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimOf(context),
                decoration: TextDecoration.none,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: f.probing
                ? Text(
                    'Analysing...',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textHint,
                    ),
                  )
                : Row(
                    children: [
                      if (frames != null) ...[
                        Icon(
                          Icons.timer_outlined,
                          size: 11,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          framesToDuration(frames),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textSec,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (goals != null) ...[
                        Icon(
                          Icons.sports_soccer_rounded,
                          size: 11,
                          color: AppTheme.textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$goals goals',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textSec,
                          ),
                        ),
                      ],
                    ],
                  ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.drag_handle_rounded,
                  color: AppTheme.textHint,
                  size: 18,
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _removeFile(index),
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textHint,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutputSelector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Output File'),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _running ? null : _pickOutput,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_rounded,
                size: 15,
                color: _outputDir != null ? AppTheme.accent : AppTheme.textHint,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _outputDir ?? 'Downloads (default)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
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
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildMergeButton() => Row(
    children: [
      Expanded(
        child: GradientButton(
          label: _running ? 'Merging...' : 'Merge Replays',
          icon: Icons.merge_type_rounded,
          onPressed: (_files.length >= 2 && !_running) ? _runMerge : null,
          loading: _running,
        ),
      ),
    ],
  );

  static const _guideSteps = [
    (
      AppTheme.accent,
      'Drop your .hbr2 files',
      'Drag two or more replay files onto the left panel. Each is parsed via node-haxball API — room state, frames and goal markers extracted.',
    ),
    (
      AppTheme.purple,
      'Order the files',
      'File 1 plays first, File 2 continues right after — no gaps, no frame resets.',
    ),
    (
      Color(0xFF4A6CF7),
      'Pick output folder',
      'Set where to save the merged file. Defaults to your Downloads folder.',
    ),
    (
      Color(0xFFFF8C42),
      'Click Merge Replays',
      'Frame offsets recalculated, spawn order preserved, HBR2 binary written — fully compatible with haxball.com.',
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
    ],
  ).animate().fadeIn(duration: 500.ms, delay: 200.ms);

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
              color: AppTheme.accent,
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
          valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
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
        if (_success && _lastOutputPath != null)
          GestureDetector(
            onTap: () =>
                Process.run('explorer', ['/select,', _lastOutputPath!]),
            child: Text(
              'Show file',
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
