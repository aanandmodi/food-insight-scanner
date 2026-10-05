import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'services/firebase_bootstrap.dart';
import 'services/user_session.dart';
import 'services/crash_reporting_service.dart';
import 'services/analytics_service.dart';
import 'services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'routes/tap_origin.dart';
import 'core/utils/qa_frame_metrics.dart';
import 'package:sizer/sizer.dart';
import 'core/app_export.dart';
import 'services/local_database_service.dart';

// Corrected Path
import 'widgets/custom_error_widget.dart';

import 'package:provider/provider.dart';
import 'data/providers/user_profile_provider.dart';
import 'data/providers/activity_provider.dart';

Future<bool> retryFirebaseInit() => FirebaseBootstrap.ensureReady();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('QA_BUILD')) {
    final output = debugPrint;
    installQaFrameMetrics((message) => output(message));
  }
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};

  // Catch synchronous and rendering errors without closing app
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!kReleaseMode) FlutterError.presentError(details);
    CrashReportingService.record(details.exception, details.stack, fatal: true);
  };

  // Catch asynchronous and platform channel errors without closing app
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReportingService.record(error, stack, fatal: true);
    return true; // Prevents app termination
  };

  UserSession.instance;
  if (await FirebaseBootstrap.ensureReady()) {
    try {
      await CrashReportingService.initialize();
      await AnalyticsService.initialize();
    } catch (_) {}
  }
  final preferences = await SharedPreferences.getInstance();
  for (final key in preferences
      .getKeys()
      .where((key) => key.endsWith('groq_api_key'))
      .toList()) {
    await preferences.remove(key);
  }

  try {
    // Initialize local SQLite database for offline persistence
    try {
      await LocalDatabaseService().initialize();
      debugPrint('Local database initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing local database: $e');
    }

    // Supabase Storage is lazy-initialized on first upload to avoid
    // conflicting with Firebase's activity handlers at startup.

    // It's better to manage this state within a state management solution
    // to avoid global variables.
    bool hasShownError = false;

    // Set a custom error widget builder to show a user-friendly error screen.
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // This logic prevents showing multiple error screens at once.
      if (!hasShownError) {
        hasShownError = true;
        Future.delayed(const Duration(seconds: 5), () {
          hasShownError = false;
        });
        return CustomErrorWidget(errorDetails: details);
      }
      return const SizedBox.shrink();
    };

    // Set preferred screen orientations.
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Run the app.
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserProfileProvider()),
          ChangeNotifierProvider(create: (_) => ActivityProvider()),
          ChangeNotifierProvider(create: (_) => FeatureFlagService()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (error, stackTrace) {
    CrashReportingService.record(error, stackTrace, fatal: true);
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "Food Insight could not start. Close the app and try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Sizer is used for responsive UI design.
    return Sizer(builder: (context, orientation, screenType) {
      return MaterialApp(
        title: 'Food Insight',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => Listener(
          onPointerDown: (event) =>
              TapOrigin.record(event.position, MediaQuery.sizeOf(context)),
          child: child!,
        ),

        // The initial route is now the splash screen.
        initialRoute: AppRoutes.splash,

        // AppRoutes defines the named routes for the app.
        routes: AppRoutes.routes,

        // onGenerateRoute for routes that need dynamic arguments.
        onGenerateRoute: AppRoutes.onGenerateRoute,
      );
    });
  }
}
