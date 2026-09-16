<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class ReportController
{
    public function getDailySalesReport(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $startDate = $queryParams['start_date'] ?? date('Y-m-01');
        $endDate = $queryParams['end_date'] ?? date('Y-m-d');

        $sql = '
          SELECT 
            b.bill_date,
            COUNT(b.id) AS total_bills,
            SUM(b.subtotal) AS subtotal_sum,
            SUM(b.cgst_amount) AS cgst_sum,
            SUM(b.sgst_amount) AS sgst_sum,
            SUM(b.igst_amount) AS igst_sum,
            SUM(b.grand_total) AS grand_total_sum,
            SUM(b.paid_amount) AS paid_sum,
            SUM(b.balance_amount) AS balance_sum
          FROM sales_bills b
          WHERE b.bill_date >= ? AND b.bill_date <= ?
          GROUP BY b.bill_date
          ORDER BY b.bill_date ASC
        ';
        $report = Database::fetchAll($sql, [$startDate, $endDate]);

        $summary = Database::fetchOne('
          SELECT 
            COUNT(b.id) AS total_invoices,
            SUM(b.grand_total) AS total_sales_amount,
            SUM(b.paid_amount) AS total_collected_amount,
            SUM(b.balance_amount) AS total_outstanding_amount
          FROM sales_bills b
          WHERE b.bill_date >= ? AND b.bill_date <= ?
        ', [$startDate, $endDate]);

        return ResponseHelper::sendSuccess($response, [
            'daily_breakdown' => $report,
            'summary' => $summary ?: [
                'total_invoices' => 0,
                'total_sales_amount' => 0.00,
                'total_collected_amount' => 0.00,
                'total_outstanding_amount' => 0.00
            ]
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
            COUNT(b.id) AS total_bills,
            SUM(b.grand_total) AS total_billed_amount,
            SUM(b.paid_amount) AS total_paid_amount,
            SUM(b.balance_amount) AS total_balance_amount
          FROM customers c
          JOIN sales_bills b ON b.customer_id = c.id
          WHERE b.bill_date >= ? AND b.bill_date <= ?
          GROUP BY c.id, c.customer_name, c.phone
          ORDER BY total_billed_amount DESC
        ';
        $report = Database::fetchAll($sql, [$startDate, $endDate]);

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
            s.phone,
            COUNT(p.id) AS total_purchases,
            SUM(p.grand_total) AS total_purchase_amount,
            SUM(p.paid_amount) AS total_paid_amount,
            SUM(p.balance_amount) AS total_balance_amount
          FROM suppliers s
          JOIN supplier_purchases p ON p.supplier_id = s.id
          WHERE p.purchase_date >= ? AND p.purchase_date <= ?
          GROUP BY s.id, s.supplier_name, s.phone
          ORDER BY total_purchase_amount DESC
        ';
        $report = Database::fetchAll($sql, [$startDate, $endDate]);

        return ResponseHelper::sendSuccess($response, $report, 'Supplier purchases report generated successfully');
    }

    public function getCustomerPendingReport(Request $request, Response $response): Response
    {
        $sql = "
          SELECT 
            c.id AS customer_id,
            c.customer_name,
            c.phone,
            c.email,
            COUNT(b.id) AS pending_bills_count,
            SUM(b.balance_amount) AS total_pending_amount
          FROM customers c
          JOIN sales_bills b ON b.customer_id = c.id
          WHERE b.status != 'PAID' AND b.balance_amount > 0
          GROUP BY c.id, c.customer_name, c.phone, c.email
          ORDER BY total_pending_amount DESC
        ";
        $report = Database::fetchAll($sql);

        return ResponseHelper::sendSuccess($response, $report, 'Customer pending report generated successfully');
    }

    public function getCustomerAgingReport(Request $request, Response $response): Response
    {
        $sql = "
          SELECT 
            c.id AS customer_id,
            c.customer_name,
            c.phone,
            SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) <= 30 THEN b.balance_amount ELSE 0 END) AS aging_0_30,
            SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) BETWEEN 31 AND 60 THEN b.balance_amount ELSE 0 END) AS aging_31_60,
            SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) BETWEEN 61 AND 90 THEN b.balance_amount ELSE 0 END) AS aging_90_plus,
            SUM(CASE WHEN DATEDIFF(CURRENT_DATE, b.bill_date) > 90 THEN b.balance_amount ELSE 0 END) AS aging_90_plus,
            SUM(b.balance_amount) AS total_outstanding
          FROM customers c
          JOIN sales_bills b ON b.customer_id = c.id
          WHERE b.status != 'PAID' AND b.balance_amount > 0
          GROUP BY c.id, c.customer_name, c.phone
          ORDER BY total_outstanding DESC
        ";
        $report = Database::fetchAll($sql);

        return ResponseHelper::sendSuccess($response, $report, 'Customer aging report generated successfully');
    }

    public function getStockReport(Request $request, Response $response): Response
    {
        $sql = '
          SELECT 
            p.id AS paper_id,
            p.paper_name,
            pt.name AS paper_type_name,
            pg.gsm_value,
            ps.name AS paper_size_name,
            p.purchase_unit,
            p.opening_stock,
            p.current_stock,
            p.reorder_level,
            CASE WHEN p.current_stock <= p.reorder_level THEN 1 ELSE 0 END AS is_low_stock
          FROM papers p
          JOIN paper_types pt ON p.paper_type_id = pt.id
          JOIN paper_gsm pg ON p.paper_gsm_id = pg.id
          JOIN paper_sizes ps ON p.paper_size_id = ps.id
          ORDER BY p.paper_name ASC
        ';
        $rows = Database::fetchAll($sql);
        return ResponseHelper::sendSuccess($response, $rows, 'Stock status report fetched successfully');
    }

    public function getCustomerPaymentReport(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $customerId = $queryParams['customer_id'] ?? null;
        $startDate = $queryParams['start_date'] ?? null;
        $endDate = $queryParams['end_date'] ?? null;

        $sql = '
          SELECT 
            p.*,
            c.customer_name,
            c.customer_type
          FROM customer_payments p
          JOIN customers c ON p.customer_id = c.id
          WHERE 1=1
        ';
        $params = [];

        if (!empty($customerId)) {
            $sql .= ' AND p.customer_id = ?';
            $params[] = $customerId;
        }
        if (!empty($startDate)) {
            $sql .= ' AND p.payment_date >= ?';
            $params[] = $startDate;
        }
        if (!empty($endDate)) {
            $sql .= ' AND p.payment_date <= ?';
            $params[] = $endDate;
        }

        $sql .= ' ORDER BY p.id DESC';
        $payments = Database::fetchAll($sql, $params);

        foreach ($payments as &$pmt) {
            $pmt['allocations'] = Database::fetchAll('
                SELECT pa.*, b.bill_number, b.bill_date, b.grand_total
                FROM payment_allocations pa
                JOIN sales_bills b ON pa.sales_bill_id = b.id
                WHERE pa.customer_payment_id = ?
            ', [$pmt['id']]);
        }

        return ResponseHelper::sendSuccess($response, $payments, 'Customer payment report fetched successfully');
    }
}
