// CHANGE-2026-09-07: Created Company Master State Provider.

import 'package:flutter/material.dart';
import '../models/company_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class CompanyProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  CompanyModel? _company;
  bool _isLoading = false;
  String? _errorMessage;

  CompanyModel? get company => _company;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchCompany() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.get<CompanyModel>(
      ApiEndpoints.company,
      parser: (json) => CompanyModel.fromJson(json),
    );

    if (response.success && response.data != null) {
      _company = response.data;
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> saveCompany(CompanyModel companyData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post<CompanyModel>(
      ApiEndpoints.company,
      companyData.toJson(),
      parser: (json) => CompanyModel.fromJson(json),
    );

    if (response.success && response.data != null) {
      _company = response.data;
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
