// CHANGE-2026-09-07: Created Rate Master data model.

class RateModel {
  final int? id;
  final int paperId;
  final int printoutTypeId;
  final String? paperName;
  final String? printoutTypeName;
  final double firstCopyRate;
  final double additionalCopyRate;
  final double clickRate;
  final bool isActive;

  RateModel({
    this.id,
    required this.paperId,
    required this.printoutTypeId,
    this.paperName,
    this.printoutTypeName,
    required this.firstCopyRate,
    required this.additionalCopyRate,
    this.clickRate = 0.0,
    this.isActive = true,
  });

  factory RateModel.fromJson(Map<String, dynamic> json) {
    return RateModel(
      id: json['id'],
      paperId: json['paper_id'] ?? 0,
      printoutTypeId: json['printout_type_id'] ?? 0,
      paperName: json['paper_name'],
      printoutTypeName: json['printout_type_name'],
      firstCopyRate: double.tryParse(json['first_copy_rate']?.toString() ?? '0') ?? 0.0,
      additionalCopyRate: double.tryParse(json['additional_copy_rate']?.toString() ?? '0') ?? 0.0,
      clickRate: double.tryParse(json['click_rate']?.toString() ?? '0') ?? 0.0,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'paper_id': paperId,
    'printout_type_id': printoutTypeId,
    'first_copy_rate': firstCopyRate,
    'additional_copy_rate': additionalCopyRate,
    'click_rate': clickRate,
    'is_active': isActive ? 1 : 0,
  };
}
