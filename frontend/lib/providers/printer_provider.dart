// CHANGE-2026-09-07: Created Printer Settings Provider.

import 'package:flutter/material.dart';
import '../models/printer_settings_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class PrinterProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  PrinterSettingsModel? _settings;
  bool _isLoading = false;
  String? _errorMessage;

  PrinterSettingsModel? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchPrinterSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.get<PrinterSettingsModel>(
      ApiEndpoints.printerSettings,
      parser: (json) => PrinterSettingsModel.fromJson(json),
    );

    if (response.success && response.data != null) {
      _settings = response.data;
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> savePrinterSettings(PrinterSettingsModel newSettings) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post<PrinterSettingsModel>(
      ApiEndpoints.printerSettings,
      newSettings.toJson(),
      parser: (json) => PrinterSettingsModel.fromJson(json),
    );

    _isLoading = false;

    if (response.success && response.data != null) {
      _settings = response.data;
      notifyListeners();
      return true;
    } else {
      _errorMessage = response.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> testPrinter() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _api.post<dynamic>(
      ApiEndpoints.testPrinter,
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
