// lib/screens/replay_viewer_screen.dart
//
// Embeds haxball.com's official replay player inside the app using WebView2.
//
// Flow:
//   1. Read .hbr2 header → extract replay version (uint32 big-endian at offset 4)
//   2. Start a Dart HTTP server on a random localhost port (with CORS headers)
//   3. Load https://www.haxball.com/replay?v=VERSION#http://127.0.0.1:PORT/replay.hbr2
//      haxball.com fetches the file from our local server and renders the replay
//   4. Dispose server + WebView when the screen is popped

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

import '../theme/app_theme.dart';

class ReplayViewerScreen extends StatefulWidget {
  const ReplayViewerScreen({super.key, required this.filePath});
  final String filePath;

  @override
  State<ReplayViewerScreen> createState() => _ReplayViewerScreenState();
}

class _ReplayViewerScreenState extends State<ReplayViewerScreen> {
  final _controller = WebviewController();
  HttpServer? _fileServer;
  bool _webviewReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fileServer?.close(force: true);
    super.dispose();
  }

  // ── Initialise ───────────────────────────────────────────────────────────────
  Future<void> _init() async {
    try {
      // 1. Read the .hbr2 file
      final bytes = await File(widget.filePath).readAsBytes();

      // 2. Validate + extract version from binary header
      if (bytes.length < 12) {
        throw Exception('File is too small to be a valid .hbr2 replay');
      }
      final magic = String.fromCharCodes(bytes.sublist(0, 4));
      if (magic != 'HBR2') {
        throw Exception('Not a valid .hbr2 file (bad magic: $magic)');
      }
      final version = ByteData.sublistView(
        bytes,
        4,
        8,
      ).getUint32(0, Endian.big);

      // 3. Start local CORS HTTP server
      _fileServer = await HttpServer.bind('127.0.0.1', 0);
      final port = _fileServer!.port;
      _serveFile(bytes);

      // 4. Initialise WebView2
      await _controller.initialize();
      _controller.setBackgroundColor(Colors.black);

      // Block navigations away from haxball.com (keep content in-app)
      _controller.url.listen((url) async {
        if (url.isNotEmpty &&
            !url.startsWith('https://www.haxball.com') &&
            url != 'about:blank') {
          await _controller.goBack();
        }
      });

      // 5. Load the official haxball.com replay URL
      //    HaxBall protocol: ?v=<version>#<file_url>
      //    Our local server serves the file as HTTP with CORS → allow-running-insecure-content
      //    flag (set in main.dart) allows haxball.com (HTTPS) to fetch it.
      final replayUrl =
          'https://www.haxball.com/replay?v=$version'
          '#http://127.0.0.1:$port/replay.hbr2';
      await _controller.loadUrl(replayUrl);

      if (mounted) setState(() => _webviewReady = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  // ── Local CORS file server ───────────────────────────────────────────────────
  void _serveFile(Uint8List bytes) {
    _fileServer!.listen((HttpRequest req) async {
      req.response.headers
        ..set('Access-Control-Allow-Origin', '*')
        ..set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
        ..set('Cache-Control', 'no-store');

      if (req.method == 'OPTIONS') {
        req.response.statusCode = HttpStatus.ok;
        await req.response.close();
        return;
      }

      req.response
        ..statusCode = HttpStatus.ok
        ..headers.set('Content-Type', 'application/octet-stream')
        ..headers.set('Content-Length', bytes.length.toString())
        ..add(bytes);
      await req.response.close();
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_error != null)
            _ErrorView(
              message: _error!,
              onClose: () => Navigator.of(context).pop(),
            )
          else if (!_webviewReady)
            _LoadingView(fileName: p.basename(widget.filePath))
          else
            Webview(
              _controller,
              permissionRequested: (url, permissionKind, isUserInitiated) =>
                  WebviewPermissionDecision.deny,
            ),

          // Floating close button (always on top)
          Positioned(
            top: 10,
            right: 10,
            child: _CloseButton(onPressed: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _hovered
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _hovered ? Colors.white54 : Colors.white24),
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
      ),
    ),
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.fileName});
  final String fileName;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(
            color: AppTheme.purple,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Loading replay…',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          fileName,
          style: GoogleFonts.robotoMono(
            fontSize: 11,
            color: Colors.white38,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 380,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
          const SizedBox(height: 16),
          Text(
            'Could not open viewer',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white54,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
}
