// lib/core/app_l10n.dart
// English / Turkish localization map

class AppL10n {
  final Map<String, String> _strings;
  const AppL10n._(this._strings);

  String t(String key) => _strings[key] ?? key;

  static const AppL10n en = AppL10n._(_en);
  static const AppL10n tr = AppL10n._(_tr);

  static AppL10n of(String langCode) => langCode == 'tr' ? tr : en;

  static const Map<String, String> _en = {
    // Nav
    'nav.merge': 'Merge',
    'nav.split': 'Split',
    'nav.analyze': 'Analyze',
    'nav.guide': 'Guide',
    'nav.about': 'About',
    'nav.settings': 'Settings',

    // Merge screen
    'merge.title': 'Merge Replays',
    'merge.subtitle': 'Combine multiple .hbr2 files into one continuous replay',
    'merge.drop': 'Drag & drop .hbr2 files',
    'merge.dropSub': 'or click to browse',
    'merge.dropHint': 'Drop files here',
    'merge.addFile': 'ADD FILE',
    'merge.outputPath': 'Auto-save to Downloads',
    'merge.browse': 'Browse',
    'merge.run': 'Merge Replays',
    'merge.running': 'Merging...',
    'merge.resultLog': 'PROCESS LOG',
    'merge.showFile': 'Show File',

    // Split screen
    'split.title': 'Split Replay',
    'split.subtitle':
        'Cut a replay at any point in time into two separate files',
    'split.drop': 'Drag & drop a .hbr2 file',
    'split.dropSub': 'or click to browse',
    'split.splitAt': 'SPLIT AT TIME',
    'split.frame': 'Frame',
    'split.part1': 'Part 1 output',
    'split.part2': 'Part 2 output',
    'split.run': 'Split Replay',
    'split.running': 'Splitting...',

    // Analyze
    'analyze.title': 'Match Analyzer',
    'analyze.subtitle': 'Full statistics: goals, assists, possession & more',
    'analyze.drop': 'Drop .hbr2 file to analyze',
    'analyze.redTeam': 'Red Team',
    'analyze.blueTeam': 'Blue Team',
    'analyze.goals': 'Goals',
    'analyze.assists': 'Assists',
    'analyze.kicks': 'Kicks',
    'analyze.poss': 'Possession',
    'analyze.duration': 'Duration',
    'analyze.timeline': 'Match Timeline',
    'analyze.players': 'Player Statistics',

    // Guide
    'guide.title': 'How It Works',
    'guide.subtitle': 'Visual guide to merge & split operations',
    'guide.play': 'Play Animation',
    'guide.replay': 'Replay',

    // About
    'about.title': 'About HBR Studio',
    'about.subtitle': 'HaxBall replay editor for the community',

    // Settings
    'settings.title': 'Settings',
    'settings.theme': 'Appearance',
    'settings.dark': 'Dark',
    'settings.light': 'Light',
    'settings.lang': 'Language',
    'settings.en': 'English',
    'settings.tr': 'Türkçe',
    'settings.perf': 'Performance',
    'settings.fps': 'High refresh rate (360Hz)',

    // AI Chat
    'ai.title': 'HaxReplay AI',
    'ai.placeholder': 'Ask about your replay, request merge/split...',
    'ai.clear': 'Clear chat',
    'ai.copy': 'Copy',
    'ai.greeting':
        'Hi! I\'m HaxReplay AI. Load a .hbr2 replay and I can show you match stats, help you split at a specific time, or merge multiple files.\n\nWhat would you like to do?',

    // Common
    'common.ready': 'Ready',
    'common.success': 'Done',
    'common.error': 'Error',
    'common.cancel': 'Cancel',
    'common.open': 'Open File',
  };

  static const Map<String, String> _tr = {
    // Nav
    'nav.merge': 'Birleştir',
    'nav.split': 'Böl',
    'nav.analyze': 'Analiz',
    'nav.guide': 'Rehber',
    'nav.about': 'Hakkında',
    'nav.settings': 'Ayarlar',

    // Merge
    'merge.title': 'Replay Birleştir',
    'merge.subtitle': 'Birden fazla .hbr2 dosyasını tek bir kayıtta birleştir',
    'merge.drop': '.hbr2 dosyalarını sürükle & bırak',
    'merge.dropSub': 'veya tıklayarak seç',
    'merge.dropHint': 'Dosyaları buraya bırak',
    'merge.addFile': 'DOSYA EKLE',
    'merge.outputPath': 'Downloads klasörüne kaydet',
    'merge.browse': 'Seç',
    'merge.run': 'Birleştir',
    'merge.running': 'Birleştiriliyor...',
    'merge.resultLog': 'İŞLEM GÜNLÜĞÜ',
    'merge.showFile': 'Dosyayı Göster',

    // Split
    'split.title': 'Replay Böl',
    'split.subtitle': 'Bir replay\'i istediğiniz anda iki ayrı dosyaya bölün',
    'split.drop': '.hbr2 dosyasını sürükle & bırak',
    'split.dropSub': 'veya tıklayarak seç',
    'split.splitAt': 'BÖLME NOKTASI',
    'split.frame': 'Kare',
    'split.part1': 'Bölüm 1 çıktısı',
    'split.part2': 'Bölüm 2 çıktısı',
    'split.run': 'Böl',
    'split.running': 'Bölünüyor...',

    // Analyze
    'analyze.title': 'Maç Analizörü',
    'analyze.subtitle':
        'Tam istatistikler: goller, asistler, top hakimiyeti ve daha fazlası',
    'analyze.drop': 'Analiz için .hbr2 dosyası bırak',
    'analyze.redTeam': 'Kırmızı Takım',
    'analyze.blueTeam': 'Mavi Takım',
    'analyze.goals': 'Goller',
    'analyze.assists': 'Asistler',
    'analyze.kicks': 'Vuruşlar',
    'analyze.poss': 'Top Hakimiyeti',
    'analyze.duration': 'Süre',
    'analyze.timeline': 'Maç Kronolojisi',
    'analyze.players': 'Oyuncu İstatistikleri',

    // Guide
    'guide.title': 'Nasıl Çalışır',
    'guide.subtitle': 'Birleştirme ve bölme için görsel rehber',
    'guide.play': 'Animasyonu Oynat',
    'guide.replay': 'Tekrar',

    // About
    'about.title': 'HBR Studio Hakkında',
    'about.subtitle': 'Topluluk için HaxBall replay düzenleyici',

    // Settings
    'settings.title': 'Ayarlar',
    'settings.theme': 'Görünüm',
    'settings.dark': 'Koyu',
    'settings.light': 'Açık',
    'settings.lang': 'Dil',
    'settings.en': 'English',
    'settings.tr': 'Türkçe',
    'settings.perf': 'Performans',
    'settings.fps': 'Yüksek yenileme hızı (360Hz)',

    // AI Chat
    'ai.title': 'HaxReplay AI',
    'ai.placeholder': 'Replay hakkında soru sor, birleştir/böl...',
    'ai.clear': 'Sohbeti temizle',
    'ai.copy': 'Kopyala',
    'ai.greeting':
        'Merhaba! Ben HaxReplay AI. Bir .hbr2 replay yükle, maç istatistiklerini göstereyim, belirli bir andan böleyim ya da birden fazla dosyayı birleştireyim.\n\nNe yapmak istersiniz?',

    // Common
    'common.ready': 'Hazır',
    'common.success': 'Tamam',
    'common.error': 'Hata',
    'common.cancel': 'İptal',
    'common.open': 'Dosya Aç',
  };
}
