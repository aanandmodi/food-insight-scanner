// lib/core/auth_gate.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../presentation/auth/login_screen.dart';
import '../presentation/home_dashboard/home_dashboard.dart';
import './services/auth_service.dart';

/// A widget that listens to authentication state changes and shows the
/// appropriate screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to a stream and rebuilds whenever new data arrives.
    return StreamBuilder<User?>(
      // We listen to the authStateChanges stream from our AuthService.
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // 1. If the stream is still waiting for data, show a loading indicator.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If the stream has data (a User object), it means the user is logged in.
        if (snapshot.hasData) {
          // So, we show the main app screen.
          return const HomeDashboard();
        }
        
        // 3. If the stream has no data, the user is logged out.
        // So, we show the login screen.
        return const LoginScreen();
      },
    );
  }
}