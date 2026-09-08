// CHANGE-2026-09-07: Created API Endpoints configuration for Flutter REST communication.

class ApiEndpoints {
  // Base URL configured for Local Backend (supports Web, Windows Desktop, Android Emulator)
  // For Android Emulator, host '10.0.2.2' is used automatically if running on Android emulator.
  static String baseUrl = 'http://localhost:9002/api';

  static String company = '$baseUrl/company';
  static String customers = '$baseUrl/customers';
  static String suppliers = '$baseUrl/suppliers';
  static String paperTypes = '$baseUrl/paper-types';
  static String paperGsm = '$baseUrl/paper-gsm';
  static String paperSizes = '$baseUrl/paper-sizes';
  static String papers = '$baseUrl/papers';
  static String printoutTypes = '$baseUrl/printout-types';
  static String taxes = '$baseUrl/taxes';
  static String rates = '$baseUrl/rates';
  static String rateLookup = '$baseUrl/rates/lookup';
  static String salesBills = '$baseUrl/sales-bills';
  static String customerPayments = '$baseUrl/customer-payments';
  static String pendingBills(int customerId) => '$baseUrl/customer-payments/pending-bills/$customerId';
  static String purchases = '$baseUrl/purchases';
  static String stockSummary = '$baseUrl/stock/summary';
  static String stockLedger = '$baseUrl/stock/ledger';
  static String stockAdjust = '$baseUrl/stock/adjust';

  // Reports
  static String reportDailySales = '$baseUrl/reports/daily-sales';
  static String reportCustomerWise = '$baseUrl/reports/customer-wise';
  static String reportSupplierPurchases = '$baseUrl/reports/supplier-purchases';
  static String reportCustomerPending = '$baseUrl/reports/customer-pending';
  static String reportCustomerAging = '$baseUrl/reports/customer-aging';
  static String reportStock = '$baseUrl/reports/stock';

  // Authentication
  static String authLogin = '$baseUrl/auth/login';
  static String authMe = '$baseUrl/auth/me';

  // Printer Settings
  static String printerSettings = '$baseUrl/settings/printer';
  static String testPrinter = '$baseUrl/settings/printer/test';
  static String printReceipt = '$baseUrl/settings/printer/print-receipt';

  // Job Estimates (Estimate Customers)
  static String jobs = '$baseUrl/jobs';
  static String jobPrint(int id) => '$baseUrl/jobs/$id/print';
  static String jobEmail(int id) => '$baseUrl/jobs/$id/email';
  static String jobPdf(int id) => '$baseUrl/jobs/$id/pdf';
}
