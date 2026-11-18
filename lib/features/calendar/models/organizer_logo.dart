class OrganizerLogo {
  const OrganizerLogo({
    required this.organizerKey,
    required this.displayLabel,
    required this.logoUrl,
    this.hermandadTopicId,
  });

  final String organizerKey;
  final String displayLabel;
  final String logoUrl;

  /// Si viene de un tablón oficial (`forum_topics` / hermandades).
  final String? hermandadTopicId;

  bool get hasLogo => logoUrl.trim().isNotEmpty;
  bool get isHermandadBoard =>
      hermandadTopicId != null && hermandadTopicId!.trim().isNotEmpty;
}
