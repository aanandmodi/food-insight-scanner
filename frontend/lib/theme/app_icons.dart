// lib/theme/app_icons.dart
//
// Centralized icon mapping for the entire app.
// Family: Material Symbols Rounded (via Flutter's Icons.*_rounded)
// Weight: Regular (400) — the default for _rounded variants.
//
// Convention:
//   • Every icon uses the `_rounded` suffix for visual consistency.
//   • Navbar icons provide BOTH an outline and a filled variant
//     so the LiquidGlassNavBar can crossfade between them.
//   • All other icons use a single entry (outline/rounded preferred).
//
// To change the icon set app-wide, update the entries here only.

import 'package:flutter/material.dart';

/// Single source of truth for all icons used across the app.
///
/// ┌─────────────────────────────────────────────────────────┐
/// │  MAPPING TABLE  (old icon → new icon)                   │
/// ├─────────────────────────────────────────────────────────┤
/// │  Navbar                                                 │
/// │   home_outlined → home_rounded (outline)                │
/// │   home_rounded  → home_rounded (filled, same glyph)     │
/// │   qr_code_scanner_outlined → qr_code_scanner_rounded    │
/// │   qr_code_scanner_rounded  → qr_code_scanner_rounded    │
/// │   auto_awesome_outlined → auto_awesome_outlined          │
/// │   auto_awesome_rounded  → auto_awesome_rounded           │
/// │   person_outline_rounded → person_outline_rounded        │
/// │   person_rounded → person_rounded                        │
/// │                                                         │
/// │  Navigation & Chrome                                    │
/// │   arrow_back → arrow_back_rounded                        │
/// │   arrow_back_ios_new_rounded → arrow_back_ios_new_rounded│
/// │   chevron_left_rounded → chevron_left_rounded            │
/// │   chevron_right_rounded → chevron_right_rounded          │
/// │   close → close_rounded                                  │
/// │   open_in_new → open_in_new_rounded                      │
/// │                                                         │
/// │  Actions                                                │
/// │   add → add_rounded                                      │
/// │   add_rounded → add_rounded                              │
/// │   check → check_rounded                                  │
/// │   check_rounded → check_rounded                          │
/// │   check_circle_rounded → check_circle_rounded            │
/// │   copy_rounded → copy_rounded                            │
/// │   delete_outline_rounded → delete_outline_rounded        │
/// │   delete_sweep_rounded → delete_sweep_rounded            │
/// │   edit_rounded → edit_rounded                            │
/// │   refresh → refresh_rounded                              │
/// │   refresh_rounded → refresh_rounded                      │
/// │   arrow_upward_rounded → arrow_upward_rounded            │
/// │                                                         │
/// │  Content & Screens                                      │
/// │   account_circle_rounded → account_circle_rounded        │
/// │   auto_awesome_rounded → auto_awesome_rounded            │
/// │   auto_awesome_outlined → auto_awesome_outlined          │
/// │   cake_rounded → cake_rounded                            │
/// │   center_focus_strong_rounded → center_focus_strong_roundd│
/// │   code_rounded → code_rounded                            │
/// │   dataset_outlined → dataset_outlined                    │
/// │   description_outlined → description_outlined            │
/// │   directions_run_rounded → directions_run_rounded        │
/// │   directions_walk_rounded → directions_walk_rounded      │
/// │   edit_calendar_rounded → edit_calendar_rounded          │
/// │   error_outline → error_outline_rounded                  │
/// │   error_outline_rounded → error_outline_rounded          │
/// │   fastfood_rounded → fastfood_rounded                    │
/// │   flag_rounded → flag_rounded                            │
/// │   height_rounded → height_rounded                        │
/// │   history_rounded → history_rounded                      │
/// │   info_outline_rounded → info_outline_rounded            │
/// │   insights_outlined → insights_rounded                   │
/// │   bug_report_outlined → bug_report_rounded               │
/// │   lock_reset_rounded → lock_reset_rounded                │
/// │   logout_rounded → logout_rounded                        │
/// │   medical_services_rounded → medical_services_rounded    │
/// │   monitor_weight_rounded → monitor_weight_rounded        │
/// │   person → person_rounded                                │
/// │   person_add_alt_1_rounded → person_add_alt_1_rounded    │
/// │   person_outline_rounded → person_outline_rounded        │
/// │   person_remove_rounded → person_remove_rounded          │
/// │   privacy_tip_outlined → privacy_tip_rounded             │
/// │   qr_code_scanner_rounded → qr_code_scanner_rounded     │
/// │   restaurant_menu → restaurant_menu_rounded              │
/// │   restaurant_menu_rounded → restaurant_menu_rounded      │
/// │   restaurant_rounded → restaurant_rounded                │
/// │   settings_rounded → settings_rounded                    │
/// │   shopping_basket_rounded → shopping_basket_rounded      │
/// │   shopping_cart_outlined → shopping_cart_rounded          │
/// │   shopping_cart_rounded → shopping_cart_rounded           │
/// │   warning_amber_rounded → warning_amber_rounded          │
/// └─────────────────────────────────────────────────────────┘
class AppIcons {
  AppIcons._();

  // ════════════════════════ Navbar Icons ════════════════════════
  // Outline (inactive) and filled (active) pairs for crossfade morph.

  static const IconData navHomeOutline = Icons.home_outlined;
  static const IconData navHomeFilled = Icons.home_rounded;

  static const IconData navScanOutline = Icons.qr_code_scanner_outlined;
  static const IconData navScanFilled = Icons.qr_code_scanner_rounded;

  static const IconData navAiChatOutline = Icons.auto_awesome_outlined;
  static const IconData navAiChatFilled = Icons.auto_awesome_rounded;

  static const IconData navProfileOutline = Icons.person_outline_rounded;
  static const IconData navProfileFilled = Icons.person_rounded;

  // ════════════════════════ Navigation Chrome ════════════════════════

  static const IconData arrowBack = Icons.arrow_back_rounded;
  static const IconData arrowBackIos = Icons.arrow_back_ios_new_rounded;
  static const IconData chevronLeft = Icons.chevron_left_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData openInNew = Icons.open_in_new_rounded;
  static const IconData arrowUpward = Icons.arrow_upward_rounded;

  // ════════════════════════ Actions ════════════════════════

  static const IconData add = Icons.add_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData checkCircle = Icons.check_circle_rounded;
  static const IconData copy = Icons.copy_rounded;
  static const IconData deleteOutline = Icons.delete_outline_rounded;
  static const IconData deleteSweep = Icons.delete_sweep_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData refresh = Icons.refresh_rounded;

  // ════════════════════════ Content & Screens ════════════════════════

  static const IconData accountCircle = Icons.account_circle_rounded;
  static const IconData aiSparkle = Icons.auto_awesome_rounded;
  static const IconData aiSparkleOutline = Icons.auto_awesome_outlined;
  static const IconData cake = Icons.cake_rounded;
  static const IconData centerFocus = Icons.center_focus_strong_rounded;
  static const IconData code = Icons.code_rounded;
  static const IconData dataset = Icons.dataset_rounded;
  static const IconData description = Icons.description_rounded;
  static const IconData directionsRun = Icons.directions_run_rounded;
  static const IconData directionsWalk = Icons.directions_walk_rounded;
  static const IconData editCalendar = Icons.edit_calendar_rounded;
  static const IconData errorOutline = Icons.error_outline_rounded;
  static const IconData fastfood = Icons.fastfood_rounded;
  static const IconData flag = Icons.flag_rounded;
  static const IconData height = Icons.height_rounded;
  static const IconData history = Icons.history_rounded;
  static const IconData infoOutline = Icons.info_outline_rounded;
  static const IconData insights = Icons.insights_rounded;
  static const IconData bugReport = Icons.bug_report_rounded;
  static const IconData lockReset = Icons.lock_reset_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData medicalServices = Icons.medical_services_rounded;
  static const IconData monitorWeight = Icons.monitor_weight_rounded;
  static const IconData person = Icons.person_rounded;
  static const IconData personAdd = Icons.person_add_alt_1_rounded;
  static const IconData personOutline = Icons.person_outline_rounded;
  static const IconData personRemove = Icons.person_remove_rounded;
  static const IconData privacyTip = Icons.privacy_tip_rounded;
  static const IconData qrCodeScanner = Icons.qr_code_scanner_rounded;
  static const IconData restaurantMenu = Icons.restaurant_menu_rounded;
  static const IconData restaurant = Icons.restaurant_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData shoppingBasket = Icons.shopping_basket_rounded;
  static const IconData shoppingCart = Icons.shopping_cart_rounded;
  static const IconData shoppingCartOutline = Icons.shopping_cart_outlined;
  static const IconData warningAmber = Icons.warning_amber_rounded;
}
