import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'core/app_export.dart';
import 'services/local_database_service.dart';

// Corrected Path
import 'widgets/custom_error_widget.dart';

import 'package:provider/provider.dart';
import 'data/providers/user_profile_provider.dart';
import 'data/providers/activity_provider.dart';

String? firebaseInitError;

/// Attempt to initialize Firebase. Can be called again from the login screen.
Future<bool> retryFirebaseInit() async {
  try {
    if (Firebase.apps.isNotEmpty) {
      // Dart thinks Firebase is initialized, but the native side may be dead
      // after a previous timeout. Probe it to confirm.
      try {
        // Probe the native side — this throws if the platform channel is dead
        FirebaseAuth.instance.currentUser;
        firebaseInitError = null;
        return true;
      } catch (_) {
        // Native side is dead despite Dart thinking it's initialized.
        // Fall through to re-initialize below.
        debugPrint('Firebase native side unresponsive, re-initializing...');
      }
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 12));
    firebaseInitError = null;
    debugPrint('Firebase initialized successfully.');
    return true;
  } catch (e) {
    firebaseInitError = e.toString();
    debugPrint('Firebase initialization failed: $e');
    return false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch synchronous and rendering errors without closing app
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError (guarded): ${details.exceptionAsString()}');
  };

  // Catch asynchronous and platform channel errors without closing app
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher uncaught error (guarded): $error\n$stack');
    return true; // Prevents app termination
  };

  // Don't block app startup indefinitely on Firebase init.
  // If Firebase init hangs/fails on a device, we still render UI and allow retry.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 12));
    firebaseInitError = null;
  } catch (e) {
    firebaseInitError = e.toString();
    debugPrint('Firebase init failed/timeout at startup: $e');
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
        ],
        child: const MyApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint("Startup Error: $error");
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Startup Error:\n$error\n\n$stackTrace",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
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
        // Using a builder to set the text scale factor to 1.0, which prevents
        // the app's font size from changing with the system's font size settings.
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
            child: child!,
          );
        },
        debugShowCheckedModeBanner: false,

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
