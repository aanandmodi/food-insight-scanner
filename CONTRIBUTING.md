# Contributing to NutriScan AI — Food Insight Scanner

Thank you for your interest in contributing! This guide will help you get started.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x+)
- [Node.js](https://nodejs.org/) (18+) for backend Cloud Functions
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- Android Studio or VS Code with Flutter extension
- A Firebase project on the Blaze plan (for Cloud Functions deployment)

### Setup
```bash
# 1. Clone the repository
git clone https://github.com/aanandmodi/food-insight-scanner.git
cd food-insight-scanner

# 2. Frontend setup
cd frontend
flutter pub get
flutter run

# 3. Backend setup (in a separate terminal)
cd backend
npm install
npx tsc --noEmit          # Verify TypeScript compiles
firebase deploy --only functions  # Deploy (requires Blaze plan)
```

### Firebase Configuration
You will need to add your own Firebase configuration files (not tracked in git):
- `frontend/android/app/google-services.json`
- `frontend/lib/firebase_options.dart`

Generate these via `flutterfire configure` or download from the Firebase Console.

---

## 📁 Project Structure

```
food-insight-scanner/
├── frontend/          # Flutter mobile app
│   ├── lib/           # Dart source code
│   ├── android/       # Android platform files
│   ├── ios/           # iOS platform files
│   └── pubspec.yaml   # Flutter dependencies
├── backend/           # Firebase Cloud Functions
│   ├── src/           # TypeScript source
│   └── package.json   # Node.js dependencies
├── docs/              # Project documentation
├── firestore.rules    # Firestore security rules
└── firebase.json      # Firebase project config
```

---

## 🔀 Branching Strategy

- `main` — Stable, production-ready code
- `dev` — Active development branch
- `feature/*` — Feature branches (e.g., `feature/push-notifications`)
- `bugfix/*` — Bug fix branches (e.g., `bugfix/auth-timeout`)

### Workflow
1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes
4. Run `flutter analyze` to check for lint issues
5. Build and test: `flutter build apk --debug`
6. Submit a Pull Request with a clear description

---

## 🧪 Testing

```bash
# Run Flutter analyzer
flutter analyze

# Run tests (when available)
flutter test

# Backend type-check
cd backend && npx tsc --noEmit
```

---

## 📝 Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use the project's design system tokens (`FoodInsightColors`, `FoodInsightTypography`, etc.) — don't create ad-hoc colors or text styles
- Use `FoodInsightTypography.body()`, `.heading()`, `.caption()`, `.display()`, `.smallCaps()` for text
- Use `SkeuCard` widget for card containers
- Add `flutter_animate` animations for new UI elements
- Backend functions must use `defineSecret` for API keys

---

## 🐛 Bug Reports

Check [docs/BUGS.md](docs/BUGS.md) for known issues first, then open a GitHub Issue with:
- Steps to reproduce
- Expected vs actual behavior
- Device and OS information
- Relevant error logs

---

## 📜 License

By contributing, you agree that your contributions will be licensed under the project's existing license.
