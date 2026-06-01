class OverlayOptions {
  final bool ruleOfThirds;
  final bool horizonLine;
  final bool suggestedFrame;

  const OverlayOptions({
    this.ruleOfThirds = true,
    this.horizonLine = false,
    this.suggestedFrame = false,
  });

  OverlayOptions copyWith({
    bool? ruleOfThirds,
    bool? horizonLine,
    bool? suggestedFrame,
  }) {
    return OverlayOptions(
      ruleOfThirds: ruleOfThirds ?? this.ruleOfThirds,
      horizonLine: horizonLine ?? this.horizonLine,
      suggestedFrame: suggestedFrame ?? this.suggestedFrame,
    );
  }
}
