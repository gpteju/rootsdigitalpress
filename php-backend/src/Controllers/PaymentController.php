<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class PaymentController
{
    public function getPayments(Request $request, Response $response): Response
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
            $allocations = Database::fetchAll('
                SELECT pa.*, b.bill_number, b.bill_date, b.grand_total
                FROM payment_allocations pa
                JOIN sales_bills b ON pa.sales_bill_id = b.id
                WHERE pa.customer_payment_id = ?
            ', [$pmt['id']]);
            $pmt['allocations'] = $allocations;
        }

        return ResponseHelper::sendSuccess($response, $payments, 'Customer payments fetched successfully');
    }

    public function getCustomerPendingBills(Request $request, Response $response, array $args): Response
    {
        $customerId = (int)$args['customerId'];
        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$customerId]);
        if (!$customer) {
            return ResponseHelper::sendError($response, 'Customer not found', [], 404);
        }

        $sql = "
          SELECT id, bill_number, bill_date, grand_total, paid_amount, balance_amount, payment_status
          FROM sales_bills
          WHERE customer_id = ? AND payment_status != 'PAID'
          ORDER BY bill_date ASC, id ASC
        ";
        $pendingBills = Database::fetchAll($sql, [$customerId]);

        return ResponseHelper::sendSuccess($response, [
            'customer' => $customer,
            'pending_bills' => $pendingBills
        ], 'Customer pending bills fetched successfully');
    }

    public function processPayment(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $customerId = $body['customer_id'] ?? null;
        $paymentDate = $body['payment_date'] ?? null;
        $paymentMode = $body['payment_mode'] ?? 'CASH';
        $paidAmount = (float)($body['amount'] ?? $body['paid_amount'] ?? 0);
        $referenceNumber = $body['reference_number'] ?? null;
        $notes = $body['notes'] ?? null;

        if (!$customerId || !$paymentDate || $paidAmount <= 0) {
            return ResponseHelper::sendError($response, 'customer_id, payment_date, and positive amount are required', [], 400);
        }

        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$customerId]);
        if (!$customer) {
            return ResponseHelper::sendError($response, 'Customer not found', [], 404);
        }

        $currentAdvanceCredit = (float)($customer['advance_credit'] ?? 0);
        $totalAvailableFunds = $paidAmount + $currentAdvanceCredit;

        $pendingBills = Database::fetchAll("
            SELECT * FROM sales_bills
            WHERE customer_id = ? AND payment_status != 'PAID'
            ORDER BY bill_date ASC, id ASC
        ", [$customerId]);

        $resultData = Database::withTransaction(function ($pdo) use (
            $customerId, $paymentDate, $paymentMode, $paidAmount, $referenceNumber, 
            $notes, $currentAdvanceCredit, $totalAvailableFunds, $pendingBills
        ) {
            $cntStmt = $pdo->query('SELECT COUNT(id) AS cnt FROM customer_payments');
            $cntRow = $cntStmt->fetch();
            $seq = str_pad((int)$cntRow['cnt'] + 1, 4, '0', STR_PAD_LEFT);
            $receiptNo = "REC-" . date('Y') . "-{$seq}";

            $pmtStmt = $pdo->prepare('
                INSERT INTO customer_payments 
                  (receipt_number, payment_date, customer_id, payment_mode, amount, reference_number, notes)
                 VALUES (?, ?, ?, ?, ?, ?, ?)
            ');
            $pmtStmt->execute([
                $receiptNo,
                $paymentDate,
                $customerId,
                $paymentMode,
                $paidAmount,
                $referenceNumber,
                $notes
            ]);
            $paymentId = $pdo->lastInsertId();

            $remainingFunds = $totalAvailableFunds;
            $allocationsCreated = [];

            $billUpdateStmt = $pdo->prepare('
                UPDATE sales_bills SET paid_amount = ?, balance_amount = ?, payment_status = ? WHERE id = ?
            ');
            $allocStmt = $pdo->prepare('
                INSERT INTO payment_allocations (customer_payment_id, sales_bill_id, allocated_amount) VALUES (?, ?, ?)
            ');

            foreach ($pendingBills as $bill) {
                if ($remainingFunds <= 0) break;

                $currentBal = (float)$bill['balance_amount'];
                if ($currentBal <= 0) continue;

                $allocation = min($remainingFunds, $currentBal);
                $newPaid = (float)$bill['paid_amount'] + $allocation;
                $newBal = $currentBal - $allocation;
                $newStatus = ($newBal <= 0) ? 'PAID' : 'PARTIAL';

                $billUpdateStmt->execute([$newPaid, max(0, $newBal), $newStatus, $bill['id']]);
                $allocStmt->execute([$paymentId, $bill['id'], $allocation]);

                $remainingFunds -= $allocation;

                $allocationsCreated[] = [
                    'sales_bill_id' => $bill['id'],
                    'bill_number' => $bill['bill_number'],
                    'allocated_amount' => $allocation,
                    'new_balance' => max(0, $newBal),
                    'payment_status' => $newStatus
                ];
            }

            $newAdvanceCredit = max(0, $remainingFunds);
            $custUpdateStmt = $pdo->prepare('UPDATE customers SET advance_credit = ? WHERE id = ?');
            $custUpdateStmt->execute([$newAdvanceCredit, $customerId]);

            $fetchStmt = $pdo->prepare('SELECT * FROM customer_payments WHERE id = ?');
            $fetchStmt->execute([$paymentId]);
            $paymentRecord = $fetchStmt->fetch();
            $paymentRecord['allocations'] = $allocationsCreated;
            $paymentRecord['advance_credit_remaining'] = $newAdvanceCredit;

            return $paymentRecord;
        });

        return ResponseHelper::sendSuccess($response, $resultData, 'Payment processed and allocated successfully', 201);
    }
}
