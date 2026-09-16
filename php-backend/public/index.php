<?php

require __DIR__ . '/../vendor/autoload.php';

use Dotenv\Dotenv;
use Slim\Factory\AppFactory;
use Slim\Routing\RouteCollectorProxy;
use App\Helpers\ResponseHelper;
use App\Middleware\AuthMiddleware;
use App\Controllers\AuthController;
use App\Controllers\CompanyController;
use App\Controllers\CustomerController;
use App\Controllers\SupplierController;
use App\Controllers\PaperMastersController;
use App\Controllers\PrintoutTypeController;
use App\Controllers\TaxController;
use App\Controllers\RateController;
use App\Controllers\SalesBillController;
use App\Controllers\PaymentController;
use App\Controllers\PurchaseController;
use App\Controllers\StockController;
use App\Controllers\ReportController;
use App\Controllers\SettingsController;
use App\Controllers\JobController;

// Load Environment Variables from .env
if (file_exists(__DIR__ . '/../.env')) {
    $dotenv = Dotenv::createImmutable(__DIR__ . '/..');
    $dotenv->safeLoad();
}

$app = AppFactory::create();

// Parse JSON Body & Form Data
$app->addBodyParsingMiddleware();

// CORS Headers Middleware
$app->add(function ($request, $handler) {
    $response = $handler->handle($request);
    return $response
        ->withHeader('Access-Control-Allow-Origin', '*')
        ->withHeader('Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Accept, Origin, Authorization')
        ->withHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
});

// OPTIONS Preflight Handler
$app->options('/{routes:.+}', function ($request, $response) {
    return $response;
});

// Health Check Endpoint (Public)
$app->get('/api/health', function ($request, $response) {
    return ResponseHelper::sendSuccess($response, [
        'status' => 'UP',
        'timestamp' => date('c')
    ], 'Printout Billing PHP Slim API Server is running');
});

// Public Auth Login Endpoint
$app->post('/api/auth/login', [AuthController::class, 'login']);

// Protected API Routes Group (Guard with JWT Auth Middleware)
$app->group('/api', function (RouteCollectorProxy $group) {
    // Auth Profile
    $group->get('/auth/me', [AuthController::class, 'getMe']);

    // Company Master
    $group->get('/company', [CompanyController::class, 'getCompany']);
    $group->post('/company', [CompanyController::class, 'saveCompany']);
    $group->put('/company', [CompanyController::class, 'saveCompany']);

    // Customers Master
    $group->get('/customers', [CustomerController::class, 'getAll']);
    $group->get('/customers/{id}', [CustomerController::class, 'getById']);
    $group->post('/customers', [CustomerController::class, 'create']);
    $group->put('/customers/{id}', [CustomerController::class, 'update']);
    $group->delete('/customers/{id}', [CustomerController::class, 'delete']);

    // Suppliers Master
    $group->get('/suppliers', [SupplierController::class, 'getAll']);
    $group->get('/suppliers/{id}', [SupplierController::class, 'getById']);
    $group->post('/suppliers', [SupplierController::class, 'create']);
    $group->put('/suppliers/{id}', [SupplierController::class, 'update']);
    $group->delete('/suppliers/{id}', [SupplierController::class, 'delete']);

    // Paper Types Master
    $group->get('/paper-types', [PaperMastersController::class, 'getPaperTypes']);
    $group->post('/paper-types', [PaperMastersController::class, 'createPaperType']);
    $group->put('/paper-types/{id}', [PaperMastersController::class, 'updatePaperType']);

    // Paper GSM Master
    $group->get('/paper-gsm', [PaperMastersController::class, 'getPaperGsm']);
    $group->post('/paper-gsm', [PaperMastersController::class, 'createPaperGsm']);
    $group->put('/paper-gsm/{id}', [PaperMastersController::class, 'updatePaperGsm']);

    // Paper Sizes Master
    $group->get('/paper-sizes', [PaperMastersController::class, 'getPaperSizes']);
    $group->post('/paper-sizes', [PaperMastersController::class, 'createPaperSize']);
    $group->put('/paper-sizes/{id}', [PaperMastersController::class, 'updatePaperSize']);

    // Unified Papers Master
    $group->get('/papers', [PaperMastersController::class, 'getAllPapers']);
    $group->post('/papers', [PaperMastersController::class, 'createPaper']);
    $group->put('/papers/{id}', [PaperMastersController::class, 'updatePaper']);

    // Printout Types Master
    $group->get('/printout-types', [PrintoutTypeController::class, 'getPrintoutTypes']);
    $group->post('/printout-types', [PrintoutTypeController::class, 'createPrintoutType']);
    $group->put('/printout-types/{id}', [PrintoutTypeController::class, 'updatePrintoutType']);

    // Tax Master
    $group->get('/taxes', [TaxController::class, 'getTaxes']);
    $group->get('/taxes/{id}', [TaxController::class, 'getTaxById']);
    $group->post('/taxes', [TaxController::class, 'createTax']);
    $group->put('/taxes/{id}', [TaxController::class, 'updateTax']);

    // Rates Master
    $group->get('/rates/lookup', [RateController::class, 'lookupRate']);
    $group->get('/rates', [RateController::class, 'getRates']);
    $group->post('/rates', [RateController::class, 'createRate']);
    $group->put('/rates/{id}', [RateController::class, 'updateRate']);

    // Sales Billing
    $group->get('/sales-bills', [SalesBillController::class, 'getSalesBills']);
    $group->get('/sales-bills/{id}', [SalesBillController::class, 'getSalesBillById']);
    $group->post('/sales-bills', [SalesBillController::class, 'createSalesBill']);
    $group->get('/sales-bills/{id}/pdf', [SalesBillController::class, 'generateBillPdf']);
    $group->post('/sales-bills/{id}/email', [SalesBillController::class, 'emailBillPdf']);
    $group->post('/sales-bills/{id}/print', [SalesBillController::class, 'printSalesBill']);

    // Customer Payments
    $group->get('/customer-payments', [PaymentController::class, 'getPayments']);
    $group->get('/customer-payments/pending-bills/{customerId}', [PaymentController::class, 'getCustomerPendingBills']);
    $group->post('/customer-payments', [PaymentController::class, 'processPayment']);

    // Supplier Purchases
    $group->get('/purchases', [PurchaseController::class, 'getPurchases']);
    $group->get('/purchases/{id}', [PurchaseController::class, 'getPurchaseById']);
    $group->post('/purchases', [PurchaseController::class, 'createPurchase']);

    // Stock Ledger
    $group->get('/stock/summary', [StockController::class, 'getStockSummary']);
    $group->get('/stock/ledger', [StockController::class, 'getStockLedger']);
    $group->post('/stock/adjust', [StockController::class, 'adjustStock']);

    // Reports Engine
    $group->get('/reports/daily-sales', [ReportController::class, 'getDailySalesReport']);
    $group->get('/reports/customer-wise', [ReportController::class, 'getCustomerWiseReport']);
    $group->get('/reports/supplier-purchases', [ReportController::class, 'getSupplierPurchasesReport']);
    $group->get('/reports/customer-pending', [ReportController::class, 'getCustomerPendingReport']);
    $group->get('/reports/customer-aging', [ReportController::class, 'getCustomerAgingReport']);
    $group->get('/reports/stock', [ReportController::class, 'getStockReport']);
    $group->get('/reports/customer-payment', [ReportController::class, 'getCustomerPaymentReport']);

    // Printer Settings
    $group->get('/settings/printer', [SettingsController::class, 'getPrinterSettings']);
    $group->post('/settings/printer', [SettingsController::class, 'updatePrinterSettings']);
    $group->post('/settings/printer/test', [SettingsController::class, 'testPrinter']);
    $group->post('/settings/printer/print-receipt', [SettingsController::class, 'printReceipt']);

    // Job Details
    $group->get('/jobs', [JobController::class, 'getJobs']);
    $group->get('/jobs/{id}', [JobController::class, 'getJobById']);
    $group->post('/jobs', [JobController::class, 'createJob']);
    $group->get('/jobs/{id}/pdf', [JobController::class, 'generateJobPdf']);
    $group->post('/jobs/{id}/email', [JobController::class, 'emailJobPdf']);
    $group->post('/jobs/{id}/print', [JobController::class, 'printJob']);

})->add(new AuthMiddleware());

// Global 404 Route Handler
$app->map(['GET', 'POST', 'PUT', 'DELETE', 'PATCH'], '/{routes:.+}', function ($request, $response) {
    return ResponseHelper::sendError($response, 'Route not found', [], 404);
});

$app->run();
