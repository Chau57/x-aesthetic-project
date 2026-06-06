enum OverlayType {
  ruleOfThirdsGrid,
  goldenRatioGrid,
  horizonLine,
  symmetryLine,
  focusPoint,
  heatmap,
  ghostFrame,
}

class OverlayInstruction {
  final OverlayType type;
  final Map<String, Object> payload;

  const OverlayInstruction({
    required this.type,
    this.payload = const {},
  });
}
