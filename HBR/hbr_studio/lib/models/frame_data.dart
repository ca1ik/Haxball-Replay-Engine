// lib/models/frame_data.dart
// Data models for per-frame replay position data (match viewer)

import 'dart:ui' show Offset;

// ── Per-player position snapshot ──────────────────────────────────────────────
class PlayerPos {
  final int id;
  final double x;
  final double y;

  const PlayerPos({required this.id, required this.x, required this.y});

  factory PlayerPos.fromJson(Map<String, dynamic> j) => PlayerPos(
    id: (j['id'] as num).toInt(),
    x: (j['x'] as num).toDouble(),
    y: (j['y'] as num).toDouble(),
  );

  Offset get offset => Offset(x, y);
}

// ── Single sampled frame ──────────────────────────────────────────────────────
class FrameData {
  final int frame;
  final List<PlayerPos> players;
  final Offset? ball;

  const FrameData({required this.frame, required this.players, this.ball});

  factory FrameData.fromJson(Map<String, dynamic> j) => FrameData(
    frame: (j['f'] as num).toInt(),
    players: (j['players'] as List)
        .map((p) => PlayerPos.fromJson(p as Map<String, dynamic>))
        .toList(),
    ball: j['ball'] != null
        ? Offset(
            (j['ball']['x'] as num).toDouble(),
            (j['ball']['y'] as num).toDouble(),
          )
        : null,
  );
}

// ── Player metadata for display ───────────────────────────────────────────────
class PlayerInfo {
  final int id;
  final String name;
  final int team; // 1=red, 2=blue, 0=spec

  const PlayerInfo({required this.id, required this.name, required this.team});
}

// ── Goal timeline entry ───────────────────────────────────────────────────────
class GoalMarker {
  final int frameNo;
  final int teamId; // 1=red, 2=blue

  const GoalMarker({required this.frameNo, required this.teamId});
}

// ── Full replay metadata ──────────────────────────────────────────────────────
class FrameMeta {
  final int totalFrames;
  final int durationMs;
  final int halfFrame;
  final Map<int, PlayerInfo> playerMap;
  final List<GoalMarker> goals;

  const FrameMeta({
    required this.totalFrames,
    required this.durationMs,
    required this.halfFrame,
    required this.playerMap,
    required this.goals,
  });

  factory FrameMeta.fromJson(Map<String, dynamic> j) {
    final rawMap = j['playerMap'] as Map<String, dynamic>;
    final playerMap = <int, PlayerInfo>{};
    for (final entry in rawMap.entries) {
      final id = int.parse(entry.key);
      final v = entry.value as Map<String, dynamic>;
      playerMap[id] = PlayerInfo(
        id: id,
        name: v['name'] as String,
        team: (v['team'] as num).toInt(),
      );
    }

    final goals = (j['goals'] as List)
        .map(
          (g) => GoalMarker(
            frameNo: (g['frameNo'] as num).toInt(),
            teamId: (g['teamId'] as num).toInt(),
          ),
        )
        .toList();

    return FrameMeta(
      totalFrames: (j['totalFrames'] as num).toInt(),
      durationMs: (j['durationMs'] as num).toInt(),
      halfFrame: (j['halfFrame'] as num).toInt(),
      playerMap: playerMap,
      goals: goals,
    );
  }
}

// ── Loaded replay session (meta + all frames) ─────────────────────────────────
class ReplaySession {
  final String filePath;
  final FrameMeta meta;
  final List<FrameData> frames;

  const ReplaySession({
    required this.filePath,
    required this.meta,
    required this.frames,
  });

  /// Interpolate player/ball positions at an arbitrary frame number.
  FrameData interpolateAt(int frame) {
    if (frames.isEmpty) return FrameData(frame: frame, players: []);
    if (frames.length == 1) return frames.first;

    // Binary search for the bounding keyframes
    int lo = 0, hi = frames.length - 1;
    while (lo < hi - 1) {
      final mid = (lo + hi) ~/ 2;
      if (frames[mid].frame <= frame) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final a = frames[lo];
    final b = frames[hi];

    if (a.frame == b.frame || frame <= a.frame) return a;
    if (frame >= b.frame) return b;

    final t = (frame - a.frame) / (b.frame - a.frame);

    // Interpolate ball
    Offset? ball;
    if (a.ball != null && b.ball != null) {
      ball = Offset.lerp(a.ball, b.ball, t);
    }

    // Interpolate per-player positions (matched by id)
    final bById = {for (final p in b.players) p.id: p};
    final players = <PlayerPos>[];
    for (final pa in a.players) {
      final pb = bById[pa.id];
      if (pb == null) {
        players.add(pa);
      } else {
        players.add(
          PlayerPos(
            id: pa.id,
            x: pa.x + (pb.x - pa.x) * t,
            y: pa.y + (pb.y - pa.y) * t,
          ),
        );
      }
    }

    return FrameData(frame: frame, players: players, ball: ball);
  }
}
