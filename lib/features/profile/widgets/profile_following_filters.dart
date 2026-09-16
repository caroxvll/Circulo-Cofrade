import 'package:flutter/material.dart';



import '../../../core/theme/app_colors.dart';

import '../../../core/theme/app_typography.dart';



enum FollowingSegment { personas, foros }



class ProfileFollowingFilters extends StatelessWidget {

  const ProfileFollowingFilters({

    super.key,

    required this.segment,

    required this.onSelected,

  });



  final FollowingSegment segment;

  final ValueChanged<FollowingSegment> onSelected;



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.all(3),

      decoration: BoxDecoration(

        color: AppColors.surface,

        borderRadius: BorderRadius.circular(22),

        border: Border.all(

          color: AppColors.border.withValues(alpha: 0.7),

        ),

      ),

      child: Row(

        children: FollowingSegment.values.map((segment) {

          final selected = this.segment == segment;

          final label = switch (segment) {

            FollowingSegment.personas => 'Personas',

            FollowingSegment.foros => 'Foros',

          };

          return Expanded(

            child: Material(

              color: Colors.transparent,

              child: InkWell(

                onTap: () => onSelected(segment),

                borderRadius: BorderRadius.circular(18),

                child: AnimatedContainer(

                  duration: const Duration(milliseconds: 180),

                  padding: const EdgeInsets.symmetric(vertical: 9),

                  decoration: BoxDecoration(

                    color: selected ? AppColors.burgundy : Colors.transparent,

                    borderRadius: BorderRadius.circular(18),

                  ),

                  child: Text(

                    label,

                    textAlign: TextAlign.center,

                    style: AppTypography.labelSmall(

                      color: selected

                          ? AppColors.textOnDark

                          : AppColors.textSecondary,

                    ).copyWith(

                      fontSize: 11,

                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,

                    ),

                  ),

                ),

              ),

            ),

          );

        }).toList(),

      ),

    );

  }

}

