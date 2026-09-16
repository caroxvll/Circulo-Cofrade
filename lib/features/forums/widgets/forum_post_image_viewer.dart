import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/share_remote_image.dart';
import '../../../core/widgets/cofradeo_network_image.dart';

/// Visor a pantalla completa con zoom (pinch) para carteles y fotos.
Future<void> showForumPostImageViewer(
  BuildContext context, {
  required String imageUrl,
  String? shareText,
}) {
  final url = imageUrl.trim();
  if (url.isEmpty) return Future.value();

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar imagen',
    barrierColor: Colors.black.withValues(alpha: 0.92),
    pageBuilder: (context, _, __) {
      return _ForumPostImageViewerPage(
        imageUrl: url,
        shareText: shareText,
      );
    },
    transitionBuilder: (context, animation, _, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _ForumPostImageViewerPage extends StatefulWidget {
  const _ForumPostImageViewerPage({
    required this.imageUrl,
    this.shareText,
  });

  final String imageUrl;
  final String? shareText;

  @override
  State<_ForumPostImageViewerPage> createState() =>
      _ForumPostImageViewerPageState();
}

class _ForumPostImageViewerPageState extends State<_ForumPostImageViewerPage> {
  var _sharing = false;
  final _shareButtonKey = GlobalKey();

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    Rect? origin;
    final box =
        _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }

    final ok = await shareRemoteImage(
      imageUrl: widget.imageUrl,
      text: widget.shareText,
      sharePositionOrigin: origin,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el cartel.')),
      );
    }

    if (mounted) setState(() => _sharing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.6,
                maxScale: 5,
                child: Center(
                  child: CofradeoNetworkImage(
                    url: widget.imageUrl,
                    fit: BoxFit.contain,
                    cacheSize: MediaQuery.sizeOf(context).width,
                    placeholder: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 2,
                      ),
                    ),
                    errorWidget: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  key: _shareButtonKey,
                  tooltip: 'Compartir cartel',
                  onPressed: _sharing ? null : _share,
                  icon: _sharing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share_outlined, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
