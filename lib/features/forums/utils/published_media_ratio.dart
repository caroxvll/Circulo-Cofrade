/// Conserva el formato real, permitiendo vertical 9:16 y horizontal hasta 16:9.
double clampPublishedAspectRatio(double aspectRatio) {
  if (aspectRatio <= 0 || aspectRatio.isNaN) return 16 / 9;
  if (aspectRatio < 1) return aspectRatio.clamp(9 / 16, 1);
  return aspectRatio.clamp(1, 16 / 9);
}
