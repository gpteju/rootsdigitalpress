// CHANGE-2026-09-07: Created Customer Payments State Provider supporting FIFO & Manual allocation.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class PaymentProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _payments = [];
  List<dynamic> _pendingBills = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get payments => _payments;
  List<dynamic> get pendingBills => _pendingBills;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPayments({int? customerId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = ApiEndpoints.customerPayments;
    if (customerId != null) url += '?customer_id=$customerId';

    final response = await _api.get<List<dynamic>>(
      url,
      parser: (j) => j as List,
    );

    if (response.success && response.data != null) {
      _payments = response.data!;
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCustomerPendingBills(int customerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.get<List<dynamic>>(
      ApiEndpoints.pendingBills(customerId),
      parser: (j) => j as List,
    );

    if (response.success && response.data != null) {
      _pendingBills = response.data!;
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> submitPayment({
    required int customerId,
    required String paymentDate,
    required double amount,
    required String allocationMode, // 'FIFO' or 'MANUAL'
    List<Map<String, dynamic>>? manualAllocations,
    String paymentMode = 'CASH',
    String? referenceNumber,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final body = {
      'customer_id': customerId,
      'payment_date': paymentDate,
      'amount': amount,
      'allocation_mode': allocationMode,
      'manual_allocations': manualAllocations ?? [],
      'payment_mode': paymentMode,
      'reference_number': referenceNumber,
      'notes': notes,
    };

    final response = await _api.post<dynamic>(
      ApiEndpoints.customerPayments,
      body,
    );

    _isLoading = false;

    if (response.success) {
      await fetchPayments();
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }
}
