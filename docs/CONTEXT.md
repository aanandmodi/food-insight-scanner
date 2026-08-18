# 🥗 Food Insight Scanner | Context & Architecture Guide

This document is designed to provide comprehensive context, architectural patterns, UI/UX guidelines, and feature breakdowns for AI assistants or new developers working on this codebase. 

---

## 📌 Project Overview
**Food Insight** is an AI-powered dietary companion built with **Flutter (Frontend)** and **Firebase (Backend)**. It allows users to scan food barcodes, log meals, track macro/micro-nutrients, and converse with a context-aware AI dietary assistant.

- **Primary AI Engine:** Groq API (`llama-3.3-70b-versatile` & `llama-3.1-8b-instant`) accessed via direct HTTP (migrated away from Cloud Functions).
- **Product Database:** Open Food Facts (OFF) REST APIs.
- **Platforms:** Android & iOS (Targeting Android SDK 36).

---

## 🏛️ High-Level Architecture & Logic

### 1. Presentation & State Management Layer
The app follows a **Provider + GetIt** architecture:
- **`GetIt`:** Used as a service locator for singletons (`AuthService`, `DatabaseService`, `GroqService`).
- **`Provider` (`ChangeNotifier`):** Manages reactive state across widget trees (e.g., `UserProfileProvider`, `MealLogProvider`).
- **Routing:** Centralized in `app_routes.dart`. It utilizes a robust `AuthGate` that checks 1) Firebase Auth status, and 2) Firestore Profile Completion, ensuring users never see the dashboard unless fully configured. Custom cinematic page transitions (fade + slide) are applied globally.

### 2. Service Layer
- **`GroqService`:** Handles AI prompting for dietary advice, ingredient risk analysis, and macro extraction from text. 
- **`OffService`:** Interfaces with Open Food Facts to fetch barcode data.
- **`DatabaseService`:** Wraps `cloud_firestore` for user profiles, scan history, and diet logs.
- **`OfflineStorage`:** `sqflite` and `shared_preferences` are used to cache product details and support graceful degradation when offline.

### 3. Native Integrations
- **Android Home Widget:** A native Android widget built with Kotlin (`MacroWidgetProvider.kt`) and XML. It relies on the `home_widget` package, syncing user macro goals and consumption from `home_dashboard.dart` to native Android `SharedPreferences`.

---

## 🎨 UI, Style, and Design System

The app utilizes a highly specific **"Warm Apple Health / Skeuomorphic"** design system defined in `app_design_system.dart`. 

### Key Visual Tokens:
1. **Color Palette:** 
   - Backgrounds: Warm White (`#FAF8F4`) and Matte Cream (`#F2EDE4`).
   - Accents: Scanner Green (`#34C759`), Health Red (`#FFFF3B30`), Carbs Blue, Fat Yellow.
2. **Typography:**
   - `Nunito` for primary display, headings, and body.
   - `JetBrains Mono` for monospace / data visualization.
3. **Shadows & Depth (Skeuomorphism):**
   - Extensive use of multi-layered drop shadows (`FoodInsightShadows.raisedCard`, `.pressed`, `.inset`) to simulate physical layers.
4. **Performance Consideration:**
   - Expensive Apple-style `BackdropFilter` (blur effects) were recently **removed** to maximize scrolling smoothness and FPS on low-end Android devices. High-opacity colors (e.g., `Colors.white.withValues(alpha: 0.95)`) are used instead of blurs.

---

## 🚀 Core Features

1. **Barcode Scanner (`mobile_scanner`):** Real-time ML-Kit based scanner with a custom skeuomorphic reticle and neon glow overlays.
2. **Product Details:** Parses Nutri-Score, Eco-Score, and flags allergens based on the user's stored health profile.
3. **Daily Diet Log & Meal Planner:** Allows users to log food manually or via AI NLP parsing. Calculates dynamically updating TDEE, protein targets, and sugar limits using the Mifflin-St Jeor Equation.
4. **AI Chat Assistant:** Context-aware chat using Groq. The system prompt dynamically injects the user's allergies, goals, and recent meals into the LLM context.
5. **Android Home Screen Widget:** Displays real-time progress bars for Calories, Protein, Carbs, and Fat natively on the Android launcher.

---

## 📁 Repository Structure (`frontend/lib`)

- `core/`: Constants, utilities, environment configs, and the `AuthGate`.
- `data/`: 
  - `models/`: Dart data classes (User, Product, ScanLog).
  - `providers/`: State management for UI binding.
  - `services/`: API clients (Firebase, Groq, OFF).
- `presentation/`: Screen-level UI widgets, categorized by feature (e.g., `auth/`, `home_dashboard/`, `ai_chat_assistant/`).
- `routes/`: Centralized routing and transition logic.
- `theme/`: `app_design_system.dart` containing all colors, shadows, and fonts.
- `widgets/`: Reusable, generic UI components (e.g., `GlassCard`, `FrostedGlassPanel`).

---

## ⚠️ Important Developer Notes

1. **Dependencies:** `home_widget` is used for Android native UI sync. `mobile_scanner` is used for camera access.
2. **API Keys:** Groq API keys are handled via environment variables/HTTP direct calls (legacy Cloud Functions were dropped).
3. **Optimized Builds:** Always build using `--split-per-abi --obfuscate --split-debug-info` to maintain small APK sizes.
4. **No Blurs:** Do not introduce `BackdropFilter` as it drastically reduces app performance. Use opaque/semi-opaque colors instead.
