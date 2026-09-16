<?php

namespace App\Services;

use Dompdf\Dompdf;
use Dompdf\Options;

class PdfService
{
    public static function buildPdfBuffer(array $bill, array $customer, array $company, array $items): string
    {
        $options = new Options();
        $options->set('isHtml5ParserEnabled', true);
        $options->set('isRemoteEnabled', true);
        $options->set('defaultFont', 'Helvetica');

        $dompdf = new Dompdf($options);

        $billNo = $bill['bill_number'] ?? $bill['job_number'] ?? '';
        $billDate = $bill['bill_date'] ?? $bill['job_date'] ?? '';
        $isEstimate = !empty($bill['is_estimate']) || str_starts_with($billNo, 'JOB-');

        $itemsHtml = '';
        $idx = 1;
        foreach ($items as $item) {
            $name = htmlspecialchars($item['paper_name_snapshot'] ?? $item['paper_name'] ?? '');
            $jobName = htmlspecialchars($item['job_name'] ?? '');
            $printoutType = htmlspecialchars($item['printout_type_name_snapshot'] ?? '');

            $desc = $name;
            if (!empty($jobName)) {
                $desc .= " - {$jobName}";
            }
            if (!empty($printoutType)) {
                $desc .= " ({$printoutType})";
            }

            $qty = (int)($item['quantity'] ?? 0);
            $rate = ($item['calculated_amount'] ?? 0) > 0 && $qty > 0 ? number_format(($item['calculated_amount'] ?? 0) / $qty, 2) : '0.00';
            $amount = number_format($item['calculated_amount'] ?? $item['total_amount'] ?? 0, 2);

            $itemsHtml .= "
                <tr>
                    <td style='text-align:center;'>{$idx}</td>
                    <td>{$desc}</td>
                    <td style='text-align:right;'>{$qty}</td>
                    <td style='text-align:right;'>Rs. {$rate}</td>
                    <td style='text-align:right;'>Rs. {$amount}</td>
                </tr>
            ";
            $idx++;
        }

        $title = $isEstimate ? 'ESTIMATE / JOB SLIP' : 'TAX INVOICE';
        $subtotal = number_format($bill['subtotal'] ?? 0, 2);
        $cgst = number_format($bill['cgst_amount'] ?? 0, 2);
        $sgst = number_format($bill['sgst_amount'] ?? 0, 2);
        $igst = number_format($bill['igst_amount'] ?? 0, 2);
        $roundOff = number_format($bill['round_off'] ?? 0, 2);
        $grandTotal = number_format($bill['grand_total'] ?? 0, 2);

        $html = "
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset='utf-8'>
            <style>
                body { font-family: Helvetica, sans-serif; font-size: 12px; color: #333; margin: 20px; }
                .header { text-align: center; border-bottom: 2px solid #333; padding-bottom: 10px; margin-bottom: 20px; }
                .company-name { font-size: 20px; font-weight: bold; color: #1a365d; }
                .title { font-size: 16px; font-weight: bold; margin-top: 5px; color: #2b6cb0; }
                .details-table { width: 100%; margin-bottom: 20px; border-collapse: collapse; }
                .details-table td { padding: 4px; vertical-align: top; }
                .items-table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
                .items-table th, .items-table td { border: 1px solid #cbd5e0; padding: 8px; }
                .items-table th { background-color: #ebf8ff; color: #2c5282; text-align: left; }
                .totals-table { width: 40%; float: right; border-collapse: collapse; }
                .totals-table td { padding: 4px; text-align: right; }
                .grand-total { font-size: 14px; font-weight: bold; color: #1a365d; border-top: 2px solid #333; }
                .footer { clear: both; margin-top: 40px; text-align: center; font-size: 10px; color: #718096; }
            </style>
        </head>
        <body>
            <div class='header'>
                <div class='company-name'>" . htmlspecialchars($company['company_name'] ?? 'Printout Company') . "</div>
                <div>" . htmlspecialchars($company['address'] ?? '') . " " . htmlspecialchars($company['city'] ?? '') . "</div>
                <div>Phone: " . htmlspecialchars($company['phone'] ?? '') . " | Email: " . htmlspecialchars($company['email'] ?? '') . "</div>
                " . (!empty($company['gstin']) ? "<div>GSTIN: " . htmlspecialchars($company['gstin']) . "</div>" : "") . "
                <div class='title'>{$title}</div>
            </div>

            <table class='details-table'>
                <tr>
                    <td width='60%'>
                        <strong>Billed To:</strong><br>
                        " . htmlspecialchars($customer['customer_name'] ?? 'Cash Customer') . "<br>
                        " . htmlspecialchars($customer['address'] ?? '') . "<br>
                        " . (!empty($customer['gstin']) ? "GSTIN: " . htmlspecialchars($customer['gstin']) : "") . "
                    </td>
                    <td width='40%'>
                        <strong>Bill No:</strong> {$billNo}<br>
                        <strong>Date:</strong> {$billDate}<br>
                    </td>
                </tr>
            </table>

            <table class='items-table'>
                <thead>
                    <tr>
                        <th width='8%' style='text-align:center;'>#</th>
                        <th>Item Description</th>
                        <th width='12%' style='text-align:right;'>Qty</th>
                        <th width='15%' style='text-align:right;'>Rate</th>
                        <th width='18%' style='text-align:right;'>Amount</th>
                    </tr>
                </thead>
                <tbody>
                    {$itemsHtml}
                </tbody>
            </table>

            <table class='totals-table'>
                <tr>
                    <td><strong>Subtotal:</strong></td>
                    <td>Rs. {$subtotal}</td>
                </tr>
                " . (($bill['cgst_amount'] ?? 0) > 0 ? "<tr><td>CGST:</td><td>Rs. {$cgst}</td></tr>" : "") . "
                " . (($bill['sgst_amount'] ?? 0) > 0 ? "<tr><td>SGST:</td><td>Rs. {$sgst}</td></tr>" : "") . "
                " . (($bill['igst_amount'] ?? 0) > 0 ? "<tr><td>IGST:</td><td>Rs. {$igst}</td></tr>" : "") . "
                " . (($bill['round_off'] ?? 0) != 0 ? "<tr><td>Round Off:</td><td>Rs. {$roundOff}</td></tr>" : "") . "
                <tr class='grand-total'>
                    <td>Grand Total:</td>
                    <td>Rs. {$grandTotal}</td>
                </tr>
            </table>

            <div class='footer'>
                This is a computer generated invoice.
            </div>
        </body>
        </html>
        ";

        $dompdf->loadHtml($html);
        $dompdf->setPaper('A4', 'portrait');
        $dompdf->render();

        return $dompdf->output();
    }
}
