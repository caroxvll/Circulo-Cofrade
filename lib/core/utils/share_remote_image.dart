import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

/// Comparte una imagen remota (cartel). Devuelve `false` solo si todo falla.
Future<bool> shareRemoteImage({
  required String imageUrl,
  String? text,
  Rect? sharePositionOrigin,
}) async {
  final trimmedUrl = imageUrl.trim();
  if (trimmedUrl.isEmpty) return false;

  final uri = Uri.tryParse(trimmedUrl);
  if (uri == null) {
    return _shareTextOnly(
      _shareMessage(text: text, fallbackUrl: trimmedUrl),
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  if (kIsWeb) {
    return _shareTextOnly(
      _shareMessage(text: text, fallbackUrl: trimmedUrl),
      sharePositionOrigin: sharePositionOrigin,
      uri: uri,
    );
  }

  try {
    final response = await http
        .get(
          uri,
          headers: const {'User-Agent': 'Cofradeo/1.0'},
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final mime = _normalizeMimeType(
        uri: uri,
        contentType: response.headers['content-type'],
      );
      final shared = await _shareImageBytes(
        bytes: response.bodyBytes,
        mimeType: mime,
        sharePositionOrigin: sharePositionOrigin,
      );
      if (shared) return true;
    }
  } catch (_) {
    // Descarga o share como archivo falló → enlace de texto.
  }

  return _shareTextOnly(
    _shareMessage(text: text, fallbackUrl: trimmedUrl),
    sharePositionOrigin: sharePositionOrigin,
  );
}

Future<bool> _shareImageBytes({
  required Uint8List bytes,
  required String mimeType,
  Rect? sharePositionOrigin,
}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        title: 'Cofradeo',
        files: [
          XFile.fromData(
            bytes,
            mimeType: mimeType,
            name: 'cartel_cofradeo.jpg',
          ),
        ],
        fileNameOverrides: const ['cartel_cofradeo.jpg'],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return true;
  } on PlatformException {
    return false;
  } catch (_) {
    return false;
  }
}

Future<bool> _shareTextOnly(
  String message, {
  Rect? sharePositionOrigin,
  Uri? uri,
}) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        uri: uri,
        title: 'Cofradeo',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}

String _shareMessage({String? text, required String fallbackUrl}) {
  if (text == null || text.trim().isEmpty) return fallbackUrl;
  return '$text\n$fallbackUrl';
}

String _normalizeMimeType({required Uri uri, String? contentType}) {
  final type = contentType?.split(';').first.trim().toLowerCase();
  return switch (type) {
    'image/png' => 'image/png',
    'image/webp' => 'image/webp',
    'image/gif' => 'image/gif',
    'image/jpeg' || 'image/jpg' => 'image/jpeg',
    _ => _mimeFromPath(uri.path),
  };
}

String _mimeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
