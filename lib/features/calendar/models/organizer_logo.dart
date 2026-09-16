class OrganizerLogo {
  const OrganizerLogo({
    required this.organizerKey,
    required this.displayLabel,
    required this.logoUrl,
  });

  final String organizerKey;
  final String displayLabel;
  final String logoUrl;

  bool get hasLogo => logoUrl.trim().isNotEmpty;
}
