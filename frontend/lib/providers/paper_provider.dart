// CHANGE-2026-09-07: Created Paper, Printout Type, Tax, and Rate Masters Provider.

import 'package:flutter/material.dart';
import '../models/paper_models.dart';
import '../models/printout_type_model.dart';
import '../models/tax_model.dart';
import '../models/rate_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class PaperProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<PaperTypeModel> _paperTypes = [];
  List<PaperGsmModel> _paperGsms = [];
  List<PaperSizeModel> _paperSizes = [];
  List<PaperModel> _papers = [];
  List<PrintoutTypeModel> _printoutTypes = [];
  List<TaxModel> _taxes = [];
  List<RateModel> _rates = [];

  bool _isLoading = false;
  String? _errorMessage;

  List<PaperTypeModel> get paperTypes => _paperTypes;
  List<PaperGsmModel> get paperGsms => _paperGsms;
  List<PaperSizeModel> get paperSizes => _paperSizes;
  List<PaperModel> get papers => _papers;
  List<PrintoutTypeModel> get printoutTypes => _printoutTypes;
  List<TaxModel> get taxes => _taxes;
  List<RateModel> get rates => _rates;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAllMasters() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.wait([
      fetchPaperTypes(),
      fetchPaperGsms(),
      fetchPaperSizes(),
      fetchPapers(),
      fetchPrintoutTypes(),
      fetchTaxes(),
      fetchRates(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchPaperTypes() async {
    final res = await _api.get<List<PaperTypeModel>>(ApiEndpoints.paperTypes, parser: (j) => (j as List).map((i) => PaperTypeModel.fromJson(i)).toList());
    if (res.success && res.data != null) _paperTypes = res.data!;
  }

  Future<void> fetchPaperGsms() async {
    final res = await _api.get<List<PaperGsmModel>>(ApiEndpoints.paperGsm, parser: (j) => (j as List).map((i) => PaperGsmModel.fromJson(i)).toList());
    if (res.success && res.data != null) _paperGsms = res.data!;
  }

  Future<void> fetchPaperSizes() async {
    final res = await _api.get<List<PaperSizeModel>>(ApiEndpoints.paperSizes, parser: (j) => (j as List).map((i) => PaperSizeModel.fromJson(i)).toList());
    if (res.success && res.data != null) _paperSizes = res.data!;
  }

  Future<void> fetchPapers() async {
    final res = await _api.get<List<PaperModel>>(ApiEndpoints.papers, parser: (j) => (j as List).map((i) => PaperModel.fromJson(i)).toList());
    if (res.success && res.data != null) _papers = res.data!;
  }

  Future<void> fetchPrintoutTypes() async {
    final res = await _api.get<List<PrintoutTypeModel>>(ApiEndpoints.printoutTypes, parser: (j) => (j as List).map((i) => PrintoutTypeModel.fromJson(i)).toList());
    if (res.success && res.data != null) _printoutTypes = res.data!;
  }

  Future<void> fetchTaxes() async {
    final res = await _api.get<List<TaxModel>>(ApiEndpoints.taxes, parser: (j) => (j as List).map((i) => TaxModel.fromJson(i)).toList());
    if (res.success && res.data != null) _taxes = res.data!;
  }

  Future<void> fetchRates() async {
    final res = await _api.get<List<RateModel>>(ApiEndpoints.rates, parser: (j) => (j as List).map((i) => RateModel.fromJson(i)).toList());
    if (res.success && res.data != null) _rates = res.data!;
  }

  /// Rate Lookup from database
  Future<RateModel?> lookupRate(int paperId, int printoutTypeId) async {
    final url = '${ApiEndpoints.rateLookup}?paper_id=$paperId&printout_type_id=$printoutTypeId';
    final res = await _api.get<RateModel>(url, parser: (j) => RateModel.fromJson(j));
    if (res.success && res.data != null) {
      return res.data;
    }
    _errorMessage = res.message;
    notifyListeners();
    return null;
  }

  // Master Creation & Update Handlers
  Future<bool> createPaperType(PaperTypeModel type) async {
    final res = await _api.post<PaperTypeModel>(ApiEndpoints.paperTypes, type.toJson(), parser: (j) => PaperTypeModel.fromJson(j));
    if (res.success) { await fetchPaperTypes(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> updatePaperType(int id, PaperTypeModel type) async {
    final res = await _api.put<PaperTypeModel>('${ApiEndpoints.paperTypes}/$id', type.toJson(), parser: (j) => PaperTypeModel.fromJson(j));
    if (res.success) { await fetchPaperTypes(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> createPaperGsm(PaperGsmModel gsm) async {
    final res = await _api.post<PaperGsmModel>(ApiEndpoints.paperGsm, gsm.toJson(), parser: (j) => PaperGsmModel.fromJson(j));
    if (res.success) { await fetchPaperGsms(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> updatePaperGsm(int id, PaperGsmModel gsm) async {
    final res = await _api.put<PaperGsmModel>('${ApiEndpoints.paperGsm}/$id', gsm.toJson(), parser: (j) => PaperGsmModel.fromJson(j));
    if (res.success) { await fetchPaperGsms(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> createPaperSize(PaperSizeModel size) async {
    final res = await _api.post<PaperSizeModel>(ApiEndpoints.paperSizes, size.toJson(), parser: (j) => PaperSizeModel.fromJson(j));
    if (res.success) { await fetchPaperSizes(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> updatePaperSize(int id, PaperSizeModel size) async {
    final res = await _api.put<PaperSizeModel>('${ApiEndpoints.paperSizes}/$id', size.toJson(), parser: (j) => PaperSizeModel.fromJson(j));
    if (res.success) { await fetchPaperSizes(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> createPaper(PaperModel paper) async {
    final res = await _api.post<PaperModel>(ApiEndpoints.papers, paper.toJson(), parser: (j) => PaperModel.fromJson(j));
    if (res.success) { await fetchPapers(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> createPrintoutType(PrintoutTypeModel pt) async {
    final res = await _api.post<PrintoutTypeModel>(ApiEndpoints.printoutTypes, pt.toJson(), parser: (j) => PrintoutTypeModel.fromJson(j));
    if (res.success) { await fetchPrintoutTypes(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> updatePrintoutType(int id, PrintoutTypeModel pt) async {
    final res = await _api.put<PrintoutTypeModel>('${ApiEndpoints.printoutTypes}/$id', pt.toJson(), parser: (j) => PrintoutTypeModel.fromJson(j));
    if (res.success) { await fetchPrintoutTypes(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> createTax(TaxModel tax) async {
    final res = await _api.post<TaxModel>(ApiEndpoints.taxes, tax.toJson(), parser: (j) => TaxModel.fromJson(j));
    if (res.success) { await fetchTaxes(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> createRate(RateModel rate) async {
    final res = await _api.post<RateModel>(ApiEndpoints.rates, rate.toJson(), parser: (j) => RateModel.fromJson(j));
    if (res.success) { await fetchRates(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }

  Future<bool> updateRate(int id, RateModel rate) async {
    final res = await _api.put<RateModel>("${ApiEndpoints.rates}/$id", rate.toJson(), parser: (j) => RateModel.fromJson(j));
    if (res.success) { await fetchRates(); return true; }
    _errorMessage = res.message; notifyListeners(); return false;
  }
}