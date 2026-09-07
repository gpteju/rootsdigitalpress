// CHANGE-2026-09-07: Created Supplier Master State Provider.

import 'package:flutter/material.dart';
import '../models/supplier_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class SupplierProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<SupplierModel> _suppliers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SupplierModel> get suppliers => _suppliers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchSuppliers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.get<List<SupplierModel>>(
      ApiEndpoints.suppliers,
      parser: (json) => (json as List).map((i) => SupplierModel.fromJson(i)).toList(),
    );

    if (response.success && response.data != null) {
      _suppliers = response.data!;
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createSupplier(SupplierModel supplier) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post<SupplierModel>(
      ApiEndpoints.suppliers,
      supplier.toJson(),
      parser: (json) => SupplierModel.fromJson(json),
    );

    if (response.success) {
      await fetchSuppliers();
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSupplier(int id, SupplierModel supplier) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.put<SupplierModel>(
      '${ApiEndpoints.suppliers}/$id',
      supplier.toJson(),
      parser: (json) => SupplierModel.fromJson(json),
    );

    if (response.success) {
      await fetchSuppliers();
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
