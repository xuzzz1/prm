import 'movie.dart';

class ScoredMovie {
  final Movie movie;
  final double totalScore;
  final double contentScore;
  final double affinityScore;
  final double actorScore;
  final double trendingScore;
  final double freshnessScore;
  final String matchReason;

  ScoredMovie({
    required this.movie,
    required this.totalScore,
    required this.contentScore,
    required this.affinityScore,
    required this.actorScore,
    required this.trendingScore,
    required this.freshnessScore,
    required this.matchReason,
  });

  double get normalizedScore => totalScore;

  String get matchPercentage {
    final pct = (totalScore * 100).clamp(0, 100).round();
    return '$pct%';
  }
}
