# Home Screen Widgets Research (Flutter)

Implementing Home Screen Widgets in Flutter allows users to view data from the app directly on their Android or iOS home screens without opening the app. For the "Food Insight Scanner", this would be perfect for displaying:
1. Daily Macro Progress (Calories, Protein, Fat, Carbs)
2. Next Planned Meal
3. A quick action button to launch the barcode scanner directly.

## Recommended Package
We will use the **[`home_widget`](https://pub.dev/packages/home_widget)** package. It acts as a bridge between Flutter's `SharedPreferences` and the native widget APIs (Android `AppWidgetProvider` and iOS `WidgetKit`).

## Implementation Strategy

### 1. Flutter Side (Data Sync)
Whenever the user's data updates (e.g., they log a meal or the AI recalibrates their macros), we will save this data to a shared group using `home_widget`:

```dart
import 'package:home_widget/home_widget.dart';

Future<void> updateWidgetData(Map<String, dynamic> macros) async {
  await HomeWidget.saveWidgetData<int>('calories_consumed', macros['calories']);
  await HomeWidget.saveWidgetData<int>('calories_goal', macros['goal']);
  await HomeWidget.updateWidget(name: 'MacroWidgetProvider', iOSName: 'MacroWidget');
}
```

### 2. Android Side (Kotlin/XML)
Android requires writing a small amount of native code.
- **Layout**: Create an XML layout in `android/app/src/main/res/layout/widget_layout.xml` designed to match the app's aesthetic.
- **Provider**: Create a Kotlin class extending `AppWidgetProvider`. It will use `HomeWidgetPlugin.getData` to read the shared preferences and update the `RemoteViews` of the XML layout.

### 3. iOS Side (SwiftUI)
- Add a Widget Extension target in Xcode.
- Create a SwiftUI view that reads the `UserDefaults` group shared by the Flutter app.
- Provide a `TimelineProvider` to dictate when the widget should refresh.

## Actionable Next Steps
To proceed with this feature, we need to:
1. Add `home_widget: ^0.3.0` to `pubspec.yaml`.
2. Decide exactly what information the first widget should show.
3. Design the widget UI in Android XML (and SwiftUI if iOS support is needed).
4. Hook up the `updateWidgetData` function inside the `CloudFunctionService` or `UserProfileProvider` to keep the widget in sync with the app.
