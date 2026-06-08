enum GuidanceSeverity {
  info,
  warning,
  critical,
}

class GuidanceMessage {
  final String title;
  final String body;
  final GuidanceSeverity severity;

  const GuidanceMessage({
    required this.title,
    required this.body,
    this.severity = GuidanceSeverity.info,
  });
}
