import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/app_network_status_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Aviso quieto, en el tono de la app: solo si de verdad no llega nada.
class NetworkStatusBanner extends ConsumerStatefulWidget {
  const NetworkStatusBanner({super.key});

  @override
  ConsumerState<NetworkStatusBanner> createState() =>
      _NetworkStatusBannerState();
}

class _NetworkStatusBannerState extends ConsumerState<NetworkStatusBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(appNetworkStatusProvider.notifier).recheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final net = ref.watch(appNetworkStatusProvider);

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: net.showBanner
          ? ColoredBox(
              color: AppColors.surface,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.goldDark,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          net.bannerMessage,
                          style: AppTypography.labelSmall(
                            color: AppColors.textSecondary,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
