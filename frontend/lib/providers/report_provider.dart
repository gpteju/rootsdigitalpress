// CHANGE-2026-09-08: Financial Reporting State Provider updated with Bill-Wise Daily Sales and customer filtering.
// CHANGE-2026-09-09: Added Customer Payment Report state handling.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class ReportProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _dailySalesBills = [];
  Map<String, dynamic>? _dailySalesSummary;
  List<dynamic> _customerWise = [];
  List<dynamic> _supplierPurchases = [];
  List<dynamic> _customerPending = [];
  List<dynamic> _customerAging = [];
  List<dynamic> _stockReport = [];
  Map<String, dynamic>? _customerPaymentReport;

  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get dailySales => _dailySalesBills;
  List<dynamic> get dailySalesBills => _dailySalesBills;
  Map<String, dynamic>? get dailySalesSummary => _dailySalesSummary;
  List<dynamic> get customerWise => _customerWise;
  List<dynamic> get supplierPurchases => _supplierPurchases;
  List<dynamic> get customerPending => _customerPending;
  List<dynamic> get customerAging => _customerAging;
  List<dynamic> get stockReport => _stockReport;
  Map<String, dynamic>? get customerPaymentReport => _customerPaymentReport;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDailySalesReport({String? startDate, String? endDate, int? customerId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = ApiEndpoints.reportDailySales;
    List<String> q = [];
    if (startDate != null && startDate.isNotEmpty) q.add('start_date=${startDate}');
    if (endDate != null && endDate.isNotEmpty) q.add('end_date=${endDate}');
    if (customerId != null) q.add('customer_id=${customerId}');
    if (q.isNotEmpty) url += '?${q.join("&")}';

    final res = await _api.get<Map<String, dynamic>>(url, parser: (j) => j as Map<String, dynamic>);
    if (res.success && res.data != null) {
      _dailySalesBills = res.data!['bills'] as List<dynamic>? ?? [];
      _dailySalesSummary = res.data!['summary'] as Map<String, dynamic>?;
    } else {
      _errorMessage = res.message;
      _dailySalesBills = [];
      _dailySalesSummary = null;
    }

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
    if (customerId != null) url += '?customer_id=${customerId}';

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
    if (customerId != null) url += '?customer_id=${customerId}';

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

  Future<void> fetchCustomerPaymentReport(int customerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = '${ApiEndpoints.reportCustomerPayment}?customer_id=${customerId}';
    final res = await _api.get<Map<String, dynamic>>(url, parser: (j) => j as Map<String, dynamic>);
    if (res.success && res.data != null) {
      _customerPaymentReport = res.data!;
    } else {
      _errorMessage = res.message;
      _customerPaymentReport = null;
    }

    _isLoading = false;
    notifyListeners();
  }
}
