// lib/widgets/ai_chat_widget.dart
// Floating AI assistant button (bottom-right) + slide-up panel
// - LED purple/blue animated border ring
// - Bilingual: auto-detects Turkish, defaults English
// - Chat history with copy per message, global clear
// - Replay-aware: uses ReplayProvider for context

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_l10n.dart';
import '../models/chat_message.dart';
import '../models/match_stats.dart';
import '../providers/replay_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class AiChatWidget extends StatefulWidget {
  const AiChatWidget({super.key});
  @override
  State<AiChatWidget> createState() => _AiChatWidgetState();
}

class _AiChatWidgetState extends State<AiChatWidget>
    with TickerProviderStateMixin {
  bool _open = false;
  final List<ChatMessage> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _typing = false;

  // LED ring animation
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _addGreeting());
  }

  void _addGreeting() {
    final lang = context.read<SettingsProvider>().lang;
    final l10n = AppL10n.of(lang);
    setState(
      () => _messages.add(
        ChatMessage(
          role: MessageRole.assistant,
          content: l10n.t('ai.greeting'),
          timestamp: DateTime.now(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ring.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Language detection ────────────────────────────────────────────────────────
  bool _isTurkish(String text) {
    final tr = RegExp(r'[şğüöçıŞĞÜÖÇİ]');
    final trWords = RegExp(
      r'\b(merhaba|selam|nasıl|nereye|bölme|birleştir|stats|istatistik|yükle|yardım|ne|bu|bir|var|ile|için|çok|daha|yapabilir|göster)\b',
      caseSensitive: false,
    );
    return tr.hasMatch(text) || trWords.hasMatch(text);
  }

  // ── AI response engine ────────────────────────────────────────────────────────
  Future<String> _getResponse(String userMsg, String lang) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final stats = context.read<ReplayProvider>().stats;
    final effectiveLang = _isTurkish(userMsg) ? 'tr' : lang;
    final isTr = effectiveLang == 'tr';

    final lower = userMsg.toLowerCase();

    // ── Greeting
    if (RegExp(r'\b(hi|hello|hey|merhaba|selam|yo)\b').hasMatch(lower)) {
      return isTr
          ? 'Merhaba! 👋 HaxReplay Assistant olarak sana yardımcı olmaya hazırım.\n\n'
                '• Replay yükle → maç istatistiklerini göstereyim\n'
                '• "X dakikada böl" → split işlemi yap\n'
                '• "Birleştir" → merge rehberi\n\n'
                'Ne yapmak istersin?'
          : 'Hey! 👋 I\'m HaxReplay Assistant.\n\n'
                '• Load a replay → I\'ll show match stats\n'
                '• "Split at 7:30" → I\'ll guide the split\n'
                '• "Merge files" → step-by-step merge guide\n\n'
                'What can I help with?';
    }

    // ── Stats request
    if (RegExp(
      r'\b(stats|istatistik|skor|score|gol|goal|result|sonuç)\b',
    ).hasMatch(lower)) {
      if (stats == null) {
        return isTr
            ? '⚠️ Henüz bir replay yüklenmedi. Lütfen önce **Analiz** ekranından bir .hbr2 dosyası yükle.'
            : '⚠️ No replay loaded yet. Please load a .hbr2 file from the **Analyze** screen first.';
      }
      return _formatStats(stats, isTr);
    }

    // ── Goals only
    if (RegExp(r'\b(goal|gol|kim attı|who scored|scorer)\b').hasMatch(lower)) {
      if (stats == null) {
        return isTr ? '⚠️ Önce bir replay yükle.' : '⚠️ Load a replay first.';
      }
      return _formatGoals(stats, isTr);
    }

    // ── Split guide
    if (RegExp(r'\b(split|böl|ayır|cut|kes)\b').hasMatch(lower)) {
      // Try to extract time
      final timeMatch = RegExp(r'(\d+):(\d+)').firstMatch(userMsg);
      if (timeMatch != null) {
        final m = timeMatch.group(1)!;
        final s = timeMatch.group(2)!;
        return isTr
            ? '✂️ **$m:$s anında bölme rehberi:**\n\n'
                  '1. Sol menüden **Böl** ekranını aç\n'
                  '2. .hbr2 dosyasını sürükle-bırak veya tıklayarak yükle\n'
                  '3. Dakika kutusuna **$m**, saniye kutusuna **$s** gir\n'
                  '4. (Veya zaman çizelgesinde imleci sürükle)\n'
                  '5. **Böl** butonuna bas\n\n'
                  '✅ İki ayrı .hbr2 dosyası oluşturulacak!'
            : '✂️ **How to split at $m:$s:**\n\n'
                  '1. Go to the **Split** screen in the left menu\n'
                  '2. Drop your .hbr2 file into the drop zone\n'
                  '3. Enter **$m** for minutes, **$s** for seconds\n'
                  '4. (Or drag the timeline cursor)\n'
                  '5. Click **Split Replay**\n\n'
                  '✅ Two independent .hbr2 files will be created!';
      }
      return isTr
          ? '✂️ Replay\'i bölmek için **Böl** ekranına git ve zamanı gir.\n'
                'Örnek: "7:30\'da böl" veya "9 dakika 15 saniyede ayır"'
          : '✂️ Go to the **Split** screen to cut a replay at a specific time.\n'
                'Example: "split at 7:30" or "cut at 9 minutes 15 seconds"';
    }

    // ── Merge guide
    if (RegExp(r'\b(merge|birleştir|combine|ekle)\b').hasMatch(lower)) {
      return isTr
          ? '🔗 **Replay birleştirme rehberi:**\n\n'
                '1. **Birleştir** ekranını aç (sol menü)\n'
                '2. .hbr2 dosyalarını sürükleyerek ekle (2 veya daha fazla)\n'
                '3. Sıralamayı istediğin gibi ayarla (sürükle-bırak)\n'
                '4. Çıktı yolunu seç (opsiyonel)\n'
                '5. **Birleştir** butonuna bas\n\n'
                '⚡ Fizik motoru tam uyum sağlar, spawn sırası korunur!'
          : '🔗 **How to merge replays:**\n\n'
                '1. Open the **Merge** screen (left menu)\n'
                '2. Drop 2+ .hbr2 files into the zone\n'
                '3. Reorder them if needed (drag handles)\n'
                '4. Pick an output path (optional)\n'
                '5. Click **Merge Replays**\n\n'
                '⚡ Physics engine maintains full accuracy with correct spawn ordering!';
    }

    // ── Help
    if (RegExp(
      r'\b(help|yardım|ne yapabilir|what can|nasıl)\b',
    ).hasMatch(lower)) {
      return isTr
          ? '🤖 **HaxReplay Assistant yapabilecekleri:**\n\n'
                '• 📊 Maç istatistiklerini gösterme (goller, asistler, hakimiyet)\n'
                '• ✂️ Replay bölme rehberi (MM:SS)\n'
                '• 🔗 Replay birleştirme rehberi\n'
                '• 🎯 HaxBall hilelerini öğretme\n'
                '• 🌐 Türkçe & İngilizce konuşma\n\n'
                'Bir replay yükledikten sonra daha detaylı analiz yapabilirim!'
          : '🤖 **HaxReplay Assistant capabilities:**\n\n'
                '• 📊 Show match stats (goals, assists, possession)\n'
                '• ✂️ Guide you through replay splitting (MM:SS)\n'
                '• 🔗 Guide you through merging replays\n'
                '• 🎯 Teach HaxBall tricks\n'
                '• 🌐 Speak Turkish & English\n\n'
                'Load a replay file for deeper analysis!';
    }

    // ── HaxBall tricks
    if (RegExp(r'\b(trick|teknik|hile|tüyo|tip|ipucu)\b').hasMatch(lower)) {
      return isTr
          ? '🎯 **HaxBall İpuçları:**\n\n'
                '**Temel Teknikler**\n'
                '• **Gol vuruşu** – Topu köşeye yönlendir, kaleci kıpırdayamazken vur\n'
                '• **Duvar şutu** – Topu duvara çarpıp açı değiştir\n'
                '• **Serbest vuruş** – Kaleci çıktığında direkt şut çek\n\n'
                '**İleri Teknikler**\n'
                '• **Double kick** – İki oyuncu aynı anda vurarak hız katlar\n'
                '• **Power shot** – Tam hızda iterek maksimum güç\n'
                '• **Curve shot** – Topa açılı çararak eğri yörünge\n\n'
                '📹 Replay\'inden istatistik çekerek hangi tekniği ne kadar kullandığını görebiliriz!'
          : '🎯 **HaxBall Tricks & Tips:**\n\n'
                '**Basic Techniques**\n'
                '• **Corner shot** – Direct ball toward corner while keeper is frozen\n'
                '• **Wall bounce** – Redirect off the wall for unexpected angles\n'
                '• **Free kick** – Quick direct shot when keeper is out of position\n\n'
                '**Advanced**\n'
                '• **Double kick** – Two players hit simultaneously to multiply speed\n'
                '• **Power push** – Max speed approach for strongest shot\n'
                '• **Curve shot** – Angled contact for curved trajectory\n\n'
                '📹 Load a replay to see your kick count and score stats!';
    }

    // ── Loaded file info
    if (stats != null &&
        RegExp(r'\b(dosya|file|yüklü|loaded|current|şu)\b').hasMatch(lower)) {
      return isTr
          ? '📁 Yüklü dosya: **${stats.fileName}**\n'
                '⏱ Süre: ${stats.duration}\n'
                '⚽ Goller: ${stats.goalCount}\n'
                '🔴 Kırmızı: ${stats.redTeam.score} · 🔵 Mavi: ${stats.blueTeam.score}'
          : '📁 Loaded: **${stats.fileName}**\n'
                '⏱ Duration: ${stats.duration}\n'
                '⚽ Goals: ${stats.goalCount}\n'
                '🔴 Red: ${stats.redTeam.score} · 🔵 Blue: ${stats.blueTeam.score}';
    }

    // ── Default
    return isTr
        ? '🤔 Tam olarak anlayamadım. Şunları deneyebilirsin:\n\n'
              '• "Maç istatistiklerini göster"\n'
              '• "7:30\'da böl"\n'
              '• "Nasıl birleştirilir?"\n'
              '• "HaxBall ipuçları"\n\n'
              'Bir replay yüklediysen çok daha detaylı yanıtlar verebilirim!'
        : '🤔 I\'m not sure about that. Try:\n\n'
              '• "Show match stats"\n'
              '• "Split at 7:30"\n'
              '• "How to merge?"\n'
              '• "HaxBall tricks"\n\n'
              'Load a replay for more detailed answers!';
  }

  String _formatStats(MatchStats stats, bool isTr) {
    final buf = StringBuffer();
    buf.writeln(isTr ? '📊 **Maç İstatistikleri**' : '📊 **Match Statistics**');
    buf.writeln();
    buf.writeln(
      '**${isTr ? "Skor" : "Score"}:** 🔴 ${stats.redTeam.score}–${stats.blueTeam.score} 🔵',
    );
    buf.writeln('**${isTr ? "Süre" : "Duration"}:** ${stats.duration}');
    buf.writeln(
      '**${isTr ? "Top Hakimiyeti" : "Possession"}:** 🔴 ${stats.possession.red.toStringAsFixed(0)}% · 🔵 ${stats.possession.blue.toStringAsFixed(0)}%',
    );
    buf.writeln();
    buf.writeln(_formatGoals(stats, isTr));
    return buf.toString();
  }

  String _formatGoals(MatchStats stats, bool isTr) {
    if (stats.goals.isEmpty) {
      return isTr ? '0 gol kaydedildi.' : 'No goals recorded.';
    }
    final buf = StringBuffer();

    // Group by team
    final redGoals = stats.goals.where((g) => g.scoringTeam == 1).toList();
    final blueGoals = stats.goals.where((g) => g.scoringTeam == 2).toList();

    buf.writeln(
      isTr
          ? '**🔴 ${stats.redTeam.players.isNotEmpty ? stats.redTeam.players.first.split(' ').first : 'Red'} Team** — ${stats.redTeam.score} ${isTr ? 'gol' : 'goals'}'
          : '**🔴 Red Team** — ${stats.redTeam.score} goals',
    );
    for (final g in redGoals) {
      final assistStr = g.assist != null
          ? ' ${isTr ? 'Asist' : 'Assist'} **${g.assist}**'
          : '';
      buf.writeln(
        '⚽ ${g.redScore}–${g.blueScore} ${isTr ? 'Gol' : 'Goal'} **${g.scorer}**$assistStr  (${g.time})',
      );
    }
    buf.writeln();
    buf.writeln(
      isTr
          ? '**🔵 ${stats.blueTeam.players.isNotEmpty ? stats.blueTeam.players.first.split(' ').first : 'Blue'} Team** — ${stats.blueTeam.score} ${isTr ? 'gol' : 'goals'}'
          : '**🔵 Blue Team** — ${stats.blueTeam.score} goals',
    );
    for (final g in blueGoals) {
      final assistStr = g.assist != null
          ? ' ${isTr ? 'Asist' : 'Assist'} **${g.assist}**'
          : '';
      buf.writeln(
        '⚽ ${g.redScore}–${g.blueScore} ${isTr ? 'Gol' : 'Goal'} **${g.scorer}**$assistStr  (${g.time})',
      );
    }
    return buf.toString().trim();
  }

  // ── Send message ──────────────────────────────────────────────────────────────
  void _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _typing) return;
    final lang = context.read<SettingsProvider>().lang;

    setState(() {
      _messages.add(
        ChatMessage(
          role: MessageRole.user,
          content: text,
          timestamp: DateTime.now(),
        ),
      );
      _ctrl.clear();
      _typing = true;
    });
    _scrollToBottom();

    final response = await _getResponse(text, lang);

    if (mounted) {
      setState(() {
        _messages.add(
          ChatMessage(
            role: MessageRole.assistant,
            content: response,
            timestamp: DateTime.now(),
          ),
        );
        _typing = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // FAB is always centered at the bottom — no dragging
    const fabW = 52.0;
    const fabMarginBottom = 20.0;
    final fabLeft = (size.width - fabW) / 2;

    // Panel opens above the FAB, centered
    final panelLeft = ((size.width - 380) / 2).clamp(8.0, size.width - 388);
    const panelBottom = fabMarginBottom + fabW + 16;

    return Stack(
      children: [
        // ── Panel ──────────────────────────────────────────────────────────────────
        if (_open)
          Positioned(
            left: panelLeft,
            bottom: panelBottom,
            child: Material(
              color: Colors.transparent,
              child: _ChatPanel(
                messages: _messages,
                typing: _typing,
                ctrl: _ctrl,
                scroll: _scroll,
                onSend: _send,
                onClear: () => setState(() {
                  _messages.clear();
                  _addGreeting();
                }),
              ),
            ).animate().slideY(begin: 0.1).fadeIn(duration: 250.ms),
          ),
        // ── FAB (fixed bottom center) ─────────────────────────────────────────────
        Positioned(
          left: fabLeft,
          bottom: fabMarginBottom,
          child: _AiFab(
            open: _open,
            ringAnimation: _ring,
            onTap: () => setState(() => _open = !_open),
          ),
        ),
      ],
    );
  }
}

// ── AI FAB ─────────────────────────────────────────────────────────────────────
class _AiFab extends StatelessWidget {
  final bool open;
  final Animation<double> ringAnimation;
  final VoidCallback onTap;
  const _AiFab({
    required this.open,
    required this.ringAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // LED ring
        AnimatedBuilder(
          animation: ringAnimation,
          builder: (_, __) => Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                    AppTheme.purple,
                    AppTheme.indigo,
                    ringAnimation.value,
                  )!.withOpacity(0.7),
                  blurRadius: 18 + ringAnimation.value * 12,
                  spreadRadius: 2 + ringAnimation.value * 4,
                ),
              ],
            ),
          ),
        ),
        // Button
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppTheme.purple, AppTheme.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              open ? Icons.close_rounded : Icons.auto_awesome_rounded,
              key: ValueKey(open),
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Chat Panel ─────────────────────────────────────────────────────────────────
class _ChatPanel extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool typing;
  final TextEditingController ctrl;
  final ScrollController scroll;
  final VoidCallback onSend;
  final VoidCallback onClear;
  const _ChatPanel({
    required this.messages,
    required this.typing,
    required this.ctrl,
    required this.scroll,
    required this.onSend,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final l10n = AppL10n.of(context.read<SettingsProvider>().lang);
    return Container(
      width: 380,
      height: 520,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF0F1524) : Colors.white,
        border: Border.all(
          color: isDark ? AppTheme.border : AppTheme.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.purple.withOpacity(0.2),
            blurRadius: 40,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _PanelHeader(l10n: l10n, onClear: onClear),
          // Messages
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: const EdgeInsets.all(12),
              itemCount: messages.length + (typing ? 1 : 0),
              itemBuilder: (_, i) {
                if (typing && i == messages.length) {
                  return const _TypingBubble();
                }
                return _MessageBubble(msg: messages[i]);
              },
            ),
          ),
          // Input
          _ChatInput(ctrl: ctrl, onSend: onSend, l10n: l10n),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final AppL10n l10n;
  final VoidCallback onClear;
  const _PanelHeader({required this.l10n, required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      gradient: const LinearGradient(
        colors: [AppTheme.purple, AppTheme.indigo],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(
          l10n.t('ai.title'),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'AI',
            style: GoogleFonts.inter(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onClear,
          child: Icon(
            Icons.refresh_rounded,
            size: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final isDark = AppTheme.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.purple, AppTheme.indigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Copied!',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    duration: const Duration(seconds: 1),
                    backgroundColor: AppTheme.accent.withOpacity(0.8),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppTheme.purple.withOpacity(isDark ? 0.25 : 0.12)
                      : (isDark
                            ? const Color(0xFF141929)
                            : const Color(0xFFF5F5FA)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isUser ? 14 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 14),
                  ),
                  border: Border.all(
                    color: isUser
                        ? AppTheme.purple.withOpacity(0.3)
                        : AppTheme.borderOf(context),
                  ),
                ),
                child: Text(
                  msg.content,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.6,
                    color: AppTheme.textPrimOf(context),
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with TickerProviderStateMixin {
  late final List<AnimationController> _dots = List.generate(
    3,
    (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true, period: Duration(milliseconds: 600 + i * 150)),
  );

  @override
  void dispose() {
    for (final c in _dots) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.purple, AppTheme.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 13,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.isDark(context)
                ? const Color(0xFF141929)
                : const Color(0xFFF5F5FA),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: AppTheme.borderOf(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedBuilder(
                  animation: _dots[i],
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, -4 * _dots[i].value),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppTheme.purple.withOpacity(
                          0.6 + _dots[i].value * 0.4,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ChatInput extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSend;
  final AppL10n l10n;
  const _ChatInput({
    required this.ctrl,
    required this.onSend,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textPrimOf(context),
              decoration: TextDecoration.none,
            ),
            decoration: InputDecoration(
              hintText: l10n.t('ai.placeholder'),
              hintStyle: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textHintOf(context),
                decoration: TextDecoration.none,
              ),
              filled: true,
              fillColor: AppTheme.borderOf(context).withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onSubmitted: (_) => onSend(),
            maxLines: 3,
            minLines: 1,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onSend,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.purple, AppTheme.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    ),
  );
}
