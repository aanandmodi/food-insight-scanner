enum FoodInsightPlan { free, pro }

/// Billing is not enabled for beta. Critical food facts and allergy checks are
/// available independently of entitlements. Replace the source when Billing ships.
class EntitlementService {
  FoodInsightPlan get plan => FoodInsightPlan.free;
  bool get billingEnabled => false;
  bool get canViewAllergenWarnings => true;
  bool get canViewNutrition => true;
}
