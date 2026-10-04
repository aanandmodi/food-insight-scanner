import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_session.dart';

/// Server values may disable shipped AI features. Unimplemented features stay off.
class FeatureFlagService extends ChangeNotifier {
  bool aiEnabled = false;
  bool aiChatEnabled = false;
  bool mealPlannerEnabled = false;
  bool aiProductAnalysisEnabled = false;
  bool aiMealParserEnabled = false;
  bool aiRecalibrationEnabled = false;
  bool aiQuickRepliesEnabled = false;
  bool additiveInsightsEnabled = true;
  bool _disposed = false;
  int _revision = 0;
  bool alternativesEnabled = false;
  static const ocrEnabled = false;
  static const notificationsEnabled = false;
  static const visionChatEnabled = false;
  FeatureFlagService() {
    UserSession.instance.addListener(refresh);
    Future.microtask(refresh);
  }
  Future<void> refresh() async {
    if (_disposed) return;
    final revision = ++_revision;
    final uid = UserSession.instance.uid;
    aiEnabled = false;
    aiChatEnabled = false;
    mealPlannerEnabled = false;
    aiProductAnalysisEnabled = false;
    aiMealParserEnabled = false;
    aiRecalibrationEnabled = false;
    aiQuickRepliesEnabled = false;
    alternativesEnabled = false;
    notifyListeners();
    if (uid == null) return;
    try {
      final document = await FirebaseFirestore.instance
          .doc('config/featureFlags')
          .get()
          .timeout(const Duration(seconds: 5));
      if (_disposed ||
          revision != _revision ||
          UserSession.instance.uid != uid) {
        return;
      }
      final flags = document.data() ?? {};
      aiEnabled = flags['aiEnabled'] == true;
      aiChatEnabled = aiEnabled && flags['aiChatEnabled'] != false;
      mealPlannerEnabled = aiEnabled &&
          flags['mealPlannerEnabled'] != false &&
          flags['aiMealPlannerEnabled'] != false;
      aiProductAnalysisEnabled =
          aiEnabled && flags['aiProductAnalysisEnabled'] != false;
      aiMealParserEnabled = aiEnabled && flags['aiMealParserEnabled'] != false;
      aiRecalibrationEnabled =
          aiEnabled && flags['aiRecalibrationEnabled'] != false;
      aiQuickRepliesEnabled =
          aiEnabled && flags['aiQuickRepliesEnabled'] != false;
      additiveInsightsEnabled = flags['additiveInsightsEnabled'] != false;
      alternativesEnabled = flags['alternativesEnabled'] == true;
      notifyListeners();
    } catch (_) {/* Stay disabled until a current server flag can be read. */}
  }

  @override
  void dispose() {
    _disposed = true;
    UserSession.instance.removeListener(refresh);
    super.dispose();
  }
}
