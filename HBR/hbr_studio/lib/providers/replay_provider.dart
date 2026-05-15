// lib/providers/replay_provider.dart
// Holds the currently analyzed replay file so AI and other screens can access it

import 'package:flutter/foundation.dart';
import '../models/match_stats.dart';

class ReplayProvider extends ChangeNotifier {
  MatchStats? _stats;
  String? _loadedPath;
  bool _analyzing = false;

  MatchStats? get stats => _stats;
  String? get loadedPath => _loadedPath;
  bool get analyzing => _analyzing;
  bool get hasStats => _stats != null;

  void setStats(String path, MatchStats stats) {
    _loadedPath = path;
    _stats = stats;
    _analyzing = false;
    notifyListeners();
  }

  void setAnalyzing(bool v) {
    _analyzing = v;
    notifyListeners();
  }

  void clear() {
    _stats = null;
    _loadedPath = null;
    _analyzing = false;
    notifyListeners();
  }
}
