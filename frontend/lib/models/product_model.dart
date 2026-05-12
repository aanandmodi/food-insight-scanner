/// Typed model for product data fetched from Open Food Facts / Firestore cache.
class ProductModel {
  final String barcode;
  final String name;
  final String brand;
  final String? category;
  final String? imageUrl;
  final Map<String, dynamic> nutrition;
  final List<String> ingredients;
  final List<String> allergens;
  final String? servingSize;
  final String? nutriScore;
  final int? novaGroup;

  const ProductModel({
    required this.barcode,
    required this.name,
    required this.brand,
    this.category,
    this.imageUrl,
    required this.nutrition,
    required this.ingredients,
    required this.allergens,
    this.servingSize,
    this.nutriScore,
    this.novaGroup,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      barcode: map['barcode'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown Product',
      brand: map['brand'] as String? ?? 'Unknown Brand',
      category: map['category'] as String?,
      imageUrl: map['image'] as String?,
      nutrition: Map<String, dynamic>.from(map['nutrition'] as Map? ?? {}),
      ingredients: List<String>.from(map['ingredients'] as List? ?? []),
      allergens: List<String>.from(map['allergens'] as List? ?? []),
      servingSize: map['servingSize'] as String?,
      nutriScore: map['nutriscore'] as String?,
      novaGroup: map['novaGroup'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'category': category,
      'image': imageUrl,
      'nutrition': nutrition,
      'ingredients': ingredients,
      'allergens': allergens,
      'servingSize': servingSize,
      'nutriscore': nutriScore,
      'novaGroup': novaGroup,
    };
  }
}
