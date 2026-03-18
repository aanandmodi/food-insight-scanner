<div align="center">

# 🥗 Food Insight Scanner

### _Scan. Analyze. Eat Smarter._

An AI-powered Flutter application that scans food product barcodes, retrieves real nutritional data from the **Open Food Facts** database, and delivers **personalized health analysis** using **Groq AI** — all tailored to your dietary profile, allergies, and health goals.

<br/>

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.2+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Groq](https://img.shields.io/badge/Groq-AI%20Engine-F55036?style=for-the-badge)](https://groq.com)
[![Open Food Facts](https://img.shields.io/badge/Open%20Food%20Facts-API-green?style=for-the-badge)](https://world.openfoodfacts.org/)
[![License](https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge)](LICENSE)

<br/>

[Features](#-features) · [Architecture](#-architecture) · [App Flow](#-app-flow) · [Screens](#-screens-in-detail) · [Setup](#-getting-started) · [Contributing](#-contributing)

---

</div>

<br/>

## ✨ Features

<table>
<tr>
<td width="50%">

### 📷 Smart Barcode Scanner
Real-time camera scanning with ML Kit, animated reticle overlay, haptic feedback on detection, flash toggle, and manual barcode entry fallback.

### 🤖 AI Nutrition Assistant
Context-aware conversational chatbot powered by **Groq AI (Kimi K2 model)**. Remembers your allergies, diet preferences, and health goals across the conversation.

### 📊 Product Analysis
Detailed nutrition breakdown with visual progress bars for calories, protein, fat, carbs, sugar, sodium, and fiber. Automatic allergen detection against your profile.

### 🥦 Healthy Alternatives
AI-generated healthier product suggestions with health scores, tailored to your dietary profile and goals.

</td>
<td width="50%">

### 🔐 Secure Authentication
Google Sign-In and Anonymous (guest) mode via Firebase Auth. Seamless session persistence across app restarts.

### 👤 Health Profile Onboarding
Multi-step onboarding wizard to capture allergies, dietary preferences (Vegan, Keto, Halal, etc.), and health goals — all used to personalize every AI interaction.

### 📓 Diet Tracker
Daily food intake logging with AI-generated meal plans for tomorrow based on today's consumption and your nutritional targets.

### ☁️ Cloud Sync
Scan history, diet logs, and user profiles synced to Firestore with per-user security rules. Product data cached globally for faster lookups.

</td>
</tr>
</table>

---

## 🏗️ Architecture

### High-Level System Design

```mermaid
graph TB
    subgraph Client["📱 Flutter App"]
        UI["🖥️ Presentation Layer<br/>(10 Screens + Widgets)"]
        SVC["⚙️ Service Layer<br/>(4 Singleton Services)"]
        MDL["📦 Models & Routes"]
    end
    
    subgraph External["☁️ External Services"]
        FA["🔐 Firebase Auth<br/>Google Sign-In + Anonymous"]
        FS["🗄️ Cloud Firestore<br/>User Data + Scan History"]
        OFF["🌍 Open Food Facts<br/>Product Database"]
        GROQ["🤖 Groq API<br/>Kimi K2 Instruct"]
    end
    
    subgraph Local["💾 Local Storage"]
        SP["SharedPreferences<br/>Profile Cache + Scan History"]
    end
    
    UI --> SVC
    SVC --> MDL
    SVC --> FA
    SVC --> FS
    SVC --> OFF
    SVC --> GROQ
    SVC --> SP
    
    style Client fill:#E3F2FD,stroke:#1565C0,stroke-width:2px
    style External fill:#FFF3E0,stroke:#E65100,stroke-width:2px
    style Local fill:#E8F5E9,stroke:#2E7D32,stroke-width:2px
```

### Tech Stack

<table>
<tr><th>Layer</th><th>Technology</th><th>Purpose</th></tr>
<tr><td>🖥️ <b>Framework</b></td><td>Flutter 3.x / Dart 3.2+</td><td>Cross-platform mobile UI</td></tr>
<tr><td>🧠 <b>AI Engine</b></td><td>Groq API (Kimi K2 Instruct)</td><td>Nutrition chat, product analysis, diet plans, alternatives</td></tr>
<tr><td>🌍 <b>Product Data</b></td><td>Open Food Facts API</td><td>Real nutrition data for millions of products (no key needed)</td></tr>
<tr><td>🔐 <b>Authentication</b></td><td>Firebase Auth</td><td>Google Sign-In + Anonymous guest mode</td></tr>
<tr><td>🗄️ <b>Cloud Database</b></td><td>Cloud Firestore</td><td>User profiles, scan history, diet log, product cache</td></tr>
<tr><td>💾 <b>Local Storage</b></td><td>SharedPreferences</td><td>Profile cache, local scan history, onboarding state</td></tr>
<tr><td>📷 <b>Barcode Scanning</b></td><td>mobile_scanner (ML Kit)</td><td>Real-time camera-based barcode detection</td></tr>
<tr><td>🎨 <b>UI Framework</b></td><td>Material Design 3 + Sizer</td><td>Responsive, premium UI with custom theming</td></tr>
<tr><td>🔄 <b>State Management</b></td><td>Provider + GetIt</td><td>Dependency injection & reactive state</td></tr>
<tr><td>🔤 <b>Typography</b></td><td>Google Fonts</td><td>Premium font rendering</td></tr>
</table>

### Service Layer Architecture

Each service is a **singleton** (factory pattern) ensuring a single instance throughout the app lifecycle:

```mermaid
classDiagram
    class AuthService {
        -FirebaseAuth _firebaseAuth
        -GoogleSignIn _googleSignIn
        +Stream~User~ authStateChanges
        +User? currentUser
        +signInWithGoogle() Future~User?~
        +signInAnonymously() Future~User?~
        +signOut() Future~void~
    }
    
    class FirestoreService {
        -FirebaseFirestore _firestore
        -FirebaseAuth _auth
        +saveUserProfile(Map profile)
        +getUserProfile() Future~Map?~
        +saveScan(Map productData)
        +getScanHistory() Future~List~
        +saveDietEntry(Map entry)
        +getDietLog(String date) Future~List~
        +cacheProduct(String barcode, Map data)
        +getCachedProduct(String barcode) Future~Map?~
    }
    
    class GroqService {
        -String? _apiKey
        -bool _isInitialized
        +initialize() Future~void~
        +generateResponse(String msg) Future~String~
        +generateQuickReplies() Future~List~
        +analyzeProduct(Map product) Future~String~
        +getHealthyAlternatives(Map product) Future~List~
        +generateDietPlan(Map summary) Future~Map~
    }
    
    class ProductService {
        +getProductByBarcode(String code) Future~Map?~
        +saveToScanHistory(Map product)
        +getScanHistory() Future~List~
    }
    
    AuthService --> FirestoreService : authenticates
    ProductService --> GroqService : AI analysis
    FirestoreService --> GroqService : user context
```

---

## 🔄 App Flow

### Complete User Journey

```mermaid
flowchart TD
    A["🚀 App Launch"] --> B["main.dart<br/>Init Firebase + Load env.json"]
    B --> C["✨ SplashScreen<br/>Animated gradient + logo<br/>4-step initialization"]
    
    C --> C1["Step 1: Check services"]
    C1 --> C2["Step 2: Authenticate"]
    C2 --> C3["Step 3: Load profile"]
    C3 --> C4["Step 4: Init ML Kit"]
    C4 --> D{"🔒 AuthGate<br/>User logged in?"}
    
    D -- "❌ No" --> E["🔑 LoginScreen<br/>Google Sign-In<br/>or Guest Mode"]
    D -- "✅ Yes" --> F{"📋 Profile exists?"}
    
    E --> |"Auth success"| F
    F -- "❌ No" --> G["👤 ProfileSetup<br/>Multi-step wizard"]
    F -- "✅ Yes" --> H["🏠 HomeDashboard"]
    G --> |"Profile saved"| H
    
    H --> I["📷 Scan"]
    H --> J["🤖 AI Chat"]
    H --> K["📜 History"]
    H --> L["📓 Diet Log"]
    H --> M["👤 Profile"]
    
    I --> N["BarcodeScanner<br/>Camera + Manual Input"]
    N --> |"Barcode found"| O["Open Food Facts API<br/>Fetch product data"]
    O --> |"Product found"| P["ProductDetails<br/>Nutrition + Ingredients<br/>+ Allergen Alerts"]
    O --> |"Not found"| N2["Error overlay<br/>Try again / Manual input"]
    
    P --> Q["🤖 GroqService<br/>AI Product Analysis"]
    P --> R["🥦 GroqService<br/>Healthy Alternatives"]
    P --> S["💾 Save to Firestore<br/>+ Local History"]
    
    J --> T["AiChatAssistant<br/>Context-aware chat"]
    T --> |"Sends profile + history"| U["Groq API<br/>Kimi K2 Model"]
    U --> |"Markdown response"| T
    
    L --> V["DietLogScreen<br/>Daily intake tracking"]
    V --> W["🤖 GroqService<br/>Tomorrow's meal plan"]

    style A fill:#4CAF50,color:#fff,stroke:#2E7D32
    style H fill:#2196F3,color:#fff,stroke:#1565C0
    style Q fill:#FF5722,color:#fff,stroke:#D84315
    style R fill:#FF5722,color:#fff,stroke:#D84315
    style U fill:#FF5722,color:#fff,stroke:#D84315
    style W fill:#FF5722,color:#fff,stroke:#D84315
    style E fill:#FFC107,color:#000,stroke:#FF8F00
    style G fill:#9C27B0,color:#fff,stroke:#6A1B9A
```

### Barcode Scanning Flow

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant BS as 📷 BarcodeScanner
    participant PS as 🔍 ProductService
    participant OFF as 🌍 Open Food Facts
    participant FS as 🗄️ Firestore
    participant GS as 🤖 GroqService
    participant PD as 📊 ProductDetails

    U->>BS: "Opens scanner"
    BS->>BS: "Request camera permission"
    BS->>BS: "Initialize ML Kit"
    
    alt Camera Scan
        U->>BS: "Points camera at barcode"
        BS->>BS: "Barcode detected ✅"
        BS->>BS: "Haptic feedback + Success flash"
    else Manual Input
        U->>BS: "Types barcode manually"
    end
    
    BS->>PS: "getProductByBarcode(code)"
    PS->>OFF: "GET /api/v2/product/{code}.json"
    OFF-->>PS: "Product data (nutrition, ingredients, allergens)"
    PS->>PS: "Parse & normalize data"
    PS->>FS: "cacheProduct(barcode, data)"
    PS->>PS: "saveToScanHistory(product)"
    PS-->>BS: "Return product map"
    
    BS->>PD: "Navigate with product data"
    PD->>GS: "analyzeProduct(product, userProfile)"
    GS-->>PD: "AI health analysis"
    PD->>GS: "getHealthyAlternatives(product)"
    GS-->>PD: "Alternative suggestions"
    PD-->>U: "Display full product view"
```

### AI Chat Flow

```mermaid
sequenceDiagram
    participant U as 👤 User
    participant AC as 🤖 AiChatAssistant
    participant GS as GroqService
    participant API as "Groq API (Kimi K2)"

    U->>AC: "Opens AI Chat"
    AC->>AC: "Load user profile from args"
    AC->>GS: "generateQuickReplies(lastMsg, profile)"
    GS->>API: "POST /chat/completions"
    API-->>GS: "4 quick reply suggestions"
    GS-->>AC: "Display quick replies"
    
    U->>AC: "Sends message or taps quick reply"
    AC->>AC: "Show typing indicator"
    AC->>GS: "generateResponse(msg, history, profile)"
    
    Note over GS,API: System prompt includes user's name, allergies, diet, goals
    
    GS->>API: "POST /chat/completions with full conversation history"
    API-->>GS: "Markdown response"
    GS-->>AC: "Return AI response"
    AC->>AC: "Render markdown bubble"
    AC->>GS: "generateQuickReplies(response)"
    GS-->>AC: "Update quick replies"
    AC-->>U: "Display response + new suggestions"
```

---

## 📱 Screens in Detail

<table>
<tr>
<th width="20%">Screen</th>
<th width="40%">Description</th>
<th width="40%">Key Widgets</th>
</tr>

<tr>
<td><b>✨ Splash Screen</b></td>
<td>Animated brand intro with gradient background, elastic logo animation, 4-step loading progress with glassmorphism container, auto-retry on connection failure</td>
<td><code>AnimatedBuilder</code>, <code>LinearGradient</code>, <code>CircularProgressIndicator</code>, <code>AnimatedSwitcher</code></td>
</tr>

<tr>
<td><b>🔑 Login Screen</b></td>
<td>Google Sign-In button with branded styling, anonymous "Continue as Guest" option, Firebase Auth integration</td>
<td><code>GoogleSignIn</code>, <code>FirebaseAuth</code></td>
</tr>

<tr>
<td><b>👤 Profile Setup</b></td>
<td>Multi-step onboarding wizard: <b>Step 1</b> — Allergy selection, <b>Step 2</b> — Dietary preferences, <b>Step 3</b> — Health goal dropdown. Saves to SharedPreferences + Firestore</td>
<td><code>AllergySelectionWidget</code>, <code>DietaryPreferencesWidget</code>, <code>HealthGoalDropdownWidget</code>, <code>ProgressIndicatorWidget</code></td>
</tr>

<tr>
<td><b>🏠 Home Dashboard</b></td>
<td>Main hub with personalized greeting, nutrition summary donut card, quick action buttons (Scan/Chat/History), recent scans with safety indicators (safe/warning/danger), diet log preview</td>
<td><code>GreetingHeader</code>, <code>NutritionSummaryCard</code>, <code>QuickActionsSection</code>, <code>RecentScansSection</code>, <code>DietLogPreview</code></td>
</tr>

<tr>
<td><b>📷 Barcode Scanner</b></td>
<td>Full-screen camera with animated scanning reticle, flash toggle, haptic feedback on detection, success flash animation, manual barcode input fallback, error overlays with retry</td>
<td><code>MobileScanner</code>, <code>CameraOverlayWidget</code>, <code>ScanningAnimationWidget</code>, <code>SuccessFlashWidget</code>, <code>ManualInputWidget</code>, <code>ErrorMessageWidget</code></td>
</tr>

<tr>
<td><b>📊 Product Details</b></td>
<td>Product image with fallback, brand/name/category info, visual nutrition bars, full ingredient list, allergen safety alerts (matched against profile), AI health analysis, healthy alternatives carousel</td>
<td><code>ProductImageWidget</code>, <code>ProductInfoWidget</code>, <code>NutritionBarsWidget</code>, <code>IngredientsWidget</code>, <code>SafetyAlertsWidget</code>, <code>AlternativesWidget</code>, <code>ActionBarWidget</code></td>
</tr>

<tr>
<td><b>🤖 AI Chat</b></td>
<td>Conversational nutrition assistant. Profile-aware system prompt, markdown-rendered responses, typing indicator, dynamic quick-reply suggestions, full conversation history</td>
<td><code>ChatHeaderWidget</code>, <code>ChatInputWidget</code>, <code>MessageBubbleWidget</code>, <code>QuickReplyWidget</code>, <code>TypingIndicatorWidget</code></td>
</tr>

<tr>
<td><b>📜 Scan History</b></td>
<td>Scrollable list of previously scanned products with images, timestamps, and re-scan capability. Synced to Firestore</td>
<td><code>ScanHistoryScreen</code></td>
</tr>

<tr>
<td><b>📓 Diet Log</b></td>
<td>Daily food intake tracker with date-based filtering. AI-generated meal plan for tomorrow based on today's intake</td>
<td><code>DietLogScreen</code></td>
</tr>

<tr>
<td><b>👤 Profile</b></td>
<td>View and edit user profile settings — allergies, dietary preferences, health goals. Sign-out functionality</td>
<td><code>ProfileScreen</code></td>
</tr>
</table>

---

## 🔥 Firestore Data Model

```mermaid
erDiagram
    USERS {
        string uid PK "Firebase Auth UID"
        string name "Display name"
        array allergies "e.g. [peanuts, gluten]"
        string dietaryPreferences "e.g. Vegan, Keto"
        string healthGoals "e.g. weight loss"
        int age
        string activityLevel
        timestamp updatedAt
    }
    
    PRODUCTS {
        string barcode PK "EAN/UPC code"
        string name "Product name"
        string brand "Brand name"
        string category "Food category"
        string image "Image URL"
        map nutrition "calories, protein, fat, sugar..."
        array ingredients "Ingredient list"
        array allergens "Detected allergens"
        string servingSize "e.g. Per 100g"
        string nutriscore "Nutri-Score grade"
        int novaGroup "NOVA processing group"
        timestamp lastUpdated
    }
    
    SCAN_HISTORY {
        string scanId PK "Auto-generated"
        string barcode FK "Product barcode"
        string name "Product name"
        string image "Product image"
        map nutrition "Nutrition snapshot"
        array allergens "Allergens at scan time"
        timestamp scannedAt
    }
    
    DIET_LOG {
        string entryId PK "Auto-generated"
        string date "YYYY-MM-DD for filtering"
        string mealType "Breakfast/Lunch/Dinner/Snack"
        string name "Food item name"
        map nutritionData "Calories, protein, etc."
        timestamp createdAt
    }
    
    USERS ||--o{ SCAN_HISTORY : "users/{uid}/scan_history"
    USERS ||--o{ DIET_LOG : "users/{uid}/diet_log"
    SCAN_HISTORY }o--|| PRODUCTS : "references by barcode"
```

### Firestore Collections

| Collection | Path | Description | Access Rule |
|---|---|---|---|
| **Users** | `users/{userId}` | User profiles with health data | Owner read/write only |
| **Products** | `products/{barcode}` | Cached product data (shared) | Authenticated read/write |
| **Scan History** | `scan_history/{userId}/scans/{scanId}` | Per-user scan records | Owner read/write only |
| **Diet Log** | `diet_log/{userId}/entries/{entryId}` | Per-user daily intake | Owner read/write only |

### Security Rules

```
users/{userId}       → read/write if auth.uid == userId
products/{productId} → read/write if authenticated
scan_history/{uid}/* → read/write if auth.uid == uid
```

---

## 📁 Project Structure

```
food_insight_scanner/
│
├── lib/
│   ├── main.dart                               # 🚀 Entry point — Firebase init, env loading, error handling
│   ├── firebase_options.dart                    # 🔐 Firebase config (⚠️ gitignored — auto-generated)
│   │
│   ├── core/
│   │   ├── app_export.dart                      # 📦 Barrel file — re-exports core utilities
│   │   ├── auth_gate.dart                       # 🔒 StreamBuilder for auth state → Login ↔ Home
│   │   └── services/
│   │       ├── auth_service.dart                # 🔐 Google Sign-In + Anonymous auth
│   │       ├── firestore_service.dart           # 🗄️ CRUD: profiles, scans, diet log, product cache
│   │       ├── groq_service.dart                # 🤖 AI: chat, analysis, alternatives, diet plans
│   │       └── product_service.dart             # 🌍 Open Food Facts API + local scan history
│   │
│   ├── models/
│   │   └── user_profile.dart                    # 📋 UserProfile class with fromMap/toMap
│   │
│   ├── presentation/
│   │   ├── splash_screen/
│   │   │   └── splash_screen.dart               # ✨ Animated splash with 4-step init
│   │   ├── auth/
│   │   │   └── login_screen.dart                # 🔑 Google + Guest login
│   │   ├── profile_setup/
│   │   │   ├── profile_setup.dart               # 👤 Multi-step onboarding wizard
│   │   │   └── widgets/                         # (4 step widgets)
│   │   ├── home_dashboard/
│   │   │   ├── home_dashboard.dart              # 🏠 Main hub with bottom nav
│   │   │   └── widgets/                         # (5 section widgets)
│   │   ├── barcode_scanner/
│   │   │   ├── barcode_scanner.dart             # 📷 Camera scanner + manual input
│   │   │   └── widgets/                         # (5 overlay widgets)
│   │   ├── product_details/
│   │   │   ├── product_details.dart             # 📊 Full product analysis view
│   │   │   └── widgets/                         # (7 detail widgets)
│   │   ├── ai_chat_assistant/
│   │   │   ├── ai_chat_assistant.dart           # 🤖 Conversational AI chat
│   │   │   └── widgets/                         # (5 chat widgets)
│   │   ├── scan_history/
│   │   │   └── scan_history_screen.dart         # 📜 Past scans browser
│   │   ├── diet_log/
│   │   │   └── diet_log_screen.dart             # 📓 Daily intake tracker
│   │   └── profile/
│   │       └── profile_screen.dart              # 👤 Profile view/edit
│   │
│   ├── routes/
│   │   └── app_routes.dart                      # 🗺️ Named routes + onGenerateRoute
│   │
│   ├── theme/
│   │   └── app_theme.dart                       # 🎨 Material 3 light/dark themes
│   │
│   └── widgets/                                 # 🧩 Shared reusable widgets
│       ├── custom_error_widget.dart
│       ├── custom_icon_widget.dart
│       └── custom_image_widget.dart
│
├── assets/
│   ├── env.json                                 # 🔐 API keys (⚠️ gitignored)
│   └── images/
│       ├── img_app_logo.svg                     # App logo
│       ├── no-image.jpg                         # Product image fallback
│       └── sad_face.svg                         # Error state illustration
│
├── android/                                     # 📱 Android platform config
├── ios/                                         # 🍎 iOS platform config
├── firestore.rules                              # 🔒 Firestore security rules
├── firestore.indexes.json                       # 📇 Firestore composite indexes
├── env.json.example                             # 📄 Template for environment variables
├── pubspec.yaml                                 # 📦 Flutter dependencies
├── analysis_options.yaml                        # 🔍 Dart analyzer config
├── LICENSE                                      # ⚖️ MIT License
└── .gitignore                                   # 🚫 Git exclusions
```

> **📊 Stats:** 36 Dart source files • 10 screens • 26 widgets • 4 services • 1 model

---

## 🚀 Getting Started

### Prerequisites

| Requirement | Version | Link |
|---|---|---|
| Flutter SDK | ≥ 3.2.3 | [Install Flutter](https://docs.flutter.dev/get-started/install) |
| Dart SDK | ≥ 3.2.3 | Included with Flutter |
| Android Studio / VS Code | Latest | [Android Studio](https://developer.android.com/studio) |
| Firebase Project | — | [Firebase Console](https://console.firebase.google.com/) |
| Groq API Key | Free | [console.groq.com](https://console.groq.com/) |

### Step 1 → Clone

```bash
git clone https://github.com/aanandmodi/food-insight-scanner.git
cd food-insight-scanner
```

### Step 2 → Configure Environment

```bash
# Copy the template
cp env.json.example env.json
cp env.json.example assets/env.json
```

Edit both `env.json` files with your keys:

```json
{
    "GROQ_API_KEY": "your_groq_api_key_here"
}
```

> 💡 Only `GROQ_API_KEY` is required. Other keys are placeholders for future features.

### Step 3 → Set Up Firebase

```bash
# 1. Install FlutterFire CLI
dart pub global activate flutterfire_cli

# 2. Generate Firebase config (creates lib/firebase_options.dart)
flutterfire configure

# 3. Deploy Firestore security rules
firebase deploy --only firestore:rules
```

Enable in Firebase Console:
- **Authentication** → Sign-in method → ✅ Google, ✅ Anonymous
- **Cloud Firestore** → Create database → Production mode

### Step 4 → Install & Run

```bash
# Get dependencies
flutter pub get

# Run on device / emulator
flutter run
```

### Step 5 → (Optional) Custom App Icon

```bash
flutter pub run flutter_launcher_icons
```

---

## 🔐 Security

| Security Measure | Status | Details |
|---|---|---|
| API keys at runtime | ✅ | Loaded from `assets/env.json` (gitignored) |
| Firebase config | ✅ | `firebase_options.dart` is gitignored |
| Google Services | ✅ | `google-services.json` is gitignored |
| Firestore rules | ✅ | Per-user read/write enforcement |
| Auth required | ✅ | All DB operations require authentication |
| Template provided | ✅ | `env.json.example` for easy onboarding |

---

## 📦 Dependencies

<table>
<tr><th>Package</th><th>Version</th><th>Purpose</th></tr>
<tr><td><code>firebase_core</code></td><td>^3.1.1</td><td>Firebase initialization</td></tr>
<tr><td><code>firebase_auth</code></td><td>^5.1.1</td><td>Authentication (Google + Anonymous)</td></tr>
<tr><td><code>cloud_firestore</code></td><td>^5.0.2</td><td>Cloud database for user data</td></tr>
<tr><td><code>google_sign_in</code></td><td>^6.2.1</td><td>Google OAuth flow</td></tr>
<tr><td><code>mobile_scanner</code></td><td>^5.1.1</td><td>Camera-based barcode/QR scanning</td></tr>
<tr><td><code>http</code></td><td>^1.2.1</td><td>REST API calls (Groq + Open Food Facts)</td></tr>
<tr><td><code>provider</code></td><td>^6.1.2</td><td>State management</td></tr>
<tr><td><code>get_it</code></td><td>^7.7.0</td><td>Service locator / dependency injection</td></tr>
<tr><td><code>shared_preferences</code></td><td>^2.2.3</td><td>Local key-value cache</td></tr>
<tr><td><code>sizer</code></td><td>^2.0.15</td><td>Responsive UI sizing</td></tr>
<tr><td><code>google_fonts</code></td><td>^6.2.1</td><td>Premium Google Fonts typography</td></tr>
<tr><td><code>flutter_markdown</code></td><td>^0.7.1</td><td>Render AI chat responses as Markdown</td></tr>
<tr><td><code>cached_network_image</code></td><td>^3.3.1</td><td>Image caching with placeholders</td></tr>
<tr><td><code>connectivity_plus</code></td><td>^6.0.3</td><td>Network connectivity detection</td></tr>
<tr><td><code>permission_handler</code></td><td>^11.3.1</td><td>Camera & storage permission requests</td></tr>
<tr><td><code>fluttertoast</code></td><td>^9.0.0</td><td>Native toast notifications</td></tr>
<tr><td><code>flutter_svg</code></td><td>^2.0.10+1</td><td>SVG asset rendering</td></tr>
<tr><td><code>intl</code></td><td>^0.20.2</td><td>Date/number internationalization</td></tr>
<tr><td><code>record</code></td><td>^6.0.0</td><td>Audio recording (future feature)</td></tr>
</table>

---

## 🤝 Contributing

Contributions are welcome! Here's how:

1. **Fork** this repository
2. **Create** a feature branch → `git checkout -b feature/my-feature`
3. **Commit** your changes → `git commit -m "Add my feature"`
4. **Push** to the branch → `git push origin feature/my-feature`
5. **Open** a Pull Request

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

| Resource | Description |
|----------|------------|
| [Open Food Facts](https://world.openfoodfacts.org/) | Free, open-source food product database |
| [Groq](https://groq.com/) | Ultra-fast AI inference platform |
| [Firebase](https://firebase.google.com/) | Authentication, database, and hosting |
| [Flutter](https://flutter.dev/) | Google's cross-platform UI framework |
| [ML Kit](https://developers.google.com/ml-kit) | On-device machine learning for scanning |

---

<div align="center">

**Built with ❤️ using Flutter & AI**

⭐ Star this repo if you find it useful!

</div>
