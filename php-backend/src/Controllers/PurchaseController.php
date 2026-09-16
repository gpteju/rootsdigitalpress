<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use App\Services\CalculatorService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class PurchaseController
{
    public function getPurchases(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $startDate = $queryParams['start_date'] ?? null;
        $endDate = $queryParams['end_date'] ?? null;
        $supplierId = $queryParams['supplier_id'] ?? null;

        $sql = '
          SELECT 
            p.*,
            s.supplier_name
          FROM supplier_purchases p
          JOIN suppliers s ON p.supplier_id = s.id
          WHERE 1=1
        ';
        $params = [];

        if (!empty($startDate)) {
            $sql .= ' AND p.purchase_date >= ?';
            $params[] = $startDate;
        }
        if (!empty($endDate)) {
            $sql .= ' AND p.purchase_date <= ?';
            $params[] = $endDate;
        }
        if (!empty($supplierId)) {
            $sql .= ' AND p.supplier_id = ?';
            $params[] = $supplierId;
        }

        $sql .= ' ORDER BY p.id DESC';
        $purchases = Database::fetchAll($sql, $params);

        return ResponseHelper::sendSuccess($response, $purchases, 'Supplier purchases fetched successfully');
    }

    public function getPurchaseById(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $sql = '
          SELECT p.*, s.supplier_name, s.address AS supplier_address, s.phone AS supplier_phone, s.email AS supplier_email
          FROM supplier_purchases p
          JOIN suppliers s ON p.supplier_id = s.id
          WHERE p.id = ?
        ';
        $purchase = Database::fetchOne($sql, [$id]);

        if (!$purchase) {
            return ResponseHelper::sendError($response, 'Supplier purchase details not found', [], 404);
        }

        $purchase['items'] = Database::fetchAll('
            SELECT spi.*, paper.paper_name 
            FROM supplier_purchase_items spi
            JOIN papers paper ON spi.paper_id = paper.id
            WHERE spi.supplier_purchase_id = ?
        ', [$id]);

        return ResponseHelper::sendSuccess($response, $purchase, 'Purchase details fetched successfully');
    }

    public function createPurchase(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $supplierId = $body['supplier_id'] ?? null;
        $purchaseDate = $body['purchase_date'] ?? null;
        $invoiceNumber = $body['invoice_number'] ?? null;
        $items = $body['items'] ?? [];
        $paidAmount = (float)($body['paid_amount'] ?? 0);
        $taxPercentage = (float)($body['tax_percentage'] ?? 0);

        if (!$supplierId || !$purchaseDate || !is_array($items) || empty($items)) {
            return ResponseHelper::sendError($response, 'supplier_id, purchase_date, and non-empty items array are required', [], 400);
        }

        $supplier = Database::fetchOne('SELECT * FROM suppliers WHERE id = ?', [$supplierId]);
        if (!$supplier) {
            return ResponseHelper::sendError($response, 'Supplier not found in Supplier Master', [], 404);
        }

        $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
        if (!$company) {
            return ResponseHelper::sendError($response, 'Company profile not configured', [], 404);
        }

        $subtotal = 0.0;
        $processedItems = [];

        foreach ($items as $idx => $item) {
            $paper = Database::fetchOne('SELECT * FROM papers WHERE id = ?', [$item['paper_id'] ?? 0]);
            if (!$paper) {
                return ResponseHelper::sendError($response, "Paper ID {$item['paper_id']} at line " . ($idx + 1) . " not found", [], 400);
            }

            $qty = (float)($item['quantity'] ?? 0);
            $rate = (float)($item['rate'] ?? 0);
            if ($qty <= 0 || $rate < 0) {
                return ResponseHelper::sendError($response, "Invalid quantity or rate at line " . ($idx + 1), [], 400);
            }

            $amt = $qty * $rate;
            $subtotal += $amt;

            $processedItems[] = [
                'paper_id' => $paper['id'],
                'quantity' => $qty,
                'rate' => $rate,
                'amount' => $amt,
                'current_stock' => (float)$paper['current_stock']
            ];
        }

        $mockTaxMaster = ['tax_percentage' => $taxPercentage, 'sub_taxes' => []];
        $taxResult = CalculatorService::calculateInvoiceTax($company['state'] ?? null, $supplier['state'] ?? null, $subtotal, $mockTaxMaster);

        $balAmount = $taxResult['grandTotal'] - $paidAmount;

        $createdPurchase = Database::withTransaction(function ($pdo) use (
            $supplierId, $purchaseDate, $invoiceNumber, $subtotal, $taxResult, 
            $paidAmount, $balAmount, $taxPercentage, $processedItems
        ) {
            $cntStmt = $pdo->query('SELECT COUNT(id) AS cnt FROM supplier_purchases');
            $cntRow = $cntStmt->fetch();
            $seq = str_pad((int)$cntRow['cnt'] + 1, 4, '0', STR_PAD_LEFT);
            $purchaseNumber = "PUR-" . date('Y') . "-{$seq}";

            $purStmt = $pdo->prepare('
                INSERT INTO supplier_purchases 
                  (purchase_number, purchase_date, supplier_id, invoice_number, subtotal, cgst_amount, sgst_amount, igst_amount, grand_total, paid_amount, balance_amount)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ');
            $purStmt->execute([
                $purchaseNumber,
                $purchaseDate,
                $supplierId,
                $invoiceNumber ?: null,
                $subtotal,
                $taxResult['cgstAmount'],
                $taxResult['sgstAmount'],
                $taxResult['igstAmount'],
                $taxResult['grandTotal'],
                $paidAmount,
                $balAmount
            ]);
            $purchaseId = $pdo->lastInsertId();

            $itemStmt = $pdo->prepare('
                INSERT INTO supplier_purchase_items 
                  (supplier_purchase_id, paper_id, quantity, rate, amount, tax_percentage, tax_amount, total_amount)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ');
            $stockStmt = $pdo->prepare('UPDATE papers SET current_stock = ? WHERE id = ?');
            $ledgerStmt = $pdo->prepare('
                INSERT INTO stock_ledger 
                  (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks)
                 VALUES (?, \'PURCHASE\', ?, ?, 0.00, ?, ?)
            ');

            foreach ($processedItems as $item) {
                $itemTaxAmt = ($item['amount'] * $taxPercentage) / 100.0;
                $itemTotal = $item['amount'] + $itemTaxAmt;

                $itemStmt->execute([
                    $purchaseId,
                    $item['paper_id'],
                    $item['quantity'],
                    $item['rate'],
                    $item['amount'],
                    $taxPercentage,
                    $itemTaxAmt,
                    $itemTotal
                ]);

                $newStock = $item['current_stock'] + $item['quantity'];
                $stockStmt->execute([$newStock, $item['paper_id']]);

                $ledgerStmt->execute([
                    $item['paper_id'],
                    $purchaseNumber,
                    $item['quantity'],
                    $newStock,
                    "Supplier Purchase #{$purchaseNumber}"
                ]);
            }

            $resStmt = $pdo->prepare('SELECT * FROM supplier_purchases WHERE id = ?');
            $resStmt->execute([$purchaseId]);
            return $resStmt->fetch();
        });

        return ResponseHelper::sendSuccess($response, $createdPurchase, 'Supplier purchase recorded successfully', 201);
    }
}
