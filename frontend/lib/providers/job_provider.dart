// CHANGE-2026-09-08: Created Job Provider for managing Estimate / Job Customers without tax.

import 'package:flutter/foundation.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class JobProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<JobModel> _jobs = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<JobModel> get jobs => _jobs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchJobs() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiEndpoints.jobs);
      if (response.success && response.data != null) {
        final List data = response.data;
        _jobs = data.map((j) => JobModel.fromJson(j)).toList();
      } else {
        _errorMessage = response.message;
      }
    } catch (e) {
      _errorMessage = 'Error fetching jobs: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<JobModel?> createJob(JobModel job) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(ApiEndpoints.jobs, job.toJson());
      if (response.success && response.data != null) {
        await fetchJobs();
        final created = JobModel.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return created;
      } else {
        _errorMessage = response.message ?? 'Failed to create job';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error creating job: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> printJob(int id) async {
    try {
      final response = await _apiService.post(ApiEndpoints.jobPrint(id), {});
      if (response.success) {
        return true;
      } else {
        _errorMessage = response.message ?? 'Printing failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Printing error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> emailJob(int id) async {
    try {
      final response = await _apiService.post(ApiEndpoints.jobEmail(id), {});
      if (response.success) {
        return true;
      } else {
        _errorMessage = response.message ?? 'Email dispatch failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Email error: $e';
      notifyListeners();
      return false;
    }
  }
}
