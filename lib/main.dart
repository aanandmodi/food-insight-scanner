  // lib/main.dart

import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'core/app_export.dart';
// Corrected Path
import 'widgets/custom_error_widget.dart';

// Using a global variable for environment settings is acceptable for small apps,
// but for larger apps, consider using a dependency injection solution like GetIt or Provider
// to make your environment settings available throughout the app.
// For now, we will keep it but it's a good practice to refactor this later.
Map<String, dynamic> env = {};

String? firebaseInitError;

/// Attempt to initialize Firebase. Can be called again from the login screen.
Future<bool> retryFirebaseInit() async {
  try {
    // If already initialized, just return true
    if (Firebase.apps.isNotEmpty) {
      firebaseInitError = null;
      return true;
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
  try {
    // Ensure that the Flutter binding is initialized before calling any Flutter APIs.
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with retry (up to 3 attempts)
    for (int attempt = 1; attempt <= 3; attempt++) {
      final success = await retryFirebaseInit();
      if (success) break;
      if (attempt < 3) {
        debugPrint('Firebase init attempt $attempt failed, retrying...');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // It's better to manage this state within a state management solution

    // to avoid global variables.
    bool hasShownError = false;

    // Load environment variables from a JSON file.
    try {
      final envString = await rootBundle.loadString('assets/env.json');
      env = jsonDecode(envString);
    } catch (e) {
      debugPrint("Error loading env.json: $e");
      // Continue without env if it fails, or handle appropriately
    }

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
    runApp(const MyApp());
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
        title: 'Food Insight Scanner',
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