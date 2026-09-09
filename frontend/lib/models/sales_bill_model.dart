// CHANGE-2026-09-07: Created Sales Bill & Line Item data models.

class SalesBillItemModel {
  final int? id;
  final int paperId;
  final int printoutTypeId;
  final String? paperNameSnapshot;
  final String? printoutTypeNameSnapshot;
  final double quantity;
  final double firstCopyRate;
  final double additionalCopyRate;
  final String rateBasedOn;
  final double clickRate;
  final double calculatedAmount;
  final double taxPercentage;
  final double taxAmount;
  final double totalAmount;

  SalesBillItemModel({
    this.id,
    required this.paperId,
    required this.printoutTypeId,
    this.paperNameSnapshot,
    this.printoutTypeNameSnapshot,
    required this.quantity,
    required this.firstCopyRate,
    required this.additionalCopyRate,
    this.rateBasedOn = 'Rates',
    this.clickRate = 0.0,
    required this.calculatedAmount,
    this.taxPercentage = 0.0,
    this.taxAmount = 0.0,
    this.totalAmount = 0.0,
  });

  factory SalesBillItemModel.fromJson(Map<String, dynamic> json) {
    return SalesBillItemModel(
      id: json['id'],
      paperId: json['paper_id'] ?? 0,
      printoutTypeId: json['printout_type_id'] ?? 0,
      paperNameSnapshot: json['paper_name_snapshot'],
      printoutTypeNameSnapshot: json['printout_type_name_snapshot'],
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      firstCopyRate: double.tryParse(json['first_copy_rate']?.toString() ?? '0') ?? 0.0,
      additionalCopyRate: double.tryParse(json['additional_copy_rate']?.toString() ?? '0') ?? 0.0,
      rateBasedOn: json['rate_based_on'] ?? 'Rates',
      clickRate: double.tryParse(json['click_rate']?.toString() ?? '0') ?? 0.0,
      calculatedAmount: double.tryParse(json['calculated_amount']?.toString() ?? '0') ?? 0.0,
      taxPercentage: double.tryParse(json['tax_percentage']?.toString() ?? '0') ?? 0.0,
      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'paper_id': paperId,
    'printout_type_id': printoutTypeId,
    'quantity': quantity,
    'first_copy_rate': firstCopyRate,
    'additional_copy_rate': additionalCopyRate,
    'rate_based_on': rateBasedOn,
    'click_rate': clickRate,
    'calculated_amount': calculatedAmount,
  };
}

class SalesBillModel {
  final int? id;
  final String? billNumber;
  final String billDate;
  final int customerId;
  final int taxId;
  final String? customerName;
  final String? customerPhone;
  final String? taxName;
  final double taxPercentage;
  final String? companyStateSnapshot;
  final String? customerStateSnapshot;
  final bool isInterstate;
  final double subtotal;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double roundOff;
  final double grandTotal;
  final double paidAmount;
  final double balanceAmount;
  final String status;
  final String? notes;
  final List<SalesBillItemModel> items;

  double get totalTaxAmount {
    final explicit = cgstAmount + sgstAmount + igstAmount;
    if (explicit > 0) return explicit;
    final diff = grandTotal - subtotal - roundOff;
    return diff > 0.01 ? diff : 0.0;
  }

  SalesBillModel({
    this.id,
    this.billNumber,
    required this.billDate,
    required this.customerId,
    required this.taxId,
    this.customerName,
    this.customerPhone,
    this.taxName,
    this.taxPercentage = 0.0,
    this.companyStateSnapshot,
    this.customerStateSnapshot,
    this.isInterstate = false,
    required this.subtotal,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
    this.roundOff = 0.0,
    required this.grandTotal,
    this.paidAmount = 0.0,
    required this.balanceAmount,
    this.status = 'UNPAID',
    this.notes,
    this.items = const [],
  });

  factory SalesBillModel.fromJson(Map<String, dynamic> json) {
    var itemList = json['items'] as List? ?? [];
    List<SalesBillItemModel> parsedItems = itemList.map((i) => SalesBillItemModel.fromJson(i)).toList();

    return SalesBillModel(
      id: json['id'],
      billNumber: json['bill_number'],
      billDate: json['bill_date'] ?? '',
      customerId: json['customer_id'] ?? 0,
      taxId: json['tax_id'] ?? 0,
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      taxName: json['tax_name'],
      taxPercentage: double.tryParse(json['tax_percentage']?.toString() ?? '0') ?? 0.0,
      companyStateSnapshot: json['company_state_snapshot'],
      customerStateSnapshot: json['customer_state_snapshot'],
      isInterstate: json['is_interstate'] == 1 || json['is_interstate'] == true,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      cgstAmount: double.tryParse(json['cgst_amount']?.toString() ?? '0') ?? 0.0,
      sgstAmount: double.tryParse(json['sgst_amount']?.toString() ?? '0') ?? 0.0,
      igstAmount: double.tryParse(json['igst_amount']?.toString() ?? '0') ?? 0.0,
      roundOff: double.tryParse(json['round_off']?.toString() ?? '0') ?? 0.0,
      grandTotal: double.tryParse(json['grand_total']?.toString() ?? '0') ?? 0.0,
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0.0,
      balanceAmount: double.tryParse(json['balance_amount']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'UNPAID',
      notes: json['notes'],
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'customer_id': customerId,
    'tax_id': taxId,
    'round_off': roundOff,
    'bill_date': billDate,
    'notes': notes,
    'items': items.map((e) => e.toJson()).toList(),
  };
}
