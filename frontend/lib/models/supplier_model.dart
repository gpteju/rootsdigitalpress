// CHANGE-2026-09-07: Created Supplier data model.

class SupplierModel {
  final int? id;
  final String supplierName;
  final String? address;
  final String? city;
  final String state;
  final String stateCode;
  final String? gstin;
  final String? phone;
  final String? email;
  final int paymentTerms;
  final bool isActive;

  SupplierModel({
    this.id,
    required this.supplierName,
    this.address,
    this.city,
    required this.state,
    required this.stateCode,
    this.gstin,
    this.phone,
    this.email,
    this.paymentTerms = 30,
    this.isActive = true,
  });

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'],
      supplierName: json['supplier_name'] ?? '',
      address: json['address'],
      city: json['city'],
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
      gstin: json['gstin'],
      phone: json['phone'],
      email: json['email'],
      paymentTerms: json['payment_terms'] ?? 30,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'supplier_name': supplierName,
      'address': address,
      'city': city,
      'state': state,
      'state_code': stateCode,
      'gstin': gstin,
      'phone': phone,
      'email': email,
      'payment_terms': paymentTerms,
      'is_active': isActive ? 1 : 0,
    };
  }
}
