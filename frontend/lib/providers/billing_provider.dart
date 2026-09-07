// CHANGE-2026-09-07: Created Sales Billing Engine State Provider.

import 'package:flutter/material.dart';
import '../models/sales_bill_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class BillingProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<SalesBillModel> _bills = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SalesBillModel> get bills => _bills;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSalesBills({int? customerId, String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = ApiEndpoints.salesBills;
    List<String> queryParams = [];
    if (customerId != null) queryParams.add('customer_id=$customerId');
    if (status != null) queryParams.add('status=$status');
    if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

    final response = await _api.get<List<SalesBillModel>>(
      url,
      parser: (json) => (json as List).map((i) => SalesBillModel.fromJson(i)).toList(),
    );

    if (response.success && response.data != null) {
      _bills = response.data!;
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<SalesBillModel?> createSalesBill(SalesBillModel bill) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post<SalesBillModel>(
      ApiEndpoints.salesBills,
      bill.toJson(),
      parser: (json) => SalesBillModel.fromJson(json),
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      await fetchSalesBills();
      return response.data;
    } else {
      _errorMessage = response.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> emailInvoice(int billId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post<dynamic>(
      '${ApiEndpoints.salesBills}/$billId/email',
      {},
    );

    _isLoading = false;
    if (response.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> printInvoice(int billId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post<dynamic>(
      '${ApiEndpoints.salesBills}/$billId/print',
      {},
    );

    _isLoading = false;
    if (response.success) {
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }
}
