import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'core/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await SupabaseBootstrap.initialize();
  await FirebaseBootstrap.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.navBarBackground,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: CofradeoApp(),
    ),
  );
}
