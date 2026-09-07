// CHANGE-2026-09-07: Created Customer Master State Provider.

import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class CustomerProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CustomerModel> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCustomers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.get<List<CustomerModel>>(
      ApiEndpoints.customers,
      parser: (json) => (json as List).map((i) => CustomerModel.fromJson(i)).toList(),
    );

    if (response.success && response.data != null) {
      _customers = response.data!;
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createCustomer(CustomerModel customer) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post<CustomerModel>(
      ApiEndpoints.customers,
      customer.toJson(),
      parser: (json) => CustomerModel.fromJson(json),
    );

    if (response.success) {
      await fetchCustomers();
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCustomer(int id, CustomerModel customer) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.put<CustomerModel>(
      '${ApiEndpoints.customers}/$id',
      customer.toJson(),
      parser: (json) => CustomerModel.fromJson(json),
    );

    if (response.success) {
      await fetchCustomers();
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
