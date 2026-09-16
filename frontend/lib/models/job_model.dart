// CHANGE-2026-09-08: Created Job Details and Job Item Flutter models.

class JobItemModel {
  final int? id;
  final int? jobDetailId;
  final int paperId;
  final int printoutTypeId;
  final String paperNameSnapshot;
  final String? jobName;
  final String printoutTypeNameSnapshot;
  final double quantity;
  final double firstCopyRate;
  final double additionalCopyRate;
  final double calculatedAmount;
  final double totalAmount;

  JobItemModel({
    this.id,
    this.jobDetailId,
    required this.paperId,
    required this.printoutTypeId,
    required this.paperNameSnapshot,
    this.jobName,
    required this.printoutTypeNameSnapshot,
    required this.quantity,
    required this.firstCopyRate,
    required this.additionalCopyRate,
    required this.calculatedAmount,
    required this.totalAmount,
  });

  factory JobItemModel.fromJson(Map<String, dynamic> json) {
    return JobItemModel(
      id: json['id'],
      jobDetailId: json['job_detail_id'],
      paperId: json['paper_id'],
      printoutTypeId: json['printout_type_id'],
      paperNameSnapshot: json['paper_name_snapshot'] ?? '',
      jobName: json['job_name'],
      printoutTypeNameSnapshot: json['printout_type_name_snapshot'] ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      firstCopyRate: double.tryParse(json['first_copy_rate']?.toString() ?? '0') ?? 0.0,
      additionalCopyRate: double.tryParse(json['additional_copy_rate']?.toString() ?? '0') ?? 0.0,
      calculatedAmount: double.tryParse(json['calculated_amount']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'paper_id': paperId,
      'printout_type_id': printoutTypeId,
      'paper_name_snapshot': paperNameSnapshot,
      'job_name': jobName,
      'printout_type_name_snapshot': printoutTypeNameSnapshot,
      'quantity': quantity,
      'first_copy_rate': firstCopyRate,
      'additional_copy_rate': additionalCopyRate,
      'calculated_amount': calculatedAmount,
      'total_amount': totalAmount,
    };
  }
}

class JobModel {
  final int? id;
  final String? jobNumber;
  final String jobDate;
  final int customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final double subtotal;
  final double grandTotal;
  final String? notes;
  final List<JobItemModel> items;

  JobModel({
    this.id,
    this.jobNumber,
    required this.jobDate,
    required this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.subtotal,
    required this.grandTotal,
    this.notes,
    this.items = const [],
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List?;
    List<JobItemModel> itemList = rawItems != null
        ? rawItems.map((i) => JobItemModel.fromJson(i)).toList()
        : [];

    return JobModel(
      id: json['id'],
      jobNumber: json['job_number'],
      jobDate: json['job_date'] ?? '',
      customerId: json['customer_id'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      customerEmail: json['customer_email'],
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0.0,
      notes: json['notes'],
      items: itemList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'customer_id': customerId,
      'notes': notes,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}
