// CHANGE-2026-09-07: Created Tax Master data model.

class SubTaxModel {
  final int? id;
  final int? taxId;
  final String subTaxName;
  final double ratePercentage;
  final String taxType;

  SubTaxModel({
    this.id,
    this.taxId,
    required this.subTaxName,
    required this.ratePercentage,
    this.taxType = 'INTRA_STATE',
  });

  factory SubTaxModel.fromJson(Map<String, dynamic> json) {
    return SubTaxModel(
      id: json['id'],
      taxId: json['tax_id'],
      subTaxName: json['sub_tax_name'] ?? '',
      ratePercentage: double.tryParse(json['rate_percentage']?.toString() ?? '0') ?? 0.0,
      taxType: json['tax_type'] ?? 'INTRA_STATE',
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (taxId != null) 'tax_id': taxId,
    'sub_tax_name': subTaxName,
    'rate_percentage': ratePercentage,
    'tax_type': taxType,
  };
}

class TaxModel {
  final int? id;
  final String taxName;
  final double taxPercentage;
  final bool isActive;
  final List<SubTaxModel> subTaxes;

  TaxModel({
    this.id,
    required this.taxName,
    required this.taxPercentage,
    this.isActive = true,
    this.subTaxes = const [],
  });

  factory TaxModel.fromJson(Map<String, dynamic> json) {
    var list = json['sub_taxes'] as List? ?? [];
    List<SubTaxModel> subTaxList = list.map((i) => SubTaxModel.fromJson(i)).toList();

    return TaxModel(
      id: json['id'],
      taxName: json['tax_name'] ?? '',
      taxPercentage: double.tryParse(json['tax_percentage']?.toString() ?? '0') ?? 0.0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      subTaxes: subTaxList,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'tax_name': taxName,
    'tax_percentage': taxPercentage,
    'is_active': isActive ? 1 : 0,
    'sub_taxes': subTaxes.map((e) => e.toJson()).toList(),
  };
}
