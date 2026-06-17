import 'package:flutter/material.dart';



import '../../../core/theme/app_colors.dart';

import '../../../core/theme/app_typography.dart';



class RepliesLoadMoreButton extends StatelessWidget {

  const RepliesLoadMoreButton({

    super.key,

    required this.loadedCount,

    required this.totalCount,

    required this.isLoading,

    required this.hasMore,

    required this.onLoadMore,

  });



  final int loadedCount;

  final int totalCount;

  final bool isLoading;

  final bool hasMore;

  final VoidCallback onLoadMore;



  @override

  Widget build(BuildContext context) {

    if (!hasMore) {

      if (totalCount > 0 && loadedCount >= totalCount) {

        return Padding(

          padding: const EdgeInsets.only(top: 8),

          child: Text(

            'No hay respuestas más antiguas',

            style: AppTypography.labelSmall(color: AppColors.textMuted),

            textAlign: TextAlign.center,

          ),

        );

      }

      return const SizedBox.shrink();

    }



    final remaining = totalCount > loadedCount ? totalCount - loadedCount : null;



    return Padding(

      padding: const EdgeInsets.only(top: 8),

      child: OutlinedButton.icon(

        onPressed: isLoading ? null : onLoadMore,

        icon: isLoading

            ? const SizedBox(

                width: 16,

                height: 16,

                child: CircularProgressIndicator(strokeWidth: 2),

              )

            : const Icon(Icons.history, size: 20),

        label: Text(

          isLoading

              ? 'Cargando…'

              : remaining != null

                  ? 'Ver respuestas anteriores ($remaining)'

                  : 'Ver respuestas anteriores',

        ),

        style: OutlinedButton.styleFrom(

          foregroundColor: AppColors.burgundy,

          side: const BorderSide(color: AppColors.burgundy),

          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),

        ),

      ),

    );

  }

}

