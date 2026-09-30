import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'user_session.dart';

/// Server values may disable shipped AI features. Unimplemented features stay off.
class FeatureFlagService extends ChangeNotifier {
  bool aiEnabled = false;
  bool aiChatEnabled = false;
  bool mealPlannerEnabled = false;
  static const alternativesEnabled = false;
  static const ocrEnabled = false;
  static const notificationsEnabled = false;
  static const visionChatEnabled = false;
  FeatureFlagService() {
    UserSession.instance.addListener(refresh);
    Future.microtask(refresh);
  }
  Future<void> refresh() async {
    final uid = UserSession.instance.uid;
    aiEnabled = false;
    aiChatEnabled = false;
    mealPlannerEnabled = false;
    notifyListeners();
    if (uid == null) return;
    try {
      final document = await FirebaseFirestore.instance
          .doc('config/featureFlags')
          .get()
          .timeout(const Duration(seconds: 5));
      if (UserSession.instance.uid != uid) return;
      final flags = document.data() ?? {};
      aiEnabled = flags['aiEnabled'] == true;
      aiChatEnabled = aiEnabled && flags['aiChatEnabled'] != false;
      mealPlannerEnabled = aiEnabled && flags['mealPlannerEnabled'] != false;
      notifyListeners();
    } catch (_) {/* Stay disabled until a current server flag can be read. */}
  }

  @override
  void dispose() {
    UserSession.instance.removeListener(refresh);
    super.dispose();
  }
}
