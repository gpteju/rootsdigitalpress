// CHANGE-2026-09-07: Created Customer data model.

class CustomerModel {
  final int? id;
  final String customerName;
  final String? address;
  final String? city;
  final String state;
  final String stateCode;
  final String? gstin;
  final String? phone;
  final String? email;
  final double creditLimit;
  final double advanceBalance;
  final int paymentTerms;
  final bool isActive;

  CustomerModel({
    this.id,
    required this.customerName,
    this.address,
    this.city,
    required this.state,
    required this.stateCode,
    this.gstin,
    this.phone,
    this.email,
    this.creditLimit = 0.0,
    this.advanceBalance = 0.0,
    this.paymentTerms = 30,
    this.isActive = true,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'],
      customerName: json['customer_name'] ?? '',
      address: json['address'],
      city: json['city'],
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
      gstin: json['gstin'],
      phone: json['phone'],
      email: json['email'],
      creditLimit: double.tryParse(json['credit_limit']?.toString() ?? '0') ?? 0.0,
      advanceBalance: double.tryParse(json['advance_balance']?.toString() ?? '0') ?? 0.0,
      paymentTerms: json['payment_terms'] ?? 30,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'customer_name': customerName,
      'address': address,
      'city': city,
      'state': state,
      'state_code': stateCode,
      'gstin': gstin,
      'phone': phone,
      'email': email,
      'credit_limit': creditLimit,
      'advance_balance': advanceBalance,
      'payment_terms': paymentTerms,
      'is_active': isActive ? 1 : 0,
    };
  }
}
