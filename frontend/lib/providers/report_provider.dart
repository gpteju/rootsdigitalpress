// CHANGE-2026-09-07: Created Financial Reporting State Provider.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class ReportProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _dailySales = [];
  List<dynamic> _customerWise = [];
  List<dynamic> _supplierPurchases = [];
  List<dynamic> _customerPending = [];
  List<dynamic> _customerAging = [];
  List<dynamic> _stockReport = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get dailySales => _dailySales;
  List<dynamic> get customerWise => _customerWise;
  List<dynamic> get supplierPurchases => _supplierPurchases;
  List<dynamic> get customerPending => _customerPending;
  List<dynamic> get customerAging => _customerAging;
  List<dynamic> get stockReport => _stockReport;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDailySalesReport({String? startDate, String? endDate}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = ApiEndpoints.reportDailySales;
    List<String> q = [];
    if (startDate != null) q.add('start_date=$startDate');
    if (endDate != null) q.add('end_date=$endDate');
    if (q.isNotEmpty) url += '?${q.join('&')}';

    final res = await _api.get<List<dynamic>>(url, parser: (j) => j as List);
    if (res.success && res.data != null) _dailySales = res.data!;
    else _errorMessage = res.message;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCustomerWiseReport() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.get<List<dynamic>>(ApiEndpoints.reportCustomerWise, parser: (j) => j as List);
    if (res.success && res.data != null) _customerWise = res.data!;
    else _errorMessage = res.message;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchSupplierPurchasesReport() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.get<List<dynamic>>(ApiEndpoints.reportSupplierPurchases, parser: (j) => j as List);
    if (res.success && res.data != null) _supplierPurchases = res.data!;
    else _errorMessage = res.message;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCustomerAgingReport({int? customerId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = ApiEndpoints.reportCustomerAging;
    if (customerId != null) url += '?customer_id=$customerId';

    final res = await _api.get<List<dynamic>>(url, parser: (j) => j as List);
    if (res.success && res.data != null) _customerAging = res.data!;
    else _errorMessage = res.message;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCustomerPendingReport({int? customerId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = ApiEndpoints.reportCustomerPending;
    if (customerId != null) url += '?customer_id=$customerId';

    final res = await _api.get<List<dynamic>>(url, parser: (j) => j as List);
    if (res.success && res.data != null) _customerPending = res.data!;
    else _errorMessage = res.message;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchStockReport() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.get<List<dynamic>>(ApiEndpoints.reportStock, parser: (j) => j as List);
    if (res.success && res.data != null) _stockReport = res.data!;
    else _errorMessage = res.message;

    _isLoading = false;
    notifyListeners();
  }
}
