import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/hive_service.dart';
import 'config/app_theme.dart';
import 'config/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait lock
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Init Hive
  await HiveService.init();

  // Load saved theme preference
  final savedTheme = HiveService.isDarkMode;

  runApp(RailwayTaApp(savedDark: savedTheme));
}

class RailwayTaApp extends StatelessWidget {
  final bool savedDark;

  const RailwayTaApp({
    super.key,
    required this.savedDark,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..setInitialTheme(savedDark),
      child: Consumer<AppProvider>(
        builder: (_, provider, __) => MaterialApp(
          title: 'Railway TA Form',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}
