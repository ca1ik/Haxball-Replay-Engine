// lib/screens/replay_viewer_screen.dart
//
// Embeds haxball.com's official replay player inside the app using WebView2.
//
// Bottom panel features:
//   • Interactive timeline scrubber with IN/OUT clip markers + seek
//   • Clip Creator  — ⬥ IN / ⬥ OUT / name / 📋 Copy
//   • Split shortcut — copies frame info for HBR Studio › Split
//   • Draggable 🤖 HBR Assistant chatbot

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:webview_windows/webview_windows.dart';

import '../theme/app_theme.dart';

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

class _Msg {
  final String text;
  final bool isUser;
  _Msg(this.text, this.isUser);
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
  int _inSec = -1;
  int _outSec = -1;
  bool _expanded = true;
  final _nameCtrl = TextEditingController();

  // chatbot
  bool _chatOpen = false;
  Offset _chatPos = Offset.zero;
  bool _chatInited = false;
  final _chatIn = TextEditingController();
  final _chatScroll = ScrollController();
  final List<_Msg> _msgs = [
    _Msg(
      'Hi! I\'m your HBR Assistant.\n'
      'Try: help · stats · clip from 1:00 to 2:30\n'
      'how to clip · seek 3:15 · clear',
      false,
    ),
  ];

  // toast
  String? _toast;
  bool _toastErr = false;
  Timer? _toastTm;

  // computed
  String get _cs => _fmtSec(_curSec);
  String get _ds => _durSec > 0 ? _fmtSec(_durSec) : '--:--';
  double get _frac => _durSec > 0 ? (_curSec / _durSec).clamp(0.0, 1.0) : 0.0;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _chatIn.dispose();
    _chatScroll.dispose();
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
      if (magic != 'HBR2') throw Exception('Bad magic: $magic');
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

  // ── clip actions ──────────────────────────────────────────────────────────

  void _setIn() => setState(() => _inSec = _curSec);
  void _setOut() => setState(() => _outSec = _curSec);

  void _copy() {
    if (_inSec < 0 || _outSec <= _inSec) {
      _toast_('Set a valid IN before OUT', err: true);
      return;
    }
    final name = _nameCtrl.text.trim().isEmpty ? 'clip' : _nameCtrl.text.trim();
    Clipboard.setData(
      ClipboardData(
        text:
            'HBR Clip: $name\n'
            'IN:  ${_fmtSec(_inSec)}  (frame ~${_inSec * 60})\n'
            'OUT: ${_fmtSec(_outSec)}  (frame ~${_outSec * 60})\n'
            'Dur: ${_fmtSec(_outSec - _inSec)}\n'
            '→ Open HBR Studio › Split to extract.',
      ),
    );
    _toast_('Copied! Open HBR Studio › Split to trim.');
  }

  void _split() {
    if (_inSec < 0) {
      _toast_('Set IN point first', err: true);
      return;
    }
    Clipboard.setData(
      ClipboardData(
        text:
            'Split at: ${_fmtSec(_inSec)} (frame ~${_inSec * 60})\n'
            'File: ${widget.filePath}',
      ),
    );
    _toast_('Copied! Open HBR Studio › Split tab to trim at this point.');
  }

  // ── toast ─────────────────────────────────────────────────────────────────

  void _toast_(String msg, {bool err = false}) {
    _toastTm?.cancel();
    setState(() {
      _toast = msg;
      _toastErr = err;
    });
    _toastTm = Timer(const Duration(milliseconds: 3400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  // ── chatbot ───────────────────────────────────────────────────────────────

  void _add(String t, {bool user = false}) {
    setState(() => _msgs.add(_Msg(t, user)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _reply(String q) {
    final lq = q.toLowerCase().trim();
    if (lq == 'help') {
      return 'Commands:\n'
          '· stats — time & clip markers\n'
          '· clip from M:SS to M:SS — set markers\n'
          '· current time\n'
          '· how to clip\n'
          '· seek M:SS — jump to time\n'
          '· clear — reset IN/OUT';
    }
    if (lq == 'stats') {
      return 'Time: $_cs / $_ds\n'
          'IN:  ${_inSec >= 0 ? _fmtSec(_inSec) : "not set"}\n'
          'OUT: ${_outSec >= 0 ? _fmtSec(_outSec) : "not set"}';
    }
    if (lq == 'current time') return 'Current time: $_cs';
    if (lq == 'clear') {
      setState(() {
        _inSec = _outSec = -1;
      });
      return 'Clip markers cleared.';
    }
    if (lq == 'how to clip') {
      return '1. Play to clip start\n'
          '2. Tap ⬥ IN in the bottom bar\n'
          '3. Play to clip end\n'
          '4. Tap ⬥ OUT\n'
          '5. Name it → 📋 Copy\n'
          '6. Open HBR Studio › Split to trim';
    }
    final cm = RegExp(r'clip from (\d+:\d+)\s+to\s+(\d+:\d+)').firstMatch(lq);
    if (cm != null) {
      setState(() {
        _inSec = _parseSec(cm.group(1)!);
        _outSec = _parseSec(cm.group(2)!);
      });
      return 'Clip set: ${cm.group(1)} → ${cm.group(2)}\nTap 📋 Copy.';
    }
    final sm = RegExp(r'seek (\d+:\d+)').firstMatch(lq);
    if (sm != null) {
      _seekTo(_parseSec(sm.group(1)!));
      return 'Seeking to ${sm.group(1)}…';
    }
    return 'I can help with clip timing and replay controls.\nType "help" for all commands.';
  }

  void _send() {
    final v = _chatIn.text.trim();
    if (v.isEmpty) return;
    _add(v, user: true);
    _chatIn.clear();
    final r = _reply(v);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) _add(r);
    });
  }

  // ── file server ───────────────────────────────────────────────────────────

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

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    if (!_chatInited) {
      _chatPos = Offset(16, sz.height - (_expanded ? 88 : 32) - 54);
      _chatInited = true;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView column (leaves room for panel at bottom)
          Column(
            children: [
              Expanded(child: _buildMain()),
              if (_ready) _buildPanel(),
            ],
          ),

          // Close button (top-right, over WebView area)
          Positioned(
            top: 10,
            right: 10,
            child: _CloseBtn(onTap: () => Navigator.pop(context)),
          ),

          // Chatbot panel (floats above the toggle)
          if (_ready && _chatOpen)
            Positioned(
              left: _chatPos.dx.clamp(0, sz.width - 292),
              top: (_chatPos.dy - 332 - 8).clamp(0, sz.height - 332),
              child: _buildChatPanel(),
            ),

          // Chatbot toggle (draggable)
          if (_ready)
            Positioned(
              left: _chatPos.dx.clamp(0, sz.width - 38),
              top: _chatPos.dy.clamp(0, sz.height - 38),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => setState(() {
                  _chatPos = Offset(
                    (_chatPos.dx + d.delta.dx).clamp(0, sz.width - 38),
                    (_chatPos.dy + d.delta.dy).clamp(0, sz.height - 38),
                  );
                }),
                onTap: () => setState(() => _chatOpen = !_chatOpen),
                child: _ChatToggle(open: _chatOpen),
              ),
            ),

          // Toast
          if (_toast != null)
            Positioned(
              bottom: _expanded ? 100.0 : 44.0,
              left: 0,
              right: 0,
              child: _ToastBar(msg: _toast!, err: _toastErr),
            ),
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

  Widget _buildPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _expanded ? 88.0 : 32.0,
      decoration: const BoxDecoration(
        color: Color(0xF2080A14),
        border: Border(top: BorderSide(color: Color(0x4D7B5EA7))),
      ),
      child: Column(
        children: [_buildTimeline(), if (_expanded) _buildClipRow()],
      ),
    );
  }

  // timeline row (always visible even when collapsed)
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
              inFrac: _inSec >= 0 && _durSec > 0
                  ? (_inSec / _durSec).clamp(0.0, 1.0)
                  : null,
              outFrac: _outSec >= 0 && _durSec > 0
                  ? (_outSec / _durSec).clamp(0.0, 1.0)
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
          const SizedBox(width: 6),
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

  // clip creator row (shown when expanded)
  Widget _buildClipRow() => Expanded(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          _Btn(label: '⬥ IN', color: AppTheme.purple, onTap: _setIn),
          const SizedBox(width: 4),
          _TLabel(
            text: _inSec >= 0 ? _fmtSec(_inSec) : '--:--',
            color: AppTheme.purple,
          ),
          const SizedBox(width: 10),
          _Btn(label: '⬥ OUT', color: AppTheme.accent, onTap: _setOut),
          const SizedBox(width: 4),
          _TLabel(
            text: _outSec >= 0 ? _fmtSec(_outSec) : '--:--',
            color: AppTheme.accent,
          ),
          const SizedBox(width: 10),
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
                  hintText: 'clip name…',
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
          const SizedBox(width: 6),
          _Btn(label: '📋 Copy', color: AppTheme.accent, onTap: _copy),
          const SizedBox(width: 6),
          Container(width: 1, height: 20, color: const Color(0x1AFFFFFF)),
          const SizedBox(width: 6),
          _Btn(
            label: '✂ Split at IN',
            color: const Color(0xFF4A6CF7),
            onTap: _split,
          ),
        ],
      ),
    ),
  );

  // ── chat panel ────────────────────────────────────────────────────────────

  Widget _buildChatPanel() => Container(
    width: 284,
    height: 326,
    decoration: BoxDecoration(
      color: const Color(0xF4080A14),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0x667B5EA7)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        // header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: Row(
            children: [
              const Text(
                '🤖',
                style: TextStyle(fontSize: 14, decoration: TextDecoration.none),
              ),
              const SizedBox(width: 8),
              Text(
                'HBR Assistant',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC8B4FF),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
        // messages
        Expanded(
          child: ListView.builder(
            controller: _chatScroll,
            padding: const EdgeInsets.all(10),
            itemCount: _msgs.length,
            itemBuilder: (_, i) => _Bubble(msg: _msgs[i]),
          ),
        ),
        // input
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: TextField(
                    controller: _chatIn,
                    onSubmitted: (_) => _send(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFB0BCD8),
                      decoration: TextDecoration.none,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Ask anything…',
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
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: AppTheme.purple.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0x4D7B5EA7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x807B5EA7)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.send_rounded,
                      size: 14,
                      color: Color(0xFFC8B4FF),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

    // track
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - 2, W, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x26FFFFFF),
    );
    // clip region
    if (inFrac != null && outFrac != null && outFrac! > inFrac!) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(W * inFrac!, cy - 2, W * (outFrac! - inFrac!), 4),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0x5500C9A7),
      );
    }
    // played (gradient)
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
    // playhead
    canvas.drawCircle(
      Offset(pX.clamp(4.0, W - 4.0), cy),
      5,
      Paint()..color = Colors.white,
    );
    // IN marker
    if (inFrac != null)
      _marker(canvas, W * inFrac!, cy, const Color(0xFF9D7FD4));
    // OUT marker
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

// ── Small reusable widgets ────────────────────────────────────────────────────

class _TLabel extends StatelessWidget {
  const _TLabel({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    child: Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
        decoration: TextDecoration.none,
        fontFeatures: const [FontFeature.tabularFigures()],
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

class _ChatToggle extends StatelessWidget {
  const _ChatToggle({required this.open});
  final bool open;
  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF7B5EA7), Color(0xFF4A6CF7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF7B5EA7).withOpacity(0.45),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Center(
      child: Text(
        open ? '✕' : '🤖',
        style: const TextStyle(fontSize: 16, decoration: TextDecoration.none),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final _Msg msg;
  @override
  Widget build(BuildContext context) => Align(
    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 220),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: msg.isUser ? const Color(0x2E4A6CF7) : const Color(0x287B5EA7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        msg.text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: msg.isUser ? const Color(0xFFA0B0E0) : const Color(0xFFB8C8E0),
          height: 1.45,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}

class _ToastBar extends StatelessWidget {
  const _ToastBar({required this.msg, required this.err});
  final String msg;
  final bool err;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 360),
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

// ── Close / Loading / Error (unchanged API) ───────────────────────────────────

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
