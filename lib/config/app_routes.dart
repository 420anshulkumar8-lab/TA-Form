import 'package:flutter/material.dart';
import '../models/ta_session.dart';
import '../screens/splash_screen.dart';
import '../screens/home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/month_selection_screen.dart';
import '../screens/ta_form_screen.dart';
import '../screens/pdf_preview_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String monthSelection = '/month-selection';
  static const String taForm = '/ta-form';
  static const String pdfPreview = '/pdf-preview';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        home: (_) => const HomeScreen(),
        profile: (_) => const ProfileScreen(),
        monthSelection: (_) => const MonthSelectionScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case taForm:
        final session = settings.arguments as TaSession;
        return MaterialPageRoute(
          builder: (_) => TaFormScreen(session: session),
          settings: settings,
        );
      case pdfPreview:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            pdfPath: args['pdfPath'] as String,
            title: args['title'] as String? ?? 'TA Form',
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}
