<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use PDO;
use Throwable;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ReportController
{
    public function getDailySalesReport(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $startDate = $queryParams['start_date'] ?? date('Y-m-01');
        $endDate = $queryParams['end_date'] ?? date('Y-m-d');
        $customerId = $queryParams['customer_id'] ?? null;
          $params = [];
        $sql = '
          SELECT 
          b.id AS bill_id,
          b.bill_number,
          b.bill_date,
          b.customer_id,
          c.customer_name,
          CAST(b.subtotal AS DOUBLE) AS subtotal,
          CAST(b.cgst_amount AS DOUBLE) AS cgst_amount,
          CAST(b.sgst_amount AS DOUBLE) AS sgst_amount,
          CAST(b.igst_amount AS DOUBLE) AS igst_amount,
          CAST(b.round_off AS DOUBLE) AS round_off,
          CAST(b.grand_total AS DOUBLE) AS grand_total,
          CAST(b.paid_amount AS DOUBLE) AS paid_amount,
          CAST(b.balance_amount AS DOUBLE) AS balance_amount,
          b.status
          FROM sales_bills b
          JOIN customers c ON b.customer_id = c.id
          WHERE c.is_estimate = 0 
          ';

        if ($startDate) {
          $sql .= ' AND b.bill_date >= ?';
          $params[] = $startDate;
        }
        if ($endDate) {
          $sql .= ' AND b.bill_date <= ?';
          $params[] = $endDate;
        }
        if ($customerId) {
          $sql .= ' AND b.customer_id = ?';
          $params[] = $customerId;
        }
        $sql .= ' ORDER BY b.bill_date DESC, b.id DESC';

        $report = Database::fetchAll($sql, $params);

        // $summary = Database::fetchOne('
        //   SELECT 
        //     COUNT(b.id) AS total_invoices,
        //     SUM(b.grand_total) AS total_sales_amount,
        //     SUM(b.paid_amount) AS total_collected_amount,
        //     SUM(b.balance_amount) AS total_outstanding_amount
        //   FROM sales_bills b
        //   WHERE b.bill_date >= ? AND b.bill_date <= ?
        // ', [$startDate, $endDate]);

        $totalSubtotal = 0;
        $totalCgst = 0;
        $totalSgst = 0;
        $totalIgst = 0;
        $totalRoundOff = 0;
        $grandTotal = 0;
        $totalPaid = 0;
        $totalOutstanding = 0;

        foreach ($report as $row) {
            $totalSubtotal += (float)($row['subtotal'] ?? 0);
            $totalCgst += (float)($row['cgst_amount'] ?? 0);
            $totalSgst += (float)($row['sgst_amount'] ?? 0);
            $totalIgst += (float)($row['igst_amount'] ?? 0);
            $totalRoundOff += (float)($row['round_off'] ?? 0);
            $grandTotal += (float)($row['grand_total'] ?? 0);
            $totalPaid += (float)($row['paid_amount'] ?? 0);
            $totalOutstanding += (float)($row['balance_amount'] ?? 0);
        }

        $summary = [
            'total_bills' => count($report),
            'total_subtotal' => $totalSubtotal,
            'total_cgst' => $totalCgst,
            'total_sgst' => $totalSgst,
            'total_igst' => $totalIgst,
            'total_round_off' => $totalRoundOff,
            'grand_total' => $grandTotal,
            'total_paid' => $totalPaid,
            'total_outstanding' => $totalOutstanding
        ];

        return ResponseHelper::sendSuccess($response, [
            'bills' => $report,
            'summary' => $summary
        ], 'Daily sales report generated successfully');
    }

    public function getCustomerWiseReport(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $startDate = $queryParams['start_date'] ?? date('Y-01-01');
        $endDate = $queryParams['end_date'] ?? date('Y-m-d');

        $sql = '
          SELECT 
        c.id AS customer_id,
        c.customer_name,
        c.phone,
        c.email,
        c.advance_balance,
        COUNT(b.id) AS bill_count,
        CAST(SUM(b.subtotal) AS DOUBLE) AS total_subtotal,
        CAST(SUM(b.cgst_amount) AS DOUBLE) AS total_cgst,
        CAST(SUM(b.sgst_amount) AS DOUBLE) AS total_sgst,
        CAST(SUM(b.igst_amount) AS DOUBLE) AS total_igst,
        CAST(SUM(b.round_off) AS DOUBLE) AS total_round_off,
        CAST(SUM(b.grand_total) AS DOUBLE) AS total_billed,
        CAST(SUM(b.paid_amount) AS DOUBLE) AS total_paid,
        CAST(SUM(b.balance_amount) AS DOUBLE) AS total_outstanding
      FROM customers c
      LEFT JOIN sales_bills b ON c.id = b.customer_id
      WHERE c.is_estimate = 0
      GROUP BY c.id
      ORDER BY total_outstanding DESC, c.customer_name ASC
        ';
        $report = Database::fetchAll($sql);

        return ResponseHelper::sendSuccess($response, $report, 'Customer-wise sales report generated successfully');
    }

    public function getSupplierPurchasesReport(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $startDate = $queryParams['start_date'] ?? date('Y-01-01');
        $endDate = $queryParams['end_date'] ?? date('Y-m-d');

        $sql = '
          SELECT 
            s.id AS supplier_id,
            s.supplier_name,
            COUNT(p.id) AS purchase_count,
            CAST(COALESCE(SUM(p.subtotal), 0) AS DOUBLE) AS total_subtotal,
            CAST(COALESCE(SUM(p.cgst_amount), 0) AS DOUBLE) AS total_cgst,
            CAST(COALESCE(SUM(p.sgst_amount), 0) AS DOUBLE) AS total_sgst,
            CAST(COALESCE(SUM(p.igst_amount), 0) AS DOUBLE) AS total_igst,
            CAST(COALESCE(SUM(p.grand_total), 0) AS DOUBLE) AS grand_total,
            CAST(COALESCE(SUM(p.paid_amount), 0) AS DOUBLE) AS total_paid,
            CAST(COALESCE(SUM(p.balance_amount), 0) AS DOUBLE) AS total_outstanding
          FROM suppliers s
          LEFT JOIN supplier_purchases p ON s.id = p.supplier_id
          WHERE p.purchase_date >= ? AND p.purchase_date <= ?
          GROUP BY s.id
          ORDER BY grand_total DESC
        ';

        $report = Database::fetchAll($sql, [$startDate, $endDate]);

        return ResponseHelper::sendSuccess($response, $report, 'Supplier purchases report generated successfully');
    }

    public function getCustomerPendingReport(Request $request, Response $response): Response
    {
      $queryParams = $request->getQueryParams();
      $customerId = $queryParams['customer_id'] ?? null;
      $params = [];
      
        $sql = "
          SELECT 
            b.id AS bill_id,
            b.bill_number,
            b.bill_date,
            c.customer_name,
            c.phone AS customer_phone,
            b.grand_total,
            b.paid_amount,
            b.balance_amount,
            DATEDIFF(CURRENT_DATE, b.bill_date) AS days_pending,
            b.status
          FROM sales_bills b
          JOIN customers c ON b.customer_id = c.id
          WHERE c.is_estimate = 0 AND b.status IN ('UNPAID', 'PARTIAL')
        ";
        if ($customerId) {
          $sql .= ' AND b.customer_id = ?';
          $params[] = $customerId;
        }
        $sql .= ' ORDER BY days_pending DESC, b.bill_date ASC';
        $report = Database::fetchAll($sql, $params);

        return ResponseHelper::sendSuccess($response, $report, 'Customer pending report generated successfully');
    }

    public function getCustomerAgingReport(Request $request, Response $response): Response
    {
      $queryParams = $request->getQueryParams();
      $customerId = $queryParams['customer_id'] ?? null;
      $params = [];
      $sql = "
        SELECT 
        c.id AS customer_id,
        c.customer_name,
        c.phone,
        c.email,
        CAST(SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) BETWEEN 0 AND 30 THEN b.balance_amount ELSE 0 END) AS DOUBLE) AS bucket_0_30,
        CAST(SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) BETWEEN 31 AND 60 THEN b.balance_amount ELSE 0 END) AS DOUBLE) AS bucket_31_60,
        CAST(SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) BETWEEN 61 AND 90 THEN b.balance_amount ELSE 0 END) AS DOUBLE) AS bucket_61_90,
        CAST(SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) > 90 THEN b.balance_amount ELSE 0 END) AS DOUBLE) AS bucket_over_90,
        CAST(SUM(b.balance_amount) AS DOUBLE) AS total_outstanding
        FROM customers c
        JOIN sales_bills b ON c.id = b.customer_id
        WHERE c.is_estimate = 0 AND b.status IN ('UNPAID', 'PARTIAL')
      ";

      if ($customerId) {
        $sql .= ' AND b.customer_id = ?';
        $params[] = $customerId;
      }
      $sql .= ' GROUP BY c.id ORDER BY total_outstanding DESC';
      $report = Database::fetchAll($sql, $params);

      return ResponseHelper::sendSuccess($response, $report, 'Customer aging report generated successfully');
    }

    public function getStockReport(Request $request, Response $response): Response
    {
        $sql = '
                SELECT 
        p.id AS paper_id,
        p.paper_name,
        p.purchase_unit,
        p.opening_stock,
        COALESCE(SUM(sl.qty_in), 0) AS total_qty_in,
        COALESCE(SUM(sl.qty_out), 0) AS total_qty_out,
        p.current_stock,
        p.reorder_level
      FROM papers p
      LEFT JOIN stock_ledger sl ON p.id = sl.paper_id
      GROUP BY p.id
      ORDER BY p.paper_name ASC
        ';
        $rows = Database::fetchAll($sql);
        return ResponseHelper::sendSuccess($response, $rows, 'Stock status report fetched successfully');
    }

    public function getCustomerPaymentReport(Request $request, Response $response): Response
    {
        try {
    // Get customer_id from query parameters
    $customerId = $request->getQueryParams()['customer_id'] ?? null;

    if (!$customerId) {
        return ResponseHelper::sendError(
            $response,
            'customer_id query parameter is required'
        );
    }

    $db = Database::getConnection();

    // ---------------------------------------------------------
    // Get Customer
    // ---------------------------------------------------------
    $stmt = $db->prepare("
        SELECT 
            id,
            customer_name,
            phone,
            email,
            advance_balance
        FROM customers
        WHERE id = ?
    ");

    $stmt->execute([$customerId]);

    $customers = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (count($customers) === 0) {
        return ResponseHelper::sendError(
            $response,
            'Customer not found in Customer Master.',
            [],
            404
        );
    }

    $customer = $customers[0];

    // ---------------------------------------------------------
    // Get Customer Payments + Allocations
    // ---------------------------------------------------------
    $sql = "
        SELECT 
            p.id AS payment_id,
            p.payment_number,
            p.payment_date,
            p.amount AS payment_amount,
            p.allocated_amount AS total_payment_allocated,
            p.advance_credit_amount,
            p.payment_mode,
            p.reference_number,
            p.notes,

            pa.id AS allocation_id,
            pa.sales_bill_id,
            pa.allocated_amount AS bill_allocated_amount,

            b.bill_number,
            b.bill_date,
            b.grand_total AS bill_grand_total,
            b.paid_amount AS bill_paid_amount,
            b.balance_amount AS bill_balance_amount,
            b.status AS bill_status

        FROM customer_payments p

        LEFT JOIN payment_allocations pa 
            ON p.id = pa.payment_id

        LEFT JOIN sales_bills b 
            ON pa.sales_bill_id = b.id

        WHERE p.customer_id = ?

        ORDER BY 
            p.payment_date DESC,
            p.id DESC,
            pa.id ASC
    ";

    $stmt = $db->prepare($sql);
    $stmt->execute([$customerId]);

    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // ---------------------------------------------------------
    // Build Payments Map
    // ---------------------------------------------------------
    $paymentsMap = [];

    $totalPayments = 0;
    $totalAllocated = 0;

    foreach ($rows as $r) {

        $paymentId = $r['payment_id'];

        // Create payment only once
        if (!isset($paymentsMap[$paymentId])) {

            $paymentAmount = (float)($r['payment_amount'] ?? 0);

            $totalPayments += $paymentAmount;

            $paymentsMap[$paymentId] = [
                'id' => $paymentId,
                'payment_number' => $r['payment_number'],
                'payment_date' => $r['payment_date'],

                'amount' => $paymentAmount,

                'allocated_amount' =>
                    (float)($r['total_payment_allocated'] ?? 0),

                'advance_credit_amount' =>
                    (float)($r['advance_credit_amount'] ?? 0),

                'payment_mode' => $r['payment_mode'],
                'reference_number' => $r['reference_number'],
                'notes' => $r['notes'],

                'allocations' => []
            ];
        }

        // -----------------------------------------------------
        // Add Allocation
        // -----------------------------------------------------
        if (!empty($r['allocation_id'])) {

            $billAllocatedAmount =
                (float)($r['bill_allocated_amount'] ?? 0);

            $totalAllocated += $billAllocatedAmount;

            $paymentsMap[$paymentId]['allocations'][] = [
                'allocation_id' => $r['allocation_id'],

                'sales_bill_id' => $r['sales_bill_id'],

                'bill_number' => $r['bill_number'],

                'bill_date' => $r['bill_date'],

                'bill_grand_total' =>
                    (float)($r['bill_grand_total'] ?? 0),

                'bill_paid_amount' =>
                    (float)($r['bill_paid_amount'] ?? 0),

                'allocated_amount' =>
                    $billAllocatedAmount,

                'bill_balance_amount' =>
                    (float)($r['bill_balance_amount'] ?? 0),

                'bill_status' => $r['bill_status']
            ];
        }
    }

    // ---------------------------------------------------------
    // Convert associative map to indexed array
    // ---------------------------------------------------------
    $paymentsList = array_values($paymentsMap);

    // ---------------------------------------------------------
    // Summary
    // ---------------------------------------------------------
    $summary = [
        'total_payments' => $totalPayments,

        'total_allocated' => $totalAllocated,

        'advance_credit' =>
            (float)($customer['advance_balance'] ?? 0)
    ];

    // ---------------------------------------------------------
    // Success Response
    // ---------------------------------------------------------
    return ResponseHelper::sendSuccess(
        $response,
        [
            'customer' => $customer,
            'summary' => $summary,
            'payments' => $paymentsList
        ],
        'Customer payment report generated successfully'
    );

} catch (Throwable $err) {

    // Pass exception to Slim error handler
    throw $err;
}
    }
}
