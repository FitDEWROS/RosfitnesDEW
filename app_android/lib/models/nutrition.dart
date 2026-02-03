class NutritionEntry {
  final int id;
  final String date;
  final int? kcal;
  final double? protein;
  final double? fat;
  final double? carb;
  final double? waterLiters;
  final int? mealsCount;

  NutritionEntry({
    required this.id,
    required this.date,
    this.kcal,
    this.protein,
    this.fat,
    this.carb,
    this.waterLiters,
    this.mealsCount,
  });

  factory NutritionEntry.fromJson(Map<String, dynamic> json) {
    return NutritionEntry(
      id: (json['id'] ?? 0) as int,
      date: (json['date'] ?? '').toString(),
      kcal: json['kcal'] as int?,
      protein: (json['protein'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      carb: (json['carb'] as num?)?.toDouble(),
      waterLiters: (json['waterLiters'] as num?)?.toDouble(),
      mealsCount: json['mealsCount'] as int?,
    );
  }
}

class NutritionItem {
  final int id;
  final int? productId;
  final String title;
  final String? brand;
  final String meal;
  final double grams;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;

  NutritionItem({
    required this.id,
    required this.productId,
    required this.title,
    required this.brand,
    required this.meal,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
  });

  factory NutritionItem.fromJson(Map<String, dynamic> json) {
    return NutritionItem(
      id: (json['id'] ?? 0) as int,
      productId: json['productId'] as int?,
      title: (json['title'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString().isEmpty ? null : json['brand'].toString(),
      meal: (json['meal'] ?? '').toString(),
      grams: (json['grams'] as num?)?.toDouble() ?? 0,
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      carb: (json['carb'] as num?)?.toDouble() ?? 0,
    );
  }
}

class NutritionProduct {
  final int? id;
  final String? barcode;
  final String title;
  final String? brand;
  final String? imageUrl;
  final double? kcal100;
  final double? protein100;
  final double? fat100;
  final double? carb100;

  NutritionProduct({
    this.id,
    this.barcode,
    required this.title,
    this.brand,
    this.imageUrl,
    this.kcal100,
    this.protein100,
    this.fat100,
    this.carb100,
  });

  factory NutritionProduct.fromJson(Map<String, dynamic> json) {
    return NutritionProduct(
      id: json['id'] as int?,
      barcode: (json['barcode'] ?? '').toString().isEmpty ? null : json['barcode'].toString(),
      title: (json['title'] ?? '').toString(),
      brand: (json['brand'] ?? '').toString().isEmpty ? null : json['brand'].toString(),
      imageUrl: (json['imageUrl'] ?? '').toString().isEmpty ? null : json['imageUrl'].toString(),
      kcal100: (json['kcal100'] as num?)?.toDouble(),
      protein100: (json['protein100'] as num?)?.toDouble(),
      fat100: (json['fat100'] as num?)?.toDouble(),
      carb100: (json['carb100'] as num?)?.toDouble(),
    );
  }
}

class NutritionDay {
  final String date;
  final NutritionEntry? entry;
  final List<NutritionItem> items;
  final String? comment;

  NutritionDay({
    required this.date,
    required this.entry,
    required this.items,
    required this.comment,
  });

  factory NutritionDay.fromJson(Map<String, dynamic> json) {
    return NutritionDay(
      date: (json['date'] ?? '').toString(),
      entry: json['entry'] == null
          ? null
          : NutritionEntry.fromJson(json['entry'] as Map<String, dynamic>),
      items: (json['items'] as List? ?? const [])
          .map((e) => NutritionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      comment: (json['comment'] ?? '').toString().isEmpty ? null : json['comment'].toString(),
    );
  }
}

class NutritionHistoryDay {
  final String date;
  final NutritionEntry? entry;
  final String? comment;

  NutritionHistoryDay({
    required this.date,
    required this.entry,
    required this.comment,
  });

  factory NutritionHistoryDay.fromJson(Map<String, dynamic> json) {
    return NutritionHistoryDay(
      date: (json['date'] ?? '').toString(),
      entry: json['entry'] == null
          ? null
          : NutritionEntry.fromJson(json['entry'] as Map<String, dynamic>),
      comment: (json['comment'] ?? '').toString().isEmpty ? null : json['comment'].toString(),
    );
  }
}
