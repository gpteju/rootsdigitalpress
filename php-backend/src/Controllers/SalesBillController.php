<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use App\Services\CalculatorService;
use App\Services\MailService;
use App\Services\PdfService;
use App\Services\ThermalPrinterService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class SalesBillController
{
    public function getSalesBills(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $startDate = $queryParams['start_date'] ?? null;
        $endDate = $queryParams['end_date'] ?? null;
        $customerId = $queryParams['customer_id'] ?? null;
        $status = $queryParams['status'] ?? null;

        $sql = '
          SELECT 
            b.*,
            c.customer_name,
            c.phone as customer_phone,
            c.email as customer_email,
            c.address as customer_address,
            c.city as customer_city,
            c.state as customer_state,
            c.gstin as customer_gstin,
            t.tax_name
          FROM sales_bills b
          JOIN customers c ON b.customer_id = c.id
          JOIN taxes t ON b.tax_id = t.id
          WHERE 1=1
        ';
        $params = [];

        if (!empty($startDate)) {
            $sql .= ' AND b.bill_date >= ?';
            $params[] = $startDate;
        }
        if (!empty($endDate)) {
            $sql .= ' AND b.bill_date <= ?';
            $params[] = $endDate;
        }
        if (!empty($customerId)) {
            $sql .= ' AND b.customer_id = ?';
            $params[] = $customerId;
        }
        if (!empty($status)) {
            $sql .= ' AND b.tatus = ?';
            $params[] = $status;
        }

        $sql .= ' ORDER BY b.id DESC';
        $bills = Database::fetchAll($sql, $params);

        return ResponseHelper::sendSuccess($response, $bills, 'Sales bills fetched successfully');
    }

    public function getSalesBillById(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $sql = '
          SELECT b.*, c.customer_name, c.address AS customer_address, c.city AS customer_city, 
                 c.state AS customer_state, c.gstin AS customer_gstin, c.phone AS customer_phone, c.email AS customer_email,
                 t.tax_name, t.tax_percentage
          FROM sales_bills b
          JOIN customers c ON b.customer_id = c.id
          JOIN taxes t ON b.tax_id = t.id
          WHERE b.id = ?
        ';
        $bill = Database::fetchOne($sql, [$id]);

        if (!$bill) {
            return ResponseHelper::sendError($response, 'Sales bill not found', [], 404);
        }

        $bill['items'] = Database::fetchAll('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $bill, 'Sales bill details fetched successfully');
    }

    public function createSalesBill(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $customerId = $body['customer_id'] ?? null;
        $billDate = $body['bill_date'] ?? null;
        $taxId = $body['tax_id'] ?? null;
        $items = $body['items'] ?? [];

        if (!$customerId || !$billDate || !$taxId || !is_array($items) || empty($items)) {
            return ResponseHelper::sendError($response, 'customer_id, bill_date, tax_id, and non-empty items array are required', [], 400);
        }

        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$customerId]);
        if (!$customer) {
            return ResponseHelper::sendError($response, 'Customer not found in Customer Master', [], 404);
        }

        $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
        if (!$company) {
            return ResponseHelper::sendError($response, 'Company profile not configured', [], 404);
        }

        $taxMaster = Database::fetchOne('SELECT * FROM taxes WHERE id = ?', [$taxId]);
        if (!$taxMaster) {
            return ResponseHelper::sendError($response, 'Tax master not found', [], 404);
        }
        $taxMaster['sub_taxes'] = Database::fetchAll('SELECT * FROM tax_sub_taxes WHERE tax_id = ?', [$taxId]);

        $calculatedSubtotal = 0.0;
        $processedItems = [];

        foreach ($items as $idx => $item) {
            $paper = Database::fetchOne('SELECT * FROM papers WHERE id = ?', [$item['paper_id'] ?? 0]);
            if (!$paper) {
                return ResponseHelper::sendError($response, "Paper ID {$item['paper_id']} at line " . ($idx + 1) . " not found", [], 400);
            }

            $printout = Database::fetchOne('SELECT * FROM printout_types WHERE id = ?', [$item['printout_type_id'] ?? 0]);
            if (!$printout) {
                return ResponseHelper::sendError($response, "Printout Type ID {$item['printout_type_id']} at line " . ($idx + 1) . " not found", [], 400);
            }

            $quantity = (float)($item['quantity'] ?? 0);
            if ($quantity <= 0) {
                return ResponseHelper::sendError($response, "Quantity must be greater than 0 at line " . ($idx + 1), [], 400);
            }

            if ((float)$paper['current_stock'] < $quantity) {
                return ResponseHelper::sendError($response, "Insufficient stock for paper \"{$paper['paper_name']}\". Requested: {$quantity}, Available: {$paper['current_stock']}.", [], 400);
            }

            $rateBasedOn = $item['rate_based_on'] ?? 'Rates';
            $firstCopyRate = 0.0;
            $additionalCopyRate = 0.0;
            $clickRate = null;
            $lineAmount = 0.0;

            if ($rateBasedOn === 'Click Rate') {
                $clickRateVal = (float)($item['click_rate'] ?? 0);
                if ($clickRateVal <= 0) {
                    $rateMaster = Database::fetchOne('SELECT click_rate FROM rates WHERE paper_id = ? AND printout_type_id = ? AND is_active = 1', [$paper['id'], $printout['id']]);
                    if ($rateMaster && $rateMaster['click_rate'] > 0) {
                        $clickRateVal = (float)$rateMaster['click_rate'];
                    }
                }
                $clickRate = $clickRateVal;
                $lineAmount = round($quantity * $clickRateVal, 2);
            } else {
                $firstCopyRate = (float)($item['first_copy_rate'] ?? 0);
                $additionalCopyRate = (float)($item['additional_copy_rate'] ?? 0);
                if ($firstCopyRate <= 0 && $additionalCopyRate <= 0) {
                    $rateMaster = Database::fetchOne('SELECT * FROM rates WHERE paper_id = ? AND printout_type_id = ? AND is_active = 1', [$paper['id'], $printout['id']]);
                    if ($rateMaster) {
                        $firstCopyRate = (float)$rateMaster['first_copy_rate'];
                        $additionalCopyRate = (float)$rateMaster['additional_copy_rate'];
                    }
                }
                $calc = CalculatorService::calculateItemAmount($quantity, $firstCopyRate, $additionalCopyRate);
                $lineAmount = $calc['lineAmount'];
            }

            $calculatedSubtotal += $lineAmount;

            $processedItems[] = [
                'paper_id' => $paper['id'],
                'printout_type_id' => $printout['id'],
                'paper_name_snapshot' => $paper['paper_name'],
                'job_name' => $item['job_name'] ?? null,
                'printout_type_name_snapshot' => $printout['name'] ?? '',
                'quantity' => $quantity,
                'first_copy_rate' => $firstCopyRate,
                'additional_copy_rate' => $additionalCopyRate,
                'rate_based_on' => $rateBasedOn,
                'click_rate' => $clickRate,
                'calculated_amount' => $lineAmount,
                'current_paper_stock' => (float)$paper['current_stock']
            ];
        }

        $taxResult = CalculatorService::calculateInvoiceTax(
            $company['state'] ?? null,
            $customer['state'] ?? null,
            $calculatedSubtotal,
            $taxMaster,
            $company['state_code'] ?? null,
            $customer['state_code'] ?? null
        );

        $finalGrandTotal = round($taxResult['grandTotal']);
        $roundOff = round($finalGrandTotal - $taxResult['grandTotal'], 2);

        $userData = $request->getAttribute('user');

        $createdBill = Database::withTransaction(function ($pdo) use (
            $billDate, $customerId, $taxId, $company, $customer, $taxResult, 
            $calculatedSubtotal, $roundOff, $finalGrandTotal, $body, $userData, $processedItems, $taxMaster
        ) {
            $cntStmt = $pdo->query('SELECT COUNT(id) AS cnt FROM sales_bills');
            $cntRow = $cntStmt->fetch();
            $seq = str_pad((int)$cntRow['cnt'] + 1, 4, '0', STR_PAD_LEFT);
            $billNumber = "INV-" . date('Y') . "-{$seq}";

            $bStmt = $pdo->prepare('
                INSERT INTO sales_bills 
                  (bill_number, bill_date, customer_id, tax_id, company_state_snapshot, customer_state_snapshot,
                   is_interstate, subtotal, cgst_amount, sgst_amount, igst_amount, round_off, grand_total, paid_amount, balance_amount, status, notes, created_by)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0.00, ?, \'UNPAID\', ?, ?)
            ');
            $bStmt->execute([
                $billNumber,
                $billDate,
                $customerId,
                $taxId,
                $company['state'] ?? 'TAMIL NADU',
                $customer['state'] ?? 'TAMIL NADU',
                $taxResult['isInterstate'] ? 1 : 0,
                $calculatedSubtotal,
                $taxResult['cgstAmount'],
                $taxResult['sgstAmount'],
                $taxResult['igstAmount'],
                $roundOff,
                $finalGrandTotal,
                $finalGrandTotal,
                $body['notes'] ?? null,
                $userData['id'] ?? null
            ]);

            $billId = $pdo->lastInsertId();

            $itemStmt = $pdo->prepare('
                INSERT INTO sales_bill_items 
                  (sales_bill_id, paper_id, printout_type_id, paper_name_snapshot, job_name, printout_type_name_snapshot,
                   quantity, first_copy_rate, additional_copy_rate, rate_based_on, click_rate, calculated_amount, tax_percentage, tax_amount, total_amount)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ');
            $stockStmt = $pdo->prepare('UPDATE papers SET current_stock = ? WHERE id = ?');
            $ledgerStmt = $pdo->prepare('
                INSERT INTO stock_ledger 
                  (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks)
                 VALUES (?, \'SALE\', ?, 0.00, ?, ?, ?)
            ');

            foreach ($processedItems as $item) {
                $itemTaxPct = (float)($taxMaster['tax_percentage'] ?? 0);
                $itemTaxAmt = ($item['calculated_amount'] * $itemTaxPct) / 100.0;
                $itemTotal = $item['calculated_amount'] + $itemTaxAmt;

                $itemStmt->execute([
                    $billId,
                    $item['paper_id'],
                    $item['printout_type_id'],
                    $item['paper_name_snapshot'],
                    $item['job_name'],
                    $item['printout_type_name_snapshot'],
                    $item['quantity'],
                    $item['first_copy_rate'],
                    $item['additional_copy_rate'],
                    $item['rate_based_on'],
                    $item['rate_based_on'] == 'Rates' ? 0 : $item['click_rate'],
                    $item['calculated_amount'],
                    $itemTaxPct,
                    $itemTaxAmt,
                    $itemTotal
                ]);

                $newStock = $item['current_paper_stock'] - $item['quantity'];
                $stockStmt->execute([$newStock, $item['paper_id']]);

                $ledgerStmt->execute([
                    $item['paper_id'],
                    $billNumber,
                    $item['quantity'],
                    $newStock,
                    "Sales Bill #{$billNumber}"
                ]);
            }

            $resStmt = $pdo->prepare('
                SELECT b.*, c.customer_name, c.address AS customer_address, c.city AS customer_city, 
                        c.state AS customer_state, c.gstin AS customer_gstin, c.phone AS customer_phone, c.email AS customer_email,
                        t.tax_name, t.tax_percentage
                 FROM sales_bills b
                 JOIN customers c ON b.customer_id = c.id
                 JOIN taxes t ON b.tax_id = t.id
                 WHERE b.id = ?
            ');
            $resStmt->execute([$billId]);
            $bill = $resStmt->fetch();

            $itemsStmt = $pdo->prepare('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?');
            $itemsStmt->execute([$billId]);
            $bill['items'] = $itemsStmt->fetchAll();

            return $bill;
        });

        return ResponseHelper::sendSuccess($response, $createdBill, 'Sales Bill created successfully', 201);
    }

    public function generateBillPdf(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $bill = Database::fetchOne('SELECT * FROM sales_bills WHERE id = ?', [$id]);
        if (!$bill) {
            return ResponseHelper::sendError($response, 'Bill not found', [], 404);
        }

        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$bill['customer_id']]) ?: ['customer_name' => 'Cash'];
        $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1') ?: ['company_name' => 'Printout Company'];
        $items = Database::fetchAll('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [$id]);

        $pdfBuffer = PdfService::buildPdfBuffer($bill, $customer, $company, $items);

        $response->getBody()->write($pdfBuffer);
        return $response
            ->withHeader('Content-Type', 'application/pdf')
            ->withHeader('Content-Disposition', "inline; filename=Invoice_{$bill['bill_number']}.pdf");
    }

    public function emailBillPdf(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $bill = Database::fetchOne('SELECT * FROM sales_bills WHERE id = ?', [$id]);
        if (!$bill) {
            return ResponseHelper::sendError($response, 'Bill not found', [], 404);
        }

        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$bill['customer_id']]);
        if (!$customer) {
            return ResponseHelper::sendError($response, 'Customer not found', [], 404);
        }

        if (empty($customer['email']) || !trim($customer['email'])) {
            return ResponseHelper::sendError($response, "Customer \"{$customer['customer_name']}\" does not have an email address registered in Customer Master.", [], 400);
        }

        $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1') ?: ['company_name' => 'Printout Company'];
        $items = Database::fetchAll('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [$id]);

        $pdfBuffer = PdfService::buildPdfBuffer($bill, $customer, $company, $items);

        $compName = $company['company_name'] ?? 'Printout Billing';
        $grandTotal = number_format((float)$bill['grand_total'], 2);

        MailService::sendInvoiceEmail(
            $customer['email'],
            "Invoice #{$bill['bill_number']} - {$compName}",
            "Dear {$customer['customer_name']},\n\nPlease find attached your invoice #{$bill['bill_number']} for Rs. {$grandTotal}.\n\nThank you for your business!",
            $pdfBuffer,
            "Invoice_{$bill['bill_number']}.pdf"
        );

        return ResponseHelper::sendSuccess($response, null, "Invoice PDF successfully emailed to {$customer['email']}");
    }

    public function printSalesBill(Request $request, Response $response, array $args): Response
    {
        try {
            $id = (int)$args['id'];
            $settings = Database::fetchOne('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');

            if (!$settings || (int)$settings['printer_enabled'] !== 1) {
                return ResponseHelper::sendError($response, 'Thermal printer is currently DISABLED in Printer Configuration. Enable printer in Settings first.', [], 400);
            }

            if (empty($settings['printer_ip']) || !trim($settings['printer_ip'])) {
                return ResponseHelper::sendError($response, 'Printer IP address is not configured. Please save a valid Printer IP in Printer Configuration.', [], 400);
            }

            $bill = Database::fetchOne('SELECT * FROM sales_bills WHERE id = ?', [$id]);
            if (!$bill) {
                return ResponseHelper::sendError($response, 'Sales bill not found', [], 404);
            }

            $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$bill['customer_id']]) ?: ['customer_name' => 'Cash'];
            $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1') ?: ['company_name' => 'Printout Company'];
            $items = Database::fetchAll('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [$id]);

            $receiptData = ThermalPrinterService::generateThermalReceipt($company, $customer, $bill, $items);
            ThermalPrinterService::sendToPrinter($settings['printer_ip'], (int)$settings['printer_port'], $receiptData);

            return ResponseHelper::sendSuccess($response, null, "Sales Bill #{$bill['bill_number']} sent successfully to printer ({$settings['printer_ip']}:{$settings['printer_port']})");
        } catch (\Exception $e) {
            return ResponseHelper::sendError($response, 'Print failed: ' . $e->getMessage(), [], 500);
        }
    }
}
