// lib/models/match_stats.dart
// Data models for HBR2 replay analysis

class MatchStats {
  final String fileName;
  final int totalFrames;
  final int durationSec;
  final String duration;
  final TeamStats redTeam;
  final TeamStats blueTeam;
  final List<GoalEvent> goals;
  final List<PlayerStat> playerStats;
  final Possession possession;
  final int events;
  final int goalCount;

  const MatchStats({
    required this.fileName,
    required this.totalFrames,
    required this.durationSec,
    required this.duration,
    required this.redTeam,
    required this.blueTeam,
    required this.goals,
    required this.playerStats,
    required this.possession,
    required this.events,
    required this.goalCount,
  });

  factory MatchStats.fromJson(Map<String, dynamic> j) => MatchStats(
    fileName: j['fileName'] as String,
    totalFrames: j['totalFrames'] as int,
    durationSec: j['durationSec'] as int,
    duration: j['duration'] as String,
    redTeam: TeamStats.fromJson(j['teams']['red'] as Map<String, dynamic>),
    blueTeam: TeamStats.fromJson(j['teams']['blue'] as Map<String, dynamic>),
    goals: (j['goals'] as List)
        .map((g) => GoalEvent.fromJson(g as Map<String, dynamic>))
        .toList(),
    playerStats: (j['playerStats'] as List)
        .map((p) => PlayerStat.fromJson(p as Map<String, dynamic>))
        .toList(),
    possession: Possession.fromJson(j['possession'] as Map<String, dynamic>),
    events: j['events'] as int,
    goalCount: j['goalCount'] as int,
  );
}

class TeamStats {
  final int score;
  final List<String> players;
  TeamStats({required this.score, required this.players});
  factory TeamStats.fromJson(Map<String, dynamic> j) => TeamStats(
    score: j['score'] as int,
    players: List<String>.from(j['players'] as List),
  );
}

class GoalEvent {
  final int frameNo;
  final String time;
  final int timeSec;
  final int scoringTeam; // 1=red, 2=blue
  final int redScore;
  final int blueScore;
  final String scorer;
  final String? assist;

  const GoalEvent({
    required this.frameNo,
    required this.time,
    required this.timeSec,
    required this.scoringTeam,
    required this.redScore,
    required this.blueScore,
    required this.scorer,
    this.assist,
  });

  factory GoalEvent.fromJson(Map<String, dynamic> j) => GoalEvent(
    frameNo: j['frameNo'] as int,
    time: j['time'] as String,
    timeSec: j['timeSec'] as int,
    scoringTeam: j['scoringTeam'] as int,
    redScore: j['redScore'] as int,
    blueScore: j['blueScore'] as int,
    scorer: j['scorer'] as String,
    assist: j['assist'] as String?,
  );
}

class PlayerStat {
  final int id;
  final String name;
  final int team; // 1=red, 2=blue
  final int goals;
  final int assists;
  final int kicks;

  const PlayerStat({
    required this.id,
    required this.name,
    required this.team,
    required this.goals,
    required this.assists,
    required this.kicks,
  });

  factory PlayerStat.fromJson(Map<String, dynamic> j) => PlayerStat(
    id: j['id'] as int,
    name: j['name'] as String,
    team: j['team'] as int,
    goals: j['goals'] as int,
    assists: j['assists'] as int,
    kicks: j['kicks'] as int,
  );
}

class Possession {
  final double red;
  final double blue;
  const Possession({required this.red, required this.blue});
  factory Possession.fromJson(Map<String, dynamic> j) => Possession(
    red: (j['red'] as num).toDouble(),
    blue: (j['blue'] as num).toDouble(),
  );
}
