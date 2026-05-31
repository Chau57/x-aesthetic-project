class AestheticResult {
  final double overallScore;
  final String label;
  final String summary;
  final List<FactorScore> factors;
  final String suggestion;

  const AestheticResult({
    required this.overallScore,
    required this.label,
    required this.summary,
    required this.factors,
    required this.suggestion,
  });
}

class FactorScore {
  final String name;
  final double score;
  final String status;
  final bool needsImprovement;

  const FactorScore({
    required this.name,
    required this.score,
    required this.status,
    required this.needsImprovement,
  });
}
