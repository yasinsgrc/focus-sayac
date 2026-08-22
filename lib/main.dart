import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/storage/app_database.dart';
import 'services/storage/exam_source_service.dart';
import 'services/storage/storage_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ekran 02/08/11'in Türkçe tarih biçimleri (`DateFormat('d MMMM y', 'tr')`)
  // için gerekli — olmadan 'tr' locale verisi eksik hatası fırlatır.
  await initializeDateFormatting('tr_TR');
  final AppDatabase database = AppDatabase();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  // SPEC.md §4: uzak override sessizce dener, hata/URL boşsa yerel seed
  // korunur — açılışı bloklamadan arka planda tetiklenir.
  unawaited(
    ExamSourceService(database: database, prefs: prefs).syncIfNeeded(),
  );
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FocusSayacApp(),
    ),
  );
}

class FocusSayacApp extends ConsumerWidget {
  const FocusSayacApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'FocusSayaç',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
