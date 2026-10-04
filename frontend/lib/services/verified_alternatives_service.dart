import 'allergen_safety_service.dart';
import 'food_fit_service.dart';

class VerifiedAlternativesService {
  static List<Map<String, dynamic>> rank(Map<String, dynamic> current,
      List<Map<String, dynamic>> candidates, Map<String, dynamic> profile) {
    final allergies =
        (profile['allergies'] as List? ?? []).whereType<String>().toList();
    final diet =
        (profile['dietaryPreferences'] as List? ?? []).join(' ').toLowerCase();
    FoodFitResult fit(Map<String, dynamic> p) => FoodFitService.evaluate(p,
        allergies: allergies,
        dietaryPreference: diet,
        healthGoal: profile['healthGoals']?.toString() ?? '');
    final original = fit(current);
    final output = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final p in candidates) {
      final barcode = p['barcode'];
      if (p['source'] != 'open_food_facts' ||
          barcode is! String ||
          !RegExp(r'^\d{8,14}$').hasMatch(barcode) ||
          barcode == current['barcode'] ||
          !seen.add(barcode) ||
          p['name'] == 'Unnamed product' ||
          (p['dataCompleteness'] as num? ?? 0) < 0.75) {
        continue;
      }
      final result = fit(p);
      if (result.score == null ||
          result.conflicts.isNotEmpty ||
          result.allergen.status != AllergenStatus.noDetectedConflict) {
        continue;
      }
      final tags = (p['ingredientsAnalysisTags'] as List? ?? []).join(' ');
      // Positive dietary evidence is required for a recommended alternative.
      if (diet.contains('vegan') &&
          !diet.contains('non vegan') &&
          (!tags.contains('vegan') ||
              tags.contains('non vegan') ||
              tags.contains('vegan status unknown'))) {
        continue;
      }
      if (diet.contains('vegetarian') &&
          !diet.contains('non-vegetarian') &&
          !diet.contains('non vegetarian') &&
          (!tags.contains('vegetarian') ||
              tags.contains('non vegetarian') ||
              tags.contains('vegetarian status unknown'))) {
        continue;
      }
      if (original.score != null && result.score! <= original.score!) continue;
      final a = current['nutrition'] as Map? ?? {};
      final b = p['nutrition'] as Map? ?? {};
      final comparisons = <String>[];
      for (final key in [
        'sugarGPer100g',
        'sodiumMgPer100g',
        'proteinGPer100g',
        'fiberGPer100g'
      ]) {
        final old = a[key];
        final next = b[key];
        if (old is! num || next is! num || !old.isFinite || !next.isFinite) {
          continue;
        }
        final lower = key.startsWith('sugar') || key.startsWith('sodium');
        final improvement = lower ? old - next : next - old;
        if (improvement <= 0) continue;
        final name = key.replaceAll('GPer100g', '').replaceAll('MgPer100g', '');
        comparisons.add(
            '${improvement.toStringAsFixed(1)} ${key.startsWith('sodium') ? 'mg' : 'g'} ${lower ? 'less' : 'more'} $name per 100g');
      }
      if (comparisons.isEmpty) continue;
      output.add({
        'product': p,
        'score': result.score,
        'previousScore': original.score,
        'comparisons': comparisons
      });
    }
    output.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return output.take(3).toList();
  }
}
