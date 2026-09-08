// CHANGE-2026-09-07: Created Company data model.

class CompanyModel {
  final int? id;
  final String companyName;
  final String address;
  final String city;
  final String state;
  final String stateCode;
  final String? gstin;
  final String phone;
  final String email;
  final String invoicePrefix;
  final String estimatePrefix;
  final int estimateCurrentNumber;

  CompanyModel({
    this.id,
    required this.companyName,
    required this.address,
    required this.city,
    required this.state,
    required this.stateCode,
    this.gstin,
    required this.phone,
    required this.email,
    this.invoicePrefix = 'INV-',
    this.estimatePrefix = 'JOB-',
    this.estimateCurrentNumber = 0,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'],
      companyName: json['company_name'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      stateCode: json['state_code'] ?? '',
      gstin: json['gstin'],
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      invoicePrefix: json['invoice_prefix'] ?? 'INV-',
      estimatePrefix: json['estimate_prefix'] ?? 'JOB-',
      estimateCurrentNumber: json['estimate_current_number'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'company_name': companyName,
      'address': address,
      'city': city,
      'state': state,
      'state_code': stateCode,
      'gstin': gstin,
      'phone': phone,
      'email': email,
      'invoice_prefix': invoicePrefix,
      'estimate_prefix': estimatePrefix,
      'estimate_current_number': estimateCurrentNumber,
    };
  }
}
