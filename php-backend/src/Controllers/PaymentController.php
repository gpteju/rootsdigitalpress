<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class PaymentController
{
    private \PDO $db;

    public function __construct()
    {
        $this->db = Database::getConnection();
    }

    public function getPayments(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $customerId = $queryParams['customer_id'] ?? null;
        $startDate = $queryParams['start_date'] ?? null;
        $endDate = $queryParams['end_date'] ?? null;

        $sql = '
            SELECT p.*, c.customer_name 
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

        // foreach ($payments as &$pmt) {
        //     $allocations = Database::fetchAll('
        //         SELECT pa.*, b.bill_number, b.bill_date, b.grand_total
        //         FROM payment_allocations pa
        //         JOIN sales_bills b ON pa.sales_bill_id = b.id
        //         WHERE pa.payment_id = ?
        //     ', [$pmt['id']]);
        //     $pmt['allocations'] = $allocations;
        // }

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
          SELECT id, bill_number, bill_date, grand_total, paid_amount, balance_amount, status
          FROM sales_bills
          WHERE customer_id = ? AND status != 'PAID'
          ORDER BY bill_date ASC, id ASC
        ";
        $pendingBills = Database::fetchAll($sql, [$customerId]);

        return ResponseHelper::sendSuccess($response, $pendingBills, 'Customer pending bills fetched successfully');
    }

    // public function processPayment(Request $request, Response $response): Response
    // {
    //     $body = (array)$request->getParsedBody();
    //     $customerId = $body['customer_id'] ?? null;
    //     $paymentDate = $body['payment_date'] ?? null;
    //     $paymentMode = $body['payment_mode'] ?? 'CASH';
    //     $paidAmount = (float)($body['amount'] ?? $body['paid_amount'] ?? 0);
    //     $referenceNumber = $body['reference_number'] ?? null;
    //     $notes = $body['notes'] ?? null;

    //     if (!$customerId || !$paymentDate || $paidAmount <= 0) {
    //         return ResponseHelper::sendError($response, 'customer_id, payment_date, and positive amount are required', [], 400);
    //     }

    //     $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$customerId]);
    //     if (!$customer) {
    //         return ResponseHelper::sendError($response, 'Customer not found', [], 404);
    //     }

    //     $currentAdvanceCredit = (float)($customer['advance_credit'] ?? 0);
    //     $totalAvailableFunds = $paidAmount + $currentAdvanceCredit;

    //     $pendingBills = Database::fetchAll("
    //         SELECT * FROM sales_bills
    //         WHERE customer_id = ? AND status != 'PAID'
    //         ORDER BY bill_date ASC, id ASC
    //     ", [$customerId]);

    //     $resultData = Database::withTransaction(function ($pdo) use (
    //         $customerId, $paymentDate, $paymentMode, $paidAmount, $referenceNumber, 
    //         $notes, $currentAdvanceCredit, $totalAvailableFunds, $pendingBills
    //     ) {
    //         $cntStmt = $pdo->query('SELECT COUNT(id) AS cnt FROM customer_payments');
    //         $cntRow = $cntStmt->fetch();
    //         $seq = str_pad((int)$cntRow['cnt'] + 1, 4, '0', STR_PAD_LEFT);
    //         $receiptNo = "REC-" . date('Y') . "-{$seq}";

    //         $pmtStmt = $pdo->prepare('
    //             INSERT INTO customer_payments 
    //               (payment_number, payment_date, customer_id, payment_mode, amount, reference_number, notes)
    //              VALUES (?, ?, ?, ?, ?, ?, ?)
    //         ');
    //         $pmtStmt->execute([
    //             $receiptNo,
    //             $paymentDate,
    //             $customerId,
    //             $paymentMode,
    //             $paidAmount,
    //             $referenceNumber,
    //             $notes
    //         ]);
    //         $paymentId = $pdo->lastInsertId();

    //         $remainingFunds = $totalAvailableFunds;
    //         $allocationsCreated = [];

    //         $billUpdateStmt = $pdo->prepare('
    //             UPDATE sales_bills SET paid_amount = ?, balance_amount = ?, status = ? WHERE id = ?
    //         ');
    //         $allocStmt = $pdo->prepare('
    //             INSERT INTO payment_allocations (customer_payment_id, sales_bill_id, allocated_amount) VALUES (?, ?, ?)
    //         ');

    //         foreach ($pendingBills as $bill) {
    //             if ($remainingFunds <= 0) break;

    //             $currentBal = (float)$bill['balance_amount'];
    //             if ($currentBal <= 0) continue;

    //             $allocation = min($remainingFunds, $currentBal);
    //             $newPaid = (float)$bill['paid_amount'] + $allocation;
    //             $newBal = $currentBal - $allocation;
    //             $newStatus = ($newBal <= 0) ? 'PAID' : 'PARTIAL';

    //             $billUpdateStmt->execute([$newPaid, max(0, $newBal), $newStatus, $bill['id']]);
    //             $allocStmt->execute([$paymentId, $bill['id'], $allocation]);

    //             $remainingFunds -= $allocation;

    //             $allocationsCreated[] = [
    //                 'sales_bill_id' => $bill['id'],
    //                 'bill_number' => $bill['bill_number'],
    //                 'allocated_amount' => $allocation,
    //                 'new_balance' => max(0, $newBal),
    //                 'status' => $newStatus
    //             ];
    //         }

    //         $newAdvanceCredit = max(0, $remainingFunds);
    //         $custUpdateStmt = $pdo->prepare('UPDATE customers SET advance_credit = ? WHERE id = ?');
    //         $custUpdateStmt->execute([$newAdvanceCredit, $customerId]);

    //         $fetchStmt = $pdo->prepare('SELECT * FROM customer_payments WHERE id = ?');
    //         $fetchStmt->execute([$paymentId]);
    //         $paymentRecord = $fetchStmt->fetch();
    //         $paymentRecord['allocations'] = $allocationsCreated;
    //         $paymentRecord['advance_credit_remaining'] = $newAdvanceCredit;

    //         return $paymentRecord;
    //     });

    //     return ResponseHelper::sendSuccess($response, $resultData, 'Payment processed and allocated successfully', 201);
    // }

    public function processPayment(
    Request $request,
    Response $response
) {
    try {
        $body = $request->getParsedBody();

        $customerId       = $body['customer_id'] ?? null;
        $paymentDate      = $body['payment_date'] ?? null;
        $amount           = $body['amount'] ?? 0;
        $allocationMode   = $body['allocation_mode'] ?? null;
        $manualAllocations = $body['manual_allocations'] ?? null;
        $paymentMode      = $body['payment_mode'] ?? 'CASH';
        $referenceNumber  = $body['reference_number'] ?? null;
        $notes            = $body['notes'] ?? null;

        $paymentAmount = (float)($amount ?: 0);

        // ---------------------------------------------------------
        // Validate Request
        // ---------------------------------------------------------
        if (
            empty($customerId) ||
            empty($paymentDate) ||
            $paymentAmount < 0 ||
            empty($allocationMode)
        ) {
            return ResponseHelper::sendError(
                $response,
                'customer_id, payment_date, valid non-negative amount, and allocation_mode (FIFO/MANUAL) are required'
            );
        }

        // Normalize allocation mode
        $allocationMode = strtoupper(trim($allocationMode));

        if (!in_array($allocationMode, ['FIFO', 'MANUAL'], true)) {
            return ResponseHelper::sendError(
                $response,
                'Unsupported allocation mode. Allowed values are FIFO or MANUAL'
            );
        }

        // ---------------------------------------------------------
        // Get Customer
        // ---------------------------------------------------------
        $stmt = $this->db->prepare("
            SELECT *
            FROM customers
            WHERE id = ?
        ");

        $stmt->execute([$customerId]);

        $customer = $stmt->fetch(\PDO::FETCH_ASSOC);

        if (!$customer) {
            return ResponseHelper::sendError(
                $response,
                'Customer not found in Customer Master.',
                [],
                404
            );
        }

        $existingAdvanceBalance =
            (float)($customer['advance_balance'] ?? 0);

        $fundsAvailable =
            $existingAdvanceBalance + $paymentAmount;

        if ($fundsAvailable <= 0) {
            return ResponseHelper::sendError(
                $response,
                'Total available funds (Payment + Existing Advance Credit) must be greater than 0'
            );
        }

        // ---------------------------------------------------------
        // Begin Transaction
        // ---------------------------------------------------------
        $this->db->beginTransaction();

        try {

            // -----------------------------------------------------
            // 1. Generate Receipt Number
            // -----------------------------------------------------
            $stmt = $this->db->query("
                SELECT COUNT(id) AS cnt
                FROM customer_payments
            ");

            $countRow = $stmt->fetch(\PDO::FETCH_ASSOC);

            $seq = ((int)$countRow['cnt']) + 1;

            $seqFormatted = str_pad(
                (string)$seq,
                4,
                '0',
                STR_PAD_LEFT
            );

            $paymentNumber =
                'REC-' . date('Y') . '-' . $seqFormatted;

            // -----------------------------------------------------
            // Variables
            // -----------------------------------------------------
            $remainingFunds = $fundsAvailable;
            $totalAllocated = 0;
            $allocationRecords = [];

            // -----------------------------------------------------
            // 2. FIFO Allocation
            // -----------------------------------------------------
            if ($allocationMode === 'FIFO') {

                $stmt = $this->db->prepare("
                    SELECT
                        id,
                        bill_number,
                        grand_total,
                        paid_amount,
                        balance_amount
                    FROM sales_bills
                    WHERE customer_id = ?
                      AND status IN ('UNPAID', 'PARTIAL')
                    ORDER BY bill_date ASC, id ASC
                ");

                $stmt->execute([$customerId]);

                $pendingBills =
                    $stmt->fetchAll(\PDO::FETCH_ASSOC);

                foreach ($pendingBills as $bill) {

                    if ($remainingFunds <= 0) {
                        break;
                    }

                    $billBalance =
                        (float)($bill['balance_amount'] ?? 0);

                    $allocation =
                        min($remainingFunds, $billBalance);

                    $remainingFunds -= $allocation;
                    $totalAllocated += $allocation;

                    $newPaid =
                        (float)($bill['paid_amount'] ?? 0)
                        + $allocation;

                    $newBalance =
                        $billBalance - $allocation;

                    $newStatus =
                        ($newBalance <= 0.001)
                            ? 'PAID'
                            : 'PARTIAL';

                    // Update Bill
                    $updateStmt = $this->db->prepare("
                        UPDATE sales_bills
                        SET
                            paid_amount = ?,
                            balance_amount = ?,
                            status = ?
                        WHERE id = ?
                    ");

                    $updateStmt->execute([
                        $newPaid,
                        $newBalance,
                        $newStatus,
                        $bill['id']
                    ]);

                    $allocationRecords[] = [
                        'sales_bill_id' => $bill['id'],
                        'allocated_amount' => $allocation
                    ];
                }

            // -----------------------------------------------------
            // 3. MANUAL Allocation
            // -----------------------------------------------------
            } elseif ($allocationMode === 'MANUAL') {

                if (!is_array($manualAllocations)) {
                    throw new \Exception(
                        'manual_allocations array is required for MANUAL allocation mode'
                    );
                }

                foreach ($manualAllocations as $allocItem) {

                    $billId =
                        $allocItem['sales_bill_id'] ?? null;

                    $allocation =
                        (float)($allocItem['allocated_amount'] ?? 0);

                    // Ignore zero / negative allocations
                    if ($allocation <= 0) {
                        continue;
                    }

                    // ---------------------------------------------
                    // Get Bill
                    // ---------------------------------------------
                    $stmt = $this->db->prepare("
                        SELECT *
                        FROM sales_bills
                        WHERE id = ?
                          AND customer_id = ?
                    ");

                    $stmt->execute([
                        $billId,
                        $customerId
                    ]);

                    $bill =
                        $stmt->fetch(\PDO::FETCH_ASSOC);

                    if (!$bill) {
                        throw new \Exception(
                            "Bill ID {$billId} not found for customer"
                        );
                    }

                    $billBalance =
                        (float)($bill['balance_amount'] ?? 0);

                    // ---------------------------------------------
                    // Validate Allocation
                    // ---------------------------------------------
                    if ($allocation > ($billBalance + 0.01)) {

                        throw new \Exception(
                            'Allocated amount ₹' .
                            $allocation .
                            ' exceeds balance ₹' .
                            $billBalance .
                            ' for Bill ' .
                            $bill['bill_number']
                        );
                    }

                    $totalAllocated += $allocation;

                    $newPaid =
                        (float)($bill['paid_amount'] ?? 0)
                        + $allocation;

                    $newBalance =
                        $billBalance - $allocation;

                    $newStatus =
                        ($newBalance <= 0.001)
                            ? 'PAID'
                            : 'PARTIAL';

                    // ---------------------------------------------
                    // Update Bill
                    // ---------------------------------------------
                    $updateStmt = $this->db->prepare("
                        UPDATE sales_bills
                        SET
                            paid_amount = ?,
                            balance_amount = ?,
                            status = ?
                        WHERE id = ?
                    ");

                    $updateStmt->execute([
                        $newPaid,
                        $newBalance,
                        $newStatus,
                        $bill['id']
                    ]);

                    $allocationRecords[] = [
                        'sales_bill_id' => $bill['id'],
                        'allocated_amount' => $allocation
                    ];
                }

                // ---------------------------------------------
                // Validate Total Allocation
                // ---------------------------------------------
                if ($totalAllocated > ($fundsAvailable + 0.01)) {

                    throw new \Exception(
                        'Total allocated amount ₹' .
                        $totalAllocated .
                        ' exceeds available funds ₹' .
                        $fundsAvailable .
                        ' (Payment: ₹' .
                        $paymentAmount .
                        ' + Advance: ₹' .
                        $existingAdvanceBalance .
                        ')'
                    );
                }

                $remainingFunds =
                    $fundsAvailable - $totalAllocated;
            }

            // -----------------------------------------------------
            // 4. Update Customer Advance Balance
            // -----------------------------------------------------
            $newAdvanceBalance =
                max(0, $remainingFunds);

            $stmt = $this->db->prepare("
                UPDATE customers
                SET advance_balance = ?
                WHERE id = ?
            ");

            $stmt->execute([
                $newAdvanceBalance,
                $customerId
            ]);

            // -----------------------------------------------------
            // 5. Calculate Advance Credit Added
            // -----------------------------------------------------
            $advanceCreditAdded =
                max(
                    0,
                    $newAdvanceBalance - $existingAdvanceBalance
                );

            // -----------------------------------------------------
            // 6. Insert Customer Payment
            // -----------------------------------------------------
            $stmt = $this->db->prepare("
                INSERT INTO customer_payments
                (
                    payment_number,
                    payment_date,
                    customer_id,
                    amount,
                    allocated_amount,
                    advance_credit_amount,
                    payment_mode,
                    reference_number,
                    notes
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ");

            $stmt->execute([
                $paymentNumber,
                $paymentDate,
                $customerId,
                $paymentAmount,
                $totalAllocated,
                $advanceCreditAdded,
                $paymentMode ?: 'CASH',
                $referenceNumber ?: null,
                $notes ?: null
            ]);

            $paymentId =
                $this->db->lastInsertId();

            // -----------------------------------------------------
            // 7. Insert Payment Allocations
            // -----------------------------------------------------
            if (!empty($allocationRecords)) {

                $stmt = $this->db->prepare("
                    INSERT INTO payment_allocations
                    (
                        payment_id,
                        sales_bill_id,
                        allocated_amount
                    )
                    VALUES (?, ?, ?)
                ");

                foreach ($allocationRecords as $record) {

                    $stmt->execute([
                        $paymentId,
                        $record['sales_bill_id'],
                        $record['allocated_amount']
                    ]);
                }
            }

            // -----------------------------------------------------
            // 8. Get Created Payment
            // -----------------------------------------------------
            $stmt = $this->db->prepare("
                SELECT *
                FROM customer_payments
                WHERE id = ?
            ");

            $stmt->execute([$paymentId]);

            $createdPayment =
                $stmt->fetch(\PDO::FETCH_ASSOC);

            // -----------------------------------------------------
            // Commit Transaction
            // -----------------------------------------------------
            $this->db->commit();

            return ResponseHelper::sendSuccess(
                $response,
                $createdPayment,
                'Customer payment processed successfully',
                201
            );

        } catch (\Throwable $e) {

            // Rollback if anything failed
            if ($this->db->inTransaction()) {
                $this->db->rollBack();
            }

            throw $e;
        }

    } catch (\Throwable $err) {

        // Let Slim error middleware handle the exception
        throw $err;
    }
}
}
