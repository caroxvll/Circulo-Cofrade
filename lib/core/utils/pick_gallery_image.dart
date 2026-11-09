import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Foto elegida en la galería del teléfono.
class GalleryImage {
  const GalleryImage({
    required this.bytes,
    required this.name,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String name;
  final String extension;
  final String contentType;
}

/// Abre la galería de fotos, no el explorador de archivos.
Future<GalleryImage?> pickGalleryImage({
  double maxWidth = 2400,
  int imageQuality = 85,
}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxWidth,
    imageQuality: imageQuality,
  );
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  final rawName = file.name.trim();
  final name = rawName.isEmpty ? 'foto.jpg' : rawName;
  final dot = name.lastIndexOf('.');
  var extension = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  if (extension == 'jpeg') extension = 'jpg';

  final mime = file.mimeType?.toLowerCase();
  if (extension != 'png' && extension != 'webp' && extension != 'jpg') {
    extension = switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  final contentType = switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };

  return GalleryImage(
    bytes: bytes,
    name: name,
    extension: extension == 'png' || extension == 'webp' ? extension : 'jpg',
    contentType: contentType,
  );
}
