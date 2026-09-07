// CHANGE-2026-09-07: Created ApiService client for communicating with Node.js REST API.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final List<dynamic> errors;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors = const [],
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic)? parseData) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null && parseData != null ? parseData(json['data']) : json['data'],
      errors: json['errors'] ?? [],
    );
  }
}

class ApiService {
  static String? bearerToken;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (bearerToken != null && bearerToken!.isNotEmpty)
      'Authorization': 'Bearer $bearerToken',
  };

  /// Performs GET request
  Future<ApiResponse<T>> get<T>(String endpoint, {T Function(dynamic)? parser}) async {
    try {
      debugPrint('[API GET] $endpoint');
      final response = await http.get(Uri.parse(endpoint), headers: _headers);
      return _processResponse<T>(response, parser);
    } catch (e) {
      debugPrint('[API GET ERROR] $e');
      return ApiResponse<T>(
        success: false,
        message: 'Network / Connection Failure: ${e.toString()}',
      );
    }
  }

  /// Performs POST request
  Future<ApiResponse<T>> post<T>(String endpoint, dynamic body, {T Function(dynamic)? parser}) async {
    try {
      debugPrint('[API POST] $endpoint');
      final response = await http.post(
        Uri.parse(endpoint),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _processResponse<T>(response, parser);
    } catch (e) {
      debugPrint('[API POST ERROR] $e');
      return ApiResponse<T>(
        success: false,
        message: 'Network / Connection Failure: ${e.toString()}',
      );
    }
  }

  /// Performs PUT request
  Future<ApiResponse<T>> put<T>(String endpoint, dynamic body, {T Function(dynamic)? parser}) async {
    try {
      debugPrint('[API PUT] $endpoint');
      final response = await http.put(
        Uri.parse(endpoint),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _processResponse<T>(response, parser);
    } catch (e) {
      debugPrint('[API PUT ERROR] $e');
      return ApiResponse<T>(
        success: false,
        message: 'Network / Connection Failure: ${e.toString()}',
      );
    }
  }

  /// Performs DELETE request
  Future<ApiResponse<T>> delete<T>(String endpoint, {T Function(dynamic)? parser}) async {
    try {
      debugPrint('[API DELETE] $endpoint');
      final response = await http.delete(Uri.parse(endpoint), headers: _headers);
      return _processResponse<T>(response, parser);
    } catch (e) {
      debugPrint('[API DELETE ERROR] $e');
      return ApiResponse<T>(
        success: false,
        message: 'Network / Connection Failure: ${e.toString()}',
      );
    }
  }

  ApiResponse<T> _processResponse<T>(http.Response response, T Function(dynamic)? parser) {
    try {
      final jsonBody = jsonDecode(response.body);
      return ApiResponse<T>.fromJson(jsonBody, parser);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: 'Server returned invalid response format (${response.statusCode})',
      );
    }
  }
}
