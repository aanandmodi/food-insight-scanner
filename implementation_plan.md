# Widget Expansion & Skeuomorphism Implementation Plan

The goal is to elevate the Android Home Screen widgets by adding premium **skeuomorphic design elements** (shadows, gradients, and depth) to perfectly match the app's internal "Apple Health" aesthetic. Furthermore, we will introduce **3 distinct widget sizes/types**, making the home screen experience fully dynamic and customizable.

## User Review Required

> [!IMPORTANT]  
> Please review the 3 proposed widget sizes and features below. Let me know if you want to swap any of these out for different features (e.g., a widget specifically for water intake, or latest scanned item).

## Proposed New Widgets

### 1. Small Widget (2x2) - "Quick Calorie Ring"
- **Purpose:** A compact, minimalist widget for users who just want to glance at their primary calorie goal.
- **Design:** Features a single, large skeuomorphic activity ring (using the Apple-style crimson gradient) with the consumed KCAL in the center. The background will be a raised, frosted-glass style card.

### 2. Medium Widget (4x2) - "Daily Summary" (Upgrading Current Widget)
- **Purpose:** The standard macro tracker.
- **Design Upgrades:** 
  - Convert the flat background into a **skeuomorphic raised card** using XML `<layer-list>` drop shadows.
  - Add **inset shadows** to the horizontal progress bars (Carbs, Protein, Fat) so they look like physical grooves cut into the card.
  - Add a **subtle gradient** to the "Goal" pill background with a soft drop shadow.
  - Implement responsive `layout_weight` constraints so it scales perfectly if the user resizes it slightly on their launcher.

### 3. Large Widget (4x4) - "Full Health Dashboard"
- **Purpose:** A comprehensive hub that not only shows macros but provides interactive quick-actions.
- **Features:**
  - Includes the Calorie Ring and all 3 Macro bars.
  - Includes **"Quick Action" buttons** natively on the widget (e.g., "Scan Food", "Log Meal"). Tapping these will use an Android `PendingIntent` to launch the app directly into those specific screens.

## Technical Implementation Details

### Native Android Updates
To achieve skeuomorphism in Android's restricted `RemoteViews` (which don't support Flutter's advanced shadow rendering or `BackdropFilter`), we will hand-craft XML drawables:

1. **Drop Shadows:** Create new XML drawables using `<layer-list>` that stack a semi-transparent gray shape offset by a few DP underneath the main white/cream background shape.
2. **Gradients:** Replace solid colors in the progress bars with `<gradient>` tags matching the app's `app_design_system.dart`.
3. **Widget Providers:** 
   - We will create 2 new `AppWidgetProvider` Kotlin classes (e.g., `SmallWidgetProvider.kt`, `LargeWidgetProvider.kt`) alongside the existing one.
   - We will register 3 distinct `<receiver>` entries in `AndroidManifest.xml`.
   - We will create 3 distinct `xml/widget_info_small.xml`, `xml/widget_info_medium.xml`, etc., to define their grid sizes.

## Verification Plan
1. Compile the Android app (`flutter build apk`).
2. Verify no XML parsing errors or layout inflation crashes.
3. You will be able to long-press your Android home screen and see **3 different Food Insight widgets** in the picker menu. You can drag them all onto your screen and resize them to see the responsive, skeuomorphic designs!
