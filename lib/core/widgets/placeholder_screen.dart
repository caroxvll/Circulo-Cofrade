import 'package:flutter/material.dart';

import '../constants/app_branding.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_logo.dart';
import 'cofradeo_badge.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.phase,
    this.subtitle,
    this.showDesignPreview = true,
  });

  final String title;
  final String phase;
  final String? subtitle;
  final bool showDesignPreview;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              title.toUpperCase(),
              style: AppTypography.screenTitle(),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: AppTypography.bodyMedium()),
            ],
            const Spacer(),
            if (showDesignPreview) ...[
              Center(
                child: Column(
                  children: [
                    const AppLogo(size: 140),
                    const SizedBox(height: 16),
                    Text(
                      AppBranding.nameUpper,
                      style: AppTypography.displayMedium(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppBranding.tagline,
                      style: AppTypography.bodyMedium(color: AppColors.goldDark),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
            Center(
              child: CofradeoBadge(label: phase),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
