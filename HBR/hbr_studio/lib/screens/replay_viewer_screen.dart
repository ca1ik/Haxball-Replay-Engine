// lib/screens/replay_viewer_screen.dart
//
// Full-screen WebView2 replay player with:
//   • Interactive timeline scrubber with IN/OUT clip markers
//   • Clip Creator — set IN, then OUT → auto-saves clip via NodeService.trim()
//   • Clip save path from SettingsProvider (default: Downloads)
//   • Close in-player menu/overlay button
//   • Global AI Chat overlay (AiChatWidget) — FAB above bottom panel

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:webview_windows/webview_windows.dart';

import '../providers/settings_provider.dart';
import '../services/node_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_chat_widget.dart';

// ── helpers ───────────────────────────────────────────────────────────────────
String _fmtSec(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

int _parseSec(String t) {
  final parts = t.split(':').map(int.tryParse).toList();
  if (parts.length == 2 && parts[0] != null && parts[1] != null) {
    return parts[0]! * 60 + parts[1]!;
  }
  return 0;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class ReplayViewerScreen extends StatefulWidget {
  const ReplayViewerScreen({super.key, required this.filePath});
  final String filePath;

  @override
  State<ReplayViewerScreen> createState() => _ReplayViewerScreenState();
}

class _ReplayViewerScreenState extends State<ReplayViewerScreen> {
  final _controller = WebviewController();
  HttpServer? _srv;
  bool _ready = false;
  String? _error;

  // timeline / clip
  int _curSec = 0;
  int _durSec = 0;
  bool _expanded = true;
  bool _saving = false;
  final _nameCtrl = TextEditingController();
  final _startCtrl = TextEditingController(text: '0:00');
  final _endCtrl = TextEditingController(text: '0:00');

  // toast
  String? _toast;
  bool _toastErr = false;
  Timer? _toastTm;

  // computed
  String get _cs => _fmtSec(_curSec);
  String get _ds => _durSec > 0 ? _fmtSec(_durSec) : '--:--';
  double get _frac => _durSec > 0 ? (_curSec / _durSec).clamp(0.0, 1.0) : 0.0;
  bool get _canSave {
    final s = _parseSec(_startCtrl.text);
    final e = _parseSec(_endCtrl.text);
    return e > s && _durSec > 0;
  }

  // Panel height for AI FAB offset
  static const double _panelH = 88.0;

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _toastTm?.cancel();
    _controller.dispose();
    _srv?.close(force: true);
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final bytes = await File(widget.filePath).readAsBytes();
      if (bytes.length < 12) throw Exception('File too small for .hbr2');
      final magic = String.fromCharCodes(bytes.sublist(0, 4));
      if (magic != 'HBR2') throw Exception('Invalid file format: $magic');
      final version = ByteData.sublistView(
        bytes,
        4,
        8,
      ).getUint32(0, Endian.big);

      _srv = await HttpServer.bind('127.0.0.1', 0);
      _serveFile(bytes);

      await _controller.initialize();
      _controller.setBackgroundColor(Colors.black);
      _controller.webMessage.listen(_onMsg);
      _controller.loadingState.listen((s) {
        if (s == LoadingState.navigationCompleted) _injectBridge();
      });
      _controller.url.listen((url) async {
        if (url.isNotEmpty &&
            !url.startsWith('https://www.haxball.com') &&
            url != 'about:blank') {
          await _controller.goBack();
        }
      });

      final replayUrl =
          'https://www.haxball.com/replay?v=$version'
          '#http://127.0.0.1:${_srv!.port}/replay.hbr2';
      await _controller.loadUrl(replayUrl);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  // ── JS bridge ─────────────────────────────────────────────────────────────
  Future<void> _injectBridge() async {
    const js = r'''
(function(){
  if(window.__hbrB)return; window.__hbrB=true;
  try{var _s=document.createElement('style');_s.textContent='body>header,body>nav,.navbar,.nav-bar,nav:first-of-type,[class*="header"]:not(canvas):not(div>canvas~*){display:none!important}body{overflow:hidden!important;margin:0!important;background:#000!important}';(document.head||document.documentElement).appendChild(_s);}catch(_x){}
  var _lt='';
  setInterval(function(){
    try{
      var ns=document.querySelectorAll('span,div,p,td');
      for(var i=0;i<ns.length;i++){
        var e=ns[i];
        if(e.children.length!==0)continue;
        var t=e.textContent.trim();
        if(/^\d{1,2}:\d{2}$/.test(t)&&t!==_lt){
          _lt=t;
          window.chrome.webview.postMessage(JSON.stringify({type:'time',value:t}));
        }
      }
      var r=document.querySelector('input[type="range"]');
      if(r&&r.max){
        var d=parseInt(r.max);
        if(d>0) window.chrome.webview.postMessage(JSON.stringify({type:'dur',value:d}));
      }
    }catch(_){}
  },400);
  window.__hbrSeek=function(s){
    try{
      var r=document.querySelector('input[type="range"]');
      if(!r)return;
      var set=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;
      set.call(r,String(s));
      r.dispatchEvent(new Event('input',{bubbles:true}));
      r.dispatchEvent(new Event('change',{bubbles:true}));
    }catch(_){}
  };
})();
''';
    try {
      await _controller.executeScript(js);
    } catch (_) {}
  }

  void _onMsg(dynamic m) {
    try {
      if (m is! String) return;
      final d = jsonDecode(m) as Map<String, dynamic>;
      if (!mounted) return;
      switch (d['type'] as String? ?? '') {
        case 'time':
          setState(() => _curSec = _parseSec(d['value'] as String));
        case 'dur':
          final v = (d['value'] as num).toInt();
          if (v > 0) setState(() => _durSec = v);
      }
    } catch (_) {}
  }

  Future<void> _seekTo(int sec) async {
    try {
      await _controller.executeScript(
        'if(window.__hbrSeek)window.__hbrSeek($sec);',
      );
      if (mounted) setState(() => _curSec = sec);
    } catch (_) {}
  }

  // ── Close in-player haxball menu ──────────────────────────────────────────
  Future<void> _closeMenu() async {
    try {
      await _controller.executeScript(r'''
(function(){
  var esc={key:'Escape',keyCode:27,which:27,bubbles:true,cancelable:true};
  var canvas=document.querySelector('canvas');
  ['keydown','keyup'].forEach(function(t){
    document.dispatchEvent(new KeyboardEvent(t,esc));
    if(canvas)canvas.dispatchEvent(new KeyboardEvent(t,esc));
  });
  document.querySelectorAll('button,a,[role="button"]').forEach(function(el){
    var t=(el.textContent||'').trim().toLowerCase();
    if(['resume','close','ok','back','dismiss','cancel','devam','kapat'].indexOf(t)>=0)el.click();
  });
  if(canvas){
    canvas.focus();
    var r=canvas.getBoundingClientRect();
    canvas.dispatchEvent(new MouseEvent('click',{clientX:r.left+r.width/2,clientY:r.top+r.height/2,bubbles:true}));
  }
})();
''');
    } catch (_) {}
  }

  // ── Clip actions ──────────────────────────────────────────────────────────
  Future<void> _saveClip() async {
    if (_saving) return;
    final startSec = _parseSec(_startCtrl.text);
    final endSec = _parseSec(_endCtrl.text);
    if (endSec <= startSec) return;

    final settings = context.read<SettingsProvider>();
    final savePath = settings.clipSavePath;
    final raw = _nameCtrl.text.trim();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final name = raw.isEmpty
        ? 'clip_$ts'
        : raw.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final outputPath = p.join(savePath, '$name.hbr2');

    // Ensure save directory exists
    try {
      final dir = Directory(savePath);
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (_) {}

    setState(() => _saving = true);
    _showToast('Saving clip…');

    try {
      bool hasError = false;
      String? errMsg;
      await for (final evt in NodeService.trim(
        inputPath: widget.filePath,
        outputPath: outputPath,
        startFrame: startSec * 60,
        endFrame: endSec * 60,
      )) {
        if (evt['type'] == 'error') {
          hasError = true;
          errMsg = evt['message'] as String?;
        }
      }
      if (hasError) {
        _showToast('Save failed: $errMsg', err: true);
      } else {
        _showToast('Saved: $name.hbr2  →  ${p.basename(savePath)}');
      }
    } catch (e) {
      _showToast('Save failed: $e', err: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Toast ─────────────────────────────────────────────────────────────────
  void _showToast(String msg, {bool err = false}) {
    _toastTm?.cancel();
    setState(() {
      _toast = msg;
      _toastErr = err;
    });
    _toastTm = Timer(const Duration(milliseconds: 3800), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ── File server ───────────────────────────────────────────────────────────
  void _serveFile(Uint8List bytes) {
    _srv!.listen((HttpRequest req) async {
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final panelBottom = (_expanded ? _panelH : 34.0) + 20.0 + 52.0 + 16.0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView + bottom panel (Column so WebView respects panel height)
          Column(
            children: [
              Expanded(child: _buildMain()),
              if (_ready) _buildPanel(),
            ],
          ),
          // Close button (top-right)
          Positioned(
            top: 10,
            right: 10,
            child: _CloseBtn(onTap: () => Navigator.pop(context)),
          ),
          // Toast notification
          if (_toast != null)
            Positioned(
              bottom: (_expanded ? _panelH : 32.0) + 10,
              left: 0,
              right: 0,
              child: _Toast(msg: _toast!, err: _toastErr),
            ),
          // Global AI Chat — FAB above bottom panel
          Positioned.fill(child: AiChatWidget(bottomOffset: panelBottom)),
        ],
      ),
    );
  }

  Widget _buildMain() {
    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onClose: () => Navigator.pop(context),
      );
    }
    if (!_ready) {
      return _LoadingView(fileName: p.basename(widget.filePath));
    }
    return Webview(
      _controller,
      permissionRequested: (_, __, ___) => WebviewPermissionDecision.deny,
    );
  }

  // ── bottom panel ─────────────────────────────────────────────────────────
  Widget _buildPanel() => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    height: _expanded ? _panelH : 34.0,
    decoration: const BoxDecoration(
      color: Color(0xF2080A14),
      border: Border(top: BorderSide(color: Color(0x4D7B5EA7))),
    ),
    child: Column(children: [_buildTimeline(), if (_expanded) _buildClipRow()]),
  );

  // timeline row
  Widget _buildTimeline() => SizedBox(
    height: 32,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              _cs,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
                decoration: TextDecoration.none,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _TimelineBar(
              frac: _frac,
              inFrac: _durSec > 0 && _parseSec(_startCtrl.text) > 0
                  ? (_parseSec(_startCtrl.text) / _durSec).clamp(0.0, 1.0)
                  : null,
              outFrac: _durSec > 0 && _parseSec(_endCtrl.text) > 0
                  ? (_parseSec(_endCtrl.text) / _durSec).clamp(0.0, 1.0)
                  : null,
              onSeek: (f) {
                if (_durSec > 0) _seekTo((_durSec * f).round());
              },
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 38,
            child: Text(
              _ds,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white24,
                decoration: TextDecoration.none,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Close in-player menu
          _TinyBtn(label: '✕ Menu', onTap: _closeMenu),
          const SizedBox(width: 4),
          // Expand/collapse toggle
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Icon(
              _expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              size: 18,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    ),
  );

  // clip creator row
  Widget _buildClipRow() => Expanded(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          // Start time
          _Btn(
            label: '⬥ Başlangıç',
            color: AppTheme.purple,
            onTap: () => setState(() => _startCtrl.text = _cs),
          ),
          const SizedBox(width: 4),
          _TimeField(
            controller: _startCtrl,
            color: AppTheme.purple,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(width: 10),
          // End time
          _Btn(
            label: '⬥ Bitiş',
            color: AppTheme.accent,
            onTap: () => setState(() => _endCtrl.text = _cs),
          ),
          const SizedBox(width: 4),
          _TimeField(
            controller: _endCtrl,
            color: AppTheme.accent,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(width: 10),
          // Clip name
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: _nameCtrl,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFFB0BCD8),
                  decoration: TextDecoration.none,
                ),
                decoration: InputDecoration(
                  hintText: 'clip adı…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF374060),
                    decoration: TextDecoration.none,
                  ),
                  filled: true,
                  fillColor: const Color(0x14FFFFFF),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: AppTheme.purple.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Kırp button
          if (!_saving)
            Opacity(
              opacity: _canSave ? 1.0 : 0.38,
              child: _Btn(
                label: '✂ Kırp',
                color: AppTheme.accent,
                onTap: _saveClip,
              ),
            ),
          if (_saving)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Kaydediliyor…',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.accent,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

// ── Timeline Bar ──────────────────────────────────────────────────────────────
class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.frac,
    required this.onSeek,
    this.inFrac,
    this.outFrac,
  });
  final double frac;
  final double? inFrac;
  final double? outFrac;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (d) => _emit(d.localPosition.dx, context),
    onHorizontalDragUpdate: (d) => _emit(d.localPosition.dx, context),
    child: Container(
      height: 20,
      alignment: Alignment.center,
      child: CustomPaint(
        painter: _TLPainter(frac: frac, inFrac: inFrac, outFrac: outFrac),
        size: const Size(double.infinity, 6),
      ),
    ),
  );

  void _emit(double dx, BuildContext ctx) {
    final w = ctx.size?.width;
    if (w == null || w == 0) return;
    onSeek((dx / w).clamp(0.0, 1.0));
  }
}

class _TLPainter extends CustomPainter {
  const _TLPainter({required this.frac, this.inFrac, this.outFrac});
  final double frac;
  final double? inFrac;
  final double? outFrac;

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final cy = size.height / 2;

    // Track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - 2, W, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x26FFFFFF),
    );

    // Clip region
    if (inFrac != null && outFrac != null && outFrac! > inFrac!) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(W * inFrac!, cy - 2, W * (outFrac! - inFrac!), 4),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0x5500C9A7),
      );
    }

    // Progress
    final pX = (W * frac).clamp(0.0, W);
    if (pX > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, cy - 2, pX, 4),
          const Radius.circular(2),
        ),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF7B5EA7), Color(0xFF4A6CF7)],
          ).createShader(Rect.fromLTWH(0, 0, W, 4)),
      );
    }

    // Playhead
    canvas.drawCircle(
      Offset(pX.clamp(4.0, W - 4.0), cy),
      5,
      Paint()..color = Colors.white,
    );

    // Markers
    if (inFrac != null)
      _marker(canvas, W * inFrac!, cy, const Color(0xFF9D7FD4));
    if (outFrac != null)
      _marker(canvas, W * outFrac!, cy, const Color(0xFF00C9A7));
  }

  void _marker(Canvas canvas, double x, double cy, Color c) => canvas.drawPath(
    Path()
      ..moveTo(x, cy - 8)
      ..lineTo(x + 5, cy - 3)
      ..lineTo(x - 5, cy - 3)
      ..close(),
    Paint()..color = c,
  );

  @override
  bool shouldRepaint(_TLPainter o) =>
      o.frac != frac || o.inFrac != inFrac || o.outFrac != outFrac;
}

// ── Small widgets ─────────────────────────────────────────────────────────────
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.controller,
    required this.color,
    this.onChanged,
  });
  final TextEditingController controller;
  final Color color;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 28,
    child: TextField(
      controller: controller,
      onChanged: onChanged != null ? (_) => onChanged!() : null,
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        decoration: TextDecoration.none,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: color.withOpacity(0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: color.withOpacity(0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: color.withOpacity(0.65)),
        ),
      ),
    ),
  );
}

class _Btn extends StatefulWidget {
  const _Btn({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_h ? 0.2 : 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: widget.color.withOpacity(_h ? 0.5 : 0.25)),
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.color,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    ),
  );
}

class _TinyBtn extends StatefulWidget {
  const _TinyBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_TinyBtn> createState() => _TinyBtnState();
}

class _TinyBtnState extends State<_TinyBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _h ? Colors.white.withOpacity(0.08) : const Color(0x0AFFFFFF),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0x14FFFFFF)),
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 9,
            color: _h ? Colors.white54 : Colors.white30,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    ),
  );
}

class _Toast extends StatelessWidget {
  const _Toast({required this.msg, required this.err});
  final String msg;
  final bool err;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: err ? const Color(0x26FF4D6A) : const Color(0x2200C9A7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: err ? const Color(0x66FF4D6A) : const Color(0x6600C9A7),
        ),
      ),
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: err ? const Color(0xFFFF4D6A) : const Color(0xFF00C9A7),
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}

class _CloseBtn extends StatefulWidget {
  const _CloseBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_CloseBtn> createState() => _CloseBtnState();
}

class _CloseBtnState extends State<_CloseBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _h
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _h ? Colors.white54 : Colors.white24),
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
        color: const Color(0xFF1A1A2E),
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
