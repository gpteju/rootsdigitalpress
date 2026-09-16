<?php

namespace App\Services;

class ThermalPrinterService
{
    public static function generateThermalReceipt(array $company, array $customer, array $bill, array $items): string
    {
        $ESC = "\x1B";
        $GS  = "\x1D";

        $out = "";

        $out .= $ESC . "@";
        $out .= $ESC . "a" . "\x01";
        $out .= $ESC . "E" . "\x01";
        $out .= ($company['company_name'] ?? 'Printout Company') . "\n";
        $out .= $ESC . "E" . "\x00";

        if (!empty($company['address'])) {
            $out .= $company['address'] . "\n";
        }
        if (!empty($company['phone'])) {
            $out .= "Ph: " . $company['phone'] . "\n";
        }
        if (!empty($company['gstin'])) {
            $out .= "GSTIN: " . $company['gstin'] . "\n";
        }

        $out .= "------------------------------------------------\n";
        $out .= (!empty($bill['is_estimate']) ? "ESTIMATE / JOB SLIP" : "TAX INVOICE") . "\n";
        $out .= "------------------------------------------------\n";

        $out .= $ESC . "a" . "\x00";
        $out .= "Customer: " . ($customer['customer_name'] ?? 'Cash Customer') . "\n";
        $out .= "Bill No : " . ($bill['bill_number'] ?? $bill['job_number'] ?? '') . "\n";
        $out .= "Date    : " . ($bill['bill_date'] ?? $bill['job_date'] ?? '') . "\n";
        $out .= "------------------------------------------------\n";

        $out .= sprintf("%-20s %5s %8s %10s\n", "Item", "Qty", "Rate", "Amount");
        $out .= "------------------------------------------------\n";

        foreach ($items as $item) {
            $paperName = $item['paper_name_snapshot'] ?? $item['paper_name'] ?? 'Item';
            $printoutType = $item['printout_type_name_snapshot'] ?? '';
            $jobName = !empty($item['job_name']) ? trim($item['job_name']) : '';
            $qty = (int)($item['quantity'] ?? 0);
            $rate = ($item['calculated_amount'] ?? 0) > 0 && $qty > 0 ? (($item['calculated_amount'] ?? 0) / $qty) : 0;
            $amt = (float)($item['calculated_amount'] ?? $item['total_amount'] ?? 0);

            $desc = $paperName;
            if (!empty($jobName)) {
                $desc .= " - {$jobName}";
            }
            if (!empty($printoutType)) {
                $desc .= " ({$printoutType})";
            }

            if (strlen($desc) > 20) {
                $out .= $desc . "\n";
                $out .= sprintf("%-20s %5d %8.2f %10.2f\n", "", $qty, $rate, $amt);
            } else {
                $out .= sprintf("%-20s %5d %8.2f %10.2f\n", $desc, $qty, $rate, $amt);
            }
        }

        $out .= "------------------------------------------------\n";
        $subtotal = $bill['subtotal'] ?? 0;
        $cgst = $bill['cgst_amount'] ?? 0;
        $sgst = $bill['sgst_amount'] ?? 0;
        $igst = $bill['igst_amount'] ?? 0;
        $grandTotal = $bill['grand_total'] ?? 0;

        $out .= sprintf("%35s: %10.2f\n", "Subtotal", $subtotal);
        if ($cgst > 0) $out .= sprintf("%35s: %10.2f\n", "CGST", $cgst);
        if ($sgst > 0) $out .= sprintf("%35s: %10.2f\n", "SGST", $sgst);
        if ($igst > 0) $out .= sprintf("%35s: %10.2f\n", "IGST", $igst);

        $out .= $ESC . "E" . "\x01";
        $out .= sprintf("%35s: %10.2f\n", "Grand Total", $grandTotal);
        $out .= $ESC . "E" . "\x00";

        $out .= "------------------------------------------------\n";
        $out .= $ESC . "a" . "\x01";
        $out .= "Thank you for your business!\n\n\n";

        $out .= $GS . "V" . "\x41" . "\x03";

        return $out;
    }

    public static function sendToPrinter(string $ip, int $port, string $data): bool
    {
        $fp = @fsockopen($ip, $port, $errno, $errstr, 5);
        if (!$fp) {
            throw new \RuntimeException("Could not connect to thermal printer at {$ip}:{$port}. Error: {$errstr}");
        }
        fwrite($fp, $data);
        fclose($fp);
        return true;
    }
}
