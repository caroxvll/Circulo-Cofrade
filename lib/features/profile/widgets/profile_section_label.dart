import 'package:flutter/material.dart';

import '../profile_design.dart';

class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(), style: ProfileDesign.filterSectionLabel());
  }
}
