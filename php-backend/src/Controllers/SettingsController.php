<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use App\Services\ThermalPrinterService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class SettingsController
{
    public function getPrinterSettings(Request $request, Response $response): Response
    {
        $settings = Database::fetchOne('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');
        return ResponseHelper::sendSuccess($response, $settings ?: new \stdClass(), 'Printer settings fetched successfully');
    }

    public function updatePrinterSettings(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $existing = Database::fetchOne('SELECT id FROM printer_settings ORDER BY id ASC LIMIT 1');

        if ($existing) {
            Database::execute(
                'UPDATE printer_settings SET 
                    printer_name = ?, printer_ip = ?, printer_port = ?, paper_width_mm = ?, printer_enabled = ?
                 WHERE id = ?',
                [
                    $body['printer_name'] ?? 'Thermal Printer',
                    $body['printer_ip'] ?? '192.168.1.200',
                    $body['printer_port'] ?? 9100,
                    $body['paper_width_mm'] ?? 80,
                    isset($body['printer_enabled']) ? (int)$body['printer_enabled'] : 1,
                    $existing['id']
                ]
            );
            $id = $existing['id'];
        } else {
            Database::execute(
                'INSERT INTO printer_settings (printer_name, printer_ip, printer_port, paper_width_mm, printer_enabled)
                 VALUES (?, ?, ?, ?, ?)',
                [
                    $body['printer_name'] ?? 'Thermal Printer',
                    $body['printer_ip'] ?? '192.168.1.200',
                    $body['printer_port'] ?? 9100,
                    $body['paper_width_mm'] ?? 80,
                    isset($body['printer_enabled']) ? (int)$body['printer_enabled'] : 1
                ]
            );
            $id = Database::lastInsertId();
        }

        $updated = Database::fetchOne('SELECT * FROM printer_settings WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $updated, 'Printer settings updated successfully');
    }

    public function testPrinter(Request $request, Response $response): Response
    {
        try {
            $body = (array)$request->getParsedBody();
            $settings = Database::fetchOne('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');

            $ip = trim($body['printer_ip'] ?? $settings['printer_ip'] ?? '');
            $port = (int)($body['printer_port'] ?? $settings['printer_port'] ?? 9100);

            if (empty($ip)) {
                return ResponseHelper::sendError($response, 'Printer IP address is required for testing', [], 400);
            }

            $company = Database::fetchOne('SELECT company_name FROM companies ORDER BY id ASC LIMIT 1');
            $companyName = $company['company_name'] ?? 'Printout Company';

            $ESC = "\x1B";
            $GS  = "\x1D";
            $out = $ESC . "@";
            $out .= $ESC . "a" . "\x01";
            $out .= $ESC . "E" . "\x01";
            $out .= $ESC . "!" . "\x30";
            $out .= "TEST PRINT\n";
            $out .= $ESC . "!0";
            $out .= "{$companyName}\n";
            $out .= $ESC . "E" . "\x00";
            $out .= "--------------------------------\n";
            $out .= $ESC . "a" . "\x00";
            $out .= "Printer Connection OK\n";
            $out .= "IP   : {$ip}\n";
            $out .= "Port : {$port}\n";
            $out .= "Date : " . date('Y-m-d H:i:s') . "\n";
            $out .= "--------------------------------\n";
            $out .= $ESC . "a" . "\x01";
            $out .= "Test Print Successful\n\n\n";
            $out .= $GS . "V" . "\x41" . "\x03";

            ThermalPrinterService::sendToPrinter($ip, $port, $out);

            return ResponseHelper::sendSuccess($response, null, "Test print successfully sent to {$ip}:{$port}");
        } catch (\Exception $e) {
            return ResponseHelper::sendError($response, 'Test print failed: ' . $e->getMessage(), [], 500);
        }
    }

    public function printReceipt(Request $request, Response $response): Response
    {
        try {
            $body = (array)($request->getParsedBody() ?? []);
            if (empty($body)) {
                $rawInput = (string)$request->getBody();
                if (!empty($rawInput)) {
                    $decoded = json_decode($rawInput, true);
                    if (is_array($decoded)) {
                        $body = $decoded;
                    }
                }
            }

            $settings = Database::fetchOne('SELECT * FROM printer_settings ORDER BY id ASC LIMIT 1');
            if (!$settings || (int)($settings['printer_enabled'] ?? 0) !== 1) {
                return ResponseHelper::sendError($response, 'Thermal printer is DISABLED. Please enable printer and configure IP/Port in Printer Settings before printing.', [], 400);
            }

            $ip = trim($settings['printer_ip'] ?? '');
            $port = (int)($settings['printer_port'] ?? 9100);

            if (empty($ip)) {
                return ResponseHelper::sendError($response, 'Printer IP address is not configured. Please save a valid Printer IP in Printer Settings.', [], 400);
            }

            $bytesBase64 = $body['bytes_base64'] ?? null;
            $billId = $body['bill_id'] ?? $body['sales_bill_id'] ?? null;

            if ($bytesBase64) {
                $receiptData = base64_decode($bytesBase64);
            } elseif ($billId) {
                $bill = Database::fetchOne('SELECT * FROM sales_bills WHERE id = ?', [$billId]);
                if (!$bill) {
                    return ResponseHelper::sendError($response, 'Sales bill not found', [], 404);
                }
                $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$bill['customer_id']]) ?: ['customer_name' => 'Cash Customer'];
                $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1') ?: ['company_name' => 'Printout Company'];
                $items = Database::fetchAll('SELECT * FROM sales_bill_items WHERE sales_bill_id = ?', [$billId]);

                $receiptData = ThermalPrinterService::generateThermalReceipt($company, $customer, $bill, $items);
            } else {
                return ResponseHelper::sendError($response, 'No print data received. Field "bytes_base64" or "bill_id" is required.', [], 400);
            }

            ThermalPrinterService::sendToPrinter($ip, $port, $receiptData);

            return ResponseHelper::sendSuccess($response, null, "Receipt printed successfully to {$ip}:{$port}");
        } catch (\Exception $e) {
            return ResponseHelper::sendError($response, 'Print failed: ' . $e->getMessage(), [], 500);
        }
    }
}
