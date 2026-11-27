import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class CompressedImage {
  const CompressedImage({
    required this.bytes,
    required this.mimeType,
    this.wasCompressed = false,
  });

  final Uint8List bytes;
  final String mimeType;
  final bool wasCompressed;
}

/// Límites recomendados por tipo de subida.
abstract final class ImageUploadLimits {
  static const avatarMaxBytes = 400 * 1024;
  static const avatarMaxSide = 512;
  static const postMaxBytes = 5 * 1024 * 1024;
  static const postMaxSide = 1920;
  static const eventIconMaxBytes = 200 * 1024;
  static const eventIconMaxSide = 512;
  static const eventCoverMaxBytes = 800 * 1024;
  static const eventCoverMaxSide = 1920;
  static const pillarIconMaxBytes = 300 * 1024;
  static const pillarIconMaxSide = 512;
  static const pillarCoverMaxBytes = 800 * 1024;
  static const pillarCoverMaxSide = 1200;
  static const profileCoverMaxBytes = 800 * 1024;
  static const profileCoverMaxSide = 1600;

  /// Tamaño máximo del archivo original antes de optimizar (calendario).
  static const eventIconPickMaxBytes = 5 * 1024 * 1024;
  static const eventCoverPickMaxBytes = 15 * 1024 * 1024;
}

/// Resultado listo para subir a storage (raster optimizado o SVG sin tocar).
class PreparedImageUpload {
  const PreparedImageUpload({
    required this.bytes,
    required this.extension,
    required this.contentType,
    this.wasCompressed = false,
    this.originalBytes,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
  final bool wasCompressed;
  final int? originalBytes;
}

bool isSvgUploadExtension(String extension) =>
    extension.toLowerCase() == 'svg';

/// Optimiza raster para subida; los SVG se devuelven tal cual.
Future<PreparedImageUpload> prepareImageUploadAsync({
  required Uint8List rawBytes,
  required String extension,
  required String contentType,
  required int maxBytes,
  required int maxSide,
  bool fitAvatarCircle = false,
}) async {
  if (isSvgUploadExtension(extension)) {
    return PreparedImageUpload(
      bytes: rawBytes,
      extension: extension,
      contentType: contentType,
    );
  }

  final compressed = await compressImageForUploadAsync(
    rawBytes,
    maxBytes: maxBytes,
    maxSide: maxSide,
    fitAvatarCircle: fitAvatarCircle,
  );

  return PreparedImageUpload(
    bytes: compressed.bytes,
    extension: 'jpg',
    contentType: 'image/jpeg',
    wasCompressed:
        compressed.wasCompressed || compressed.bytes.length < rawBytes.length,
    originalBytes: rawBytes.length,
  );
}

/// Reduce tamaño para subida: redimensiona y comprime JPEG hasta caber en [maxBytes].
CompressedImage compressImageForUpload(
  Uint8List input, {
  int maxBytes = ImageUploadLimits.postMaxBytes,
  int maxSide = ImageUploadLimits.postMaxSide,
  bool fitAvatarCircle = false,
}) {
  final decoded = img.decodeImage(input);
  if (decoded == null) {
    return CompressedImage(bytes: input, mimeType: _guessMime(input));
  }

  var working = fitAvatarCircle ? _fitImageToAvatarCircle(decoded) : decoded;
  var side = maxSide;
  var quality = 88;
  var output = _encodeJpeg(working, quality);
  var wasCompressed = output.length < input.length;

  while (output.length > maxBytes) {
    wasCompressed = true;
    if (quality > 45) {
      quality -= 12;
      output = _encodeJpeg(working, quality);
      continue;
    }
    if (side > 720) {
      side = (side * 0.82).round();
      working = img.copyResize(
        working,
        width: working.width >= working.height ? side : null,
        height: working.height > working.width ? side : null,
        interpolation: img.Interpolation.linear,
      );
      quality = 82;
      output = _encodeJpeg(working, quality);
      continue;
    }
    break;
  }

  if (output.length > maxBytes) {
    throw ImageTooLargeAfterCompressException(output.length);
  }

  return CompressedImage(
    bytes: output,
    mimeType: 'image/jpeg',
    wasCompressed: wasCompressed || output.length < input.length,
  );
}

/// Igual que [compressImageForUpload] pero fuera del hilo de UI.
Future<CompressedImage> compressImageForUploadAsync(
  Uint8List input, {
  int maxBytes = ImageUploadLimits.postMaxBytes,
  int maxSide = ImageUploadLimits.postMaxSide,
  bool fitAvatarCircle = false,
}) {
  return compute(
    _compressImageForUploadIsolate,
    _CompressImageRequest(
      input: input,
      maxBytes: maxBytes,
      maxSide: maxSide,
      fitAvatarCircle: fitAvatarCircle,
    ),
  );
}

class _CompressImageRequest {
  const _CompressImageRequest({
    required this.input,
    required this.maxBytes,
    required this.maxSide,
    this.fitAvatarCircle = false,
  });

  final Uint8List input;
  final int maxBytes;
  final int maxSide;
  final bool fitAvatarCircle;
}

CompressedImage _compressImageForUploadIsolate(_CompressImageRequest request) {
  return compressImageForUpload(
    request.input,
    maxBytes: request.maxBytes,
    maxSide: request.maxSide,
    fitAvatarCircle: request.fitAvatarCircle,
  );
}

/// Quita margen blanco/transparente y recorta a cuadrado para que el escudo
/// llene el círculo del avatar.
img.Image _fitImageToAvatarCircle(img.Image source) {
  final box = _contentBounds(source);
  if (box == null) return source;

  final pad = ((box.width > box.height ? box.width : box.height) * 0.04)
      .round()
      .clamp(2, 24);
  var x = (box.left - pad).clamp(0, source.width - 1);
  var y = (box.top - pad).clamp(0, source.height - 1);
  var w = (box.width + pad * 2).clamp(1, source.width - x);
  var h = (box.height + pad * 2).clamp(1, source.height - y);

  final trimmed = img.copyCrop(source, x: x, y: y, width: w, height: h);
  final side = trimmed.width < trimmed.height ? trimmed.width : trimmed.height;
  if (side <= 0) return trimmed;
  final ox = ((trimmed.width - side) / 2).round();
  final oy = ((trimmed.height - side) / 2).round();
  return img.copyCrop(trimmed, x: ox, y: oy, width: side, height: side);
}

({int left, int top, int width, int height})? _contentBounds(img.Image source) {
  var minX = source.width;
  var minY = source.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      if (!_isAvatarContentPixel(source.getPixel(x, y))) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < minX) return null;
  return (left: minX, top: minY, width: maxX - minX + 1, height: maxY - minY + 1);
}

bool _isAvatarContentPixel(img.Pixel pixel) {
  if (pixel.a < 24) return false;
  // Fondos blancos o crema típicos de escudos PNG.
  if (pixel.r >= 242 && pixel.g >= 242 && pixel.b >= 236) return false;
  return true;
}

Uint8List _encodeJpeg(img.Image image, int quality) {
  return Uint8List.fromList(img.encodeJpg(image, quality: quality));
}

String _guessMime(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  return 'image/jpeg';
}

class ImageTooLargeAfterCompressException implements Exception {
  ImageTooLargeAfterCompressException(this.bytesLength);

  final int bytesLength;
}

String formatImageSize(int bytes) {
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).round()} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
