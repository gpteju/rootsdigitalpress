// CHANGE-2026-09-07: Created Paper Type, GSM, Size, and Unified Paper data models.

class PaperTypeModel {
  final int? id;
  final String name;
  final String? description;
  final bool isActive;

  PaperTypeModel({this.id, required this.name, this.description, this.isActive = true});

  factory PaperTypeModel.fromJson(Map<String, dynamic> json) {
    return PaperTypeModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {if (id != null) 'id': id, 'name': name, 'description': description, 'is_active': isActive ? 1 : 0};
}

class PaperGsmModel {
  final int? id;
  final int gsmValue;
  final String? description;
  final bool isActive;

  PaperGsmModel({this.id, required this.gsmValue, this.description, this.isActive = true});

  factory PaperGsmModel.fromJson(Map<String, dynamic> json) {
    return PaperGsmModel(
      id: json['id'],
      gsmValue: json['gsm_value'] ?? 0,
      description: json['description'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {if (id != null) 'id': id, 'gsm_value': gsmValue, 'description': description, 'is_active': isActive ? 1 : 0};
}

class PaperSizeModel {
  final int? id;
  final String name;
  final String? description;
  final bool isActive;

  PaperSizeModel({this.id, required this.name, this.description, this.isActive = true});

  factory PaperSizeModel.fromJson(Map<String, dynamic> json) {
    return PaperSizeModel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {if (id != null) 'id': id, 'name': name, 'description': description, 'is_active': isActive ? 1 : 0};
}

class PaperModel {
  final int? id;
  final String paperName;
  final int paperTypeId;
  final int paperGsmId;
  final int paperSizeId;
  final String? paperTypeName;
  final int? gsmValue;
  final String? paperSizeName;
  final String purchaseUnit;
  final double openingStock;
  final double currentStock;
  final double reorderLevel;
  final bool isActive;

  PaperModel({
    this.id,
    required this.paperName,
    required this.paperTypeId,
    required this.paperGsmId,
    required this.paperSizeId,
    this.paperTypeName,
    this.gsmValue,
    this.paperSizeName,
    this.purchaseUnit = 'Sheet',
    this.openingStock = 0.0,
    this.currentStock = 0.0,
    this.reorderLevel = 100.0,
    this.isActive = true,
  });

  factory PaperModel.fromJson(Map<String, dynamic> json) {
    return PaperModel(
      id: json['id'],
      paperName: json['paper_name'] ?? '',
      paperTypeId: json['paper_type_id'] ?? 0,
      paperGsmId: json['paper_gsm_id'] ?? 0,
      paperSizeId: json['paper_size_id'] ?? 0,
      paperTypeName: json['paper_type_name'],
      gsmValue: json['gsm_value'],
      paperSizeName: json['paper_size_name'],
      purchaseUnit: json['purchase_unit'] ?? 'Sheet',
      openingStock: double.tryParse(json['opening_stock']?.toString() ?? '0') ?? 0.0,
      currentStock: double.tryParse(json['current_stock']?.toString() ?? '0') ?? 0.0,
      reorderLevel: double.tryParse(json['reorder_level']?.toString() ?? '100') ?? 100.0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'paper_name': paperName,
    'paper_type_id': paperTypeId,
    'paper_gsm_id': paperGsmId,
    'paper_size_id': paperSizeId,
    'purchase_unit': purchaseUnit,
    'opening_stock': openingStock,
    'reorder_level': reorderLevel,
    'is_active': isActive ? 1 : 0,
  };
}
