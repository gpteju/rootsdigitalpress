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

class JobController
{
    public function getJobs(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $startDate = $queryParams['start_date'] ?? null;
        $endDate = $queryParams['end_date'] ?? null;
        $customerId = $queryParams['customer_id'] ?? null;

        $sql = '
          SELECT 
            j.*,
            c.customer_name,
            c.phone AS customer_phone,
            c.email AS customer_email
          FROM job_details j
          JOIN customers c ON j.customer_id = c.id
          WHERE 1=1
        ';
        $params = [];

        if (!empty($startDate)) {
            $sql .= ' AND j.job_date >= ?';
            $params[] = $startDate;
        }
        if (!empty($endDate)) {
            $sql .= ' AND j.job_date <= ?';
            $params[] = $endDate;
        }
        if (!empty($customerId)) {
            $sql .= ' AND j.customer_id = ?';
            $params[] = $customerId;
        }

        $sql .= ' ORDER BY j.id DESC';
        $jobs = Database::fetchAll($sql, $params);

        return ResponseHelper::sendSuccess($response, $jobs, 'Job estimates fetched successfully');
    }

    public function getJobById(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $sql = '
          SELECT j.*, c.customer_name, c.phone AS customer_phone, c.email AS customer_email
          FROM job_details j
          JOIN customers c ON j.customer_id = c.id
          WHERE j.id = ?
        ';
        $job = Database::fetchOne($sql, [$id]);

        if (!$job) {
            return ResponseHelper::sendError($response, 'Job estimate not found', [], 404);
        }

        $job['items'] = Database::fetchAll('SELECT * FROM job_detail_items WHERE job_detail_id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $job, 'Job estimate details fetched successfully');
    }

    public function createJob(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $customerId = $body['customer_id'] ?? null;
        $jobDate = $body['job_date'] ?? date('Y-m-d');
        $items = $body['items'] ?? [];
        $notes = $body['notes'] ?? null;

        if (!$customerId || !is_array($items) || empty($items)) {
            return ResponseHelper::sendError($response, 'customer_id and non-empty items array are required', [], 400);
        }

        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$customerId]);
        if (!$customer) {
            return ResponseHelper::sendError($response, 'Customer not found in Customer Master', [], 404);
        }

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

            $firstCopyRate = (float)($item['first_copy_rate'] ?? 0);
            $additionalCopyRate = (float)($item['additional_copy_rate'] ?? 0);

            if ($firstCopyRate <= 0 && $additionalCopyRate <= 0) {
                $rateMaster = Database::fetchOne('SELECT * FROM rates WHERE paper_id = ? AND printout_type_id = ? AND is_active = 1', [$paper['id'], $printout['id']]);
                if ($rateMaster) {
                    $firstCopyRate = (float)$rateMaster['first_copy_rate'];
                    $additionalCopyRate = (float)$rateMaster['additional_copy_rate'];
                }
            }

            $lineAmount = 0.0;
            if ($firstCopyRate > 0 || $additionalCopyRate > 0) {
                if ($quantity == 1.0) {
                    $lineAmount = $firstCopyRate;
                } else {
                    $lineAmount = $firstCopyRate + ($quantity - 1.0) * $additionalCopyRate;
                }
            } else {
                $lineAmount = (float)($item['calculated_amount'] ?? 0);
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
                'calculated_amount' => $lineAmount,
                'current_paper_stock' => (float)$paper['current_stock']
            ];
        }

        $userData = $request->getAttribute('user');

        $createdJob = Database::withTransaction(function ($pdo) use (
            $jobDate, $customerId, $calculatedSubtotal, $notes, $userData, $processedItems
        ) {
            $cntStmt = $pdo->query('SELECT COUNT(id) AS cnt FROM job_details');
            $cntRow = $cntStmt->fetch();
            $seq = str_pad((int)$cntRow['cnt'] + 1, 4, '0', STR_PAD_LEFT);
            $jobNumber = "JOB-" . date('Y') . "-{$seq}";

            $jStmt = $pdo->prepare('
                INSERT INTO job_details 
                  (job_number, job_date, customer_id, subtotal, grand_total, notes, created_by)
                 VALUES (?, ?, ?, ?, ?, ?, ?)
            ');
            $jStmt->execute([
                $jobNumber,
                $jobDate,
                $customerId,
                $calculatedSubtotal,
                $calculatedSubtotal,
                $notes,
                $userData['id'] ?? null
            ]);
            $jobDetailId = $pdo->lastInsertId();

            $itemStmt = $pdo->prepare('
                INSERT INTO job_detail_items 
                  (job_detail_id, paper_id, printout_type_id, paper_name_snapshot, job_name, printout_type_name_snapshot,
                   quantity, first_copy_rate, additional_copy_rate, calculated_amount, total_amount)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ');
            $stockStmt = $pdo->prepare('UPDATE papers SET current_stock = ? WHERE id = ?');
            $ledgerStmt = $pdo->prepare('
                INSERT INTO stock_ledger 
                  (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks)
                 VALUES (?, \'JOB_ESTIMATE\', ?, 0.00, ?, ?, ?)
            ');

            foreach ($processedItems as $item) {
                $itemStmt->execute([
                    $jobDetailId,
                    $item['paper_id'],
                    $item['printout_type_id'],
                    $item['paper_name_snapshot'],
                    $item['job_name'],
                    $item['printout_type_name_snapshot'],
                    $item['quantity'],
                    $item['first_copy_rate'],
                    $item['additional_copy_rate'],
                    $item['calculated_amount'],
                    $item['calculated_amount']
                ]);

                $newStock = $item['current_paper_stock'] - $item['quantity'];
                $stockStmt->execute([$newStock, $item['paper_id']]);

                $ledgerStmt->execute([
                    $item['paper_id'],
                    $jobNumber,
                    $item['quantity'],
                    $newStock,
                    "Job Estimate #{$jobNumber}"
                ]);
            }

            $resStmt = $pdo->prepare('
                SELECT j.*, c.customer_name, c.phone AS customer_phone, c.email AS customer_email
                FROM job_details j
                JOIN customers c ON j.customer_id = c.id
                WHERE j.id = ?
            ');
            $resStmt->execute([$jobDetailId]);
            $job = $resStmt->fetch();

            $itemsStmt = $pdo->prepare('SELECT * FROM job_detail_items WHERE job_detail_id = ?');
            $itemsStmt->execute([$jobDetailId]);
            $job['items'] = $itemsStmt->fetchAll();

            return $job;
        });

        return ResponseHelper::sendSuccess($response, $createdJob, 'Job estimate created successfully', 201);
    }

    public function generateJobPdf(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $job = Database::fetchOne('SELECT * FROM job_details WHERE id = ?', [$id]);
        if (!$job) {
            return ResponseHelper::sendError($response, 'Job estimate not found', [], 404);
        }

        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$job['customer_id']]) ?: ['customer_name' => 'Estimate Customer'];
        $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1') ?: ['company_name' => 'Printout Company'];
        $items = Database::fetchAll('SELECT * FROM job_detail_items WHERE job_detail_id = ?', [$id]);

        $billAdapter = array_merge($job, [
            'bill_number' => $job['job_number'],
            'bill_date' => $job['job_date'],
            'cgst_amount' => 0,
            'sgst_amount' => 0,
            'igst_amount' => 0,
            'is_estimate' => 1
        ]);

        $pdfBuffer = PdfService::buildPdfBuffer($billAdapter, $customer, $company, $items);

        $response->getBody()->write($pdfBuffer);
        return $response
            ->withHeader('Content-Type', 'application/pdf')
            ->withHeader('Content-Disposition', "inline; filename=Estimate_{$job['job_number']}.pdf");
    }

    public function emailJobPdf(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $job = Database::fetchOne('SELECT * FROM job_details WHERE id = ?', [$id]);
        if (!$job) {
            return ResponseHelper::sendError($response, 'Job estimate not found', [], 404);
        }

        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$job['customer_id']]);
        if (!$customer) {
            return ResponseHelper::sendError($response, 'Customer not found', [], 404);
        }

        if (empty($customer['email']) || !trim($customer['email'])) {
            return ResponseHelper::sendError($response, "Customer \"{$customer['customer_name']}\" does not have an email address registered in Customer Master.", [], 400);
        }

        $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1') ?: ['company_name' => 'Printout Company'];
        $items = Database::fetchAll('SELECT * FROM job_detail_items WHERE job_detail_id = ?', [$id]);

        $billAdapter = array_merge($job, [
            'bill_number' => $job['job_number'],
            'bill_date' => $job['job_date'],
            'cgst_amount' => 0,
            'sgst_amount' => 0,
            'igst_amount' => 0,
            'is_estimate' => 1
        ]);

        $pdfBuffer = PdfService::buildPdfBuffer($billAdapter, $customer, $company, $items);
        $compName = $company['company_name'] ?? 'Printout Billing';
        $grandTotal = number_format((float)$job['grand_total'], 2);

        MailService::sendInvoiceEmail(
            $customer['email'],
            "Estimate #{$job['job_number']} - {$compName}",
            "Dear {$customer['customer_name']},\n\nPlease find attached your job estimate #{$job['job_number']} for Rs. {$grandTotal}.\n\nThank you!",
            $pdfBuffer,
            "Estimate_{$job['job_number']}.pdf"
        );

        return ResponseHelper::sendSuccess($response, null, "Job estimate PDF successfully emailed to {$customer['email']}");
    }

    public function printJob(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $settings = Database::fetchOne('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');

        if (!$settings || (int)$settings['printer_enabled'] !== 1) {
            return ResponseHelper::sendError($response, 'Thermal printer is currently DISABLED in Printer Configuration. Enable printer in Settings first.', [], 400);
        }

        $job = Database::fetchOne('SELECT * FROM job_details WHERE id = ?', [$id]);
        if (!$job) {
            return ResponseHelper::sendError($response, 'Job estimate not found', [], 404);
        }

        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$job['customer_id']]) ?: ['customer_name' => 'Estimate Customer'];
        $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1') ?: ['company_name' => 'Printout Company'];
        $items = Database::fetchAll('SELECT * FROM job_detail_items WHERE job_detail_id = ?', [$id]);

        $billAdapter = array_merge($job, [
            'bill_number' => $job['job_number'],
            'bill_date' => $job['job_date'],
            'cgst_amount' => 0,
            'sgst_amount' => 0,
            'igst_amount' => 0,
            'is_estimate' => 1
        ]);

        $receiptData = ThermalPrinterService::generateThermalReceipt($company, $customer, $billAdapter, $items);
        ThermalPrinterService::sendToPrinter($settings['printer_ip'], (int)$settings['printer_port'], $receiptData);

        return ResponseHelper::sendSuccess($response, null, "Job Estimate #{$job['job_number']} sent successfully to printer");
    }
}
