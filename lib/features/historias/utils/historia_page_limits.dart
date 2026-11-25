/// Una hoja del Cronicón tiene que caber sin scroll.
const historiaPageMaxWords = 90;
const historiaPageMaxWordsWithImage = 40;

int countHistoriaWords(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return 0;
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (match) => match.group(1) ?? '',
  );
  text = text.replaceAll(RegExp(r'[#*_>`]+'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return 0;
  return text.split(' ').length;
}

int historiaPageWordLimit({required bool hasImage}) =>
    hasImage ? historiaPageMaxWordsWithImage : historiaPageMaxWords;

String historiaPageWordHint({required bool hasImage}) {
  final max = historiaPageWordLimit(hasImage: hasImage);
  return hasImage
      ? 'Con foto caben unas $max palabras, para que no haya que hacer scroll.'
      : 'Como mucho $max palabras por hoja, como en un libro.';
}
