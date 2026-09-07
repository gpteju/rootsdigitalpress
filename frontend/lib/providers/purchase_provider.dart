// CHANGE-2026-09-07: Created Supplier Purchases and Stock State Provider.

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class PurchaseProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _purchases = [];
  List<dynamic> _stockSummary = [];
  List<dynamic> _stockLedger = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get purchases => _purchases;
  List<dynamic> get stockSummary => _stockSummary;
  List<dynamic> get stockLedger => _stockLedger;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPurchases({int? supplierId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = ApiEndpoints.purchases;
    if (supplierId != null) url += '?supplier_id=$supplierId';

    final res = await _api.get<List<dynamic>>(url, parser: (j) => j as List);
    if (res.success && res.data != null) _purchases = res.data!;
    else _errorMessage = res.message;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchStockSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.get<List<dynamic>>(ApiEndpoints.stockSummary, parser: (j) => j as List);
    if (res.success && res.data != null) _stockSummary = res.data!;
    else _errorMessage = res.message;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchStockLedger({int? paperId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String url = ApiEndpoints.stockLedger;
    if (paperId != null) url += '?paper_id=$paperId';

    final res = await _api.get<List<dynamic>>(url, parser: (j) => j as List);
    if (res.success && res.data != null) _stockLedger = res.data!;
    else _errorMessage = res.message;

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createPurchase(Map<String, dynamic> purchaseData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.post<dynamic>(ApiEndpoints.purchases, purchaseData);
    _isLoading = false;

    if (res.success) {
      await fetchPurchases();
      await fetchStockSummary();
      return true;
    } else {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> adjustStock({required int paperId, required String adjustmentType, required double quantity, String? remarks}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _api.post<dynamic>(ApiEndpoints.stockAdjust, {
      'paper_id': paperId,
      'adjustment_type': adjustmentType,
      'quantity': quantity,
      'remarks': remarks,
    });
    _isLoading = false;

    if (res.success) {
      await fetchStockSummary();
      return true;
    } else {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }
  }
}
