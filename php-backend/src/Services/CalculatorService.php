<?php

namespace App\Services;

class CalculatorService
{
    public static function calculateItemAmount(float|int $quantity, float|int $firstCopyRate, float|int $additionalCopyRate): array
    {
        $qty = (float)$quantity;
        $firstRate = (float)$firstCopyRate;
        $addRate = (float)$additionalCopyRate;

        if ($qty <= 0) {
            return ['lineAmount' => 0.0, 'effectiveRatePerUnit' => 0.0];
        }

        if ($qty == 1.0) {
            $lineAmount = $firstRate;
        } else {
            $remainingQty = $qty - 1.0;
            $lineAmount = $firstRate + ($remainingQty * $addRate);
        }

        $roundedLineAmount = round($lineAmount, 2);
        $effectiveRate = round($lineAmount / $qty, 2);

        return [
            'lineAmount' => $roundedLineAmount,
            'effectiveRatePerUnit' => $effectiveRate
        ];
    }

    public static function calculateInvoiceTax(
        ?string $companyState,
        ?string $customerState,
        float|int $totalSubtotal,
        ?array $taxMaster,
        ?string $companyStateCode = null,
        ?string $customerStateCode = null
    ): array {
        $subtotal = (float)$totalSubtotal;
        $compCode = strtoupper(trim($companyStateCode ?? ''));
        $custCode = strtoupper(trim($customerStateCode ?? ''));
        $compState = strtoupper(trim($companyState ?? ''));
        $custState = strtoupper(trim($customerState ?? ''));

        $isInterstate = (!empty($compCode) && !empty($custCode))
            ? ($compCode !== $custCode)
            : ($compState !== $custState);

        $cgstAmount = 0.0;
        $sgstAmount = 0.0;
        $igstAmount = 0.0;

        if (!$taxMaster || empty($taxMaster['tax_percentage'])) {
            return [
                'isInterstate' => $isInterstate,
                'cgstAmount' => 0.0,
                'sgstAmount' => 0.0,
                'igstAmount' => 0.0,
                'totalTaxAmount' => 0.0,
                'grandTotal' => round($subtotal, 2)
            ];
        }

        $subTaxes = $taxMaster['sub_taxes'] ?? [];
        $taxPct = (float)($taxMaster['tax_percentage'] ?? 0);

        if (!$isInterstate) {
            foreach ($subTaxes as $st) {
                $ratePct = (float)($st['rate_percentage'] ?? 0);
                $taxVal = ($subtotal * $ratePct) / 100.0;
                $subTaxName = strtoupper($st['sub_tax_name'] ?? '');

                if (str_contains($subTaxName, 'CGST')) {
                    $cgstAmount += $taxVal;
                } elseif (str_contains($subTaxName, 'SGST')) {
                    $sgstAmount += $taxVal;
                }
            }
            if (empty($subTaxes) && $taxPct > 0) {
                $halfRate = $taxPct / 2.0;
                $cgstAmount = ($subtotal * $halfRate) / 100.0;
                $sgstAmount = ($subtotal * $halfRate) / 100.0;
            }
        } else {
            foreach ($subTaxes as $st) {
                $subTaxName = strtoupper($st['sub_tax_name'] ?? '');
                if (str_contains($subTaxName, 'IGST')) {
                    $ratePct = (float)($st['rate_percentage'] ?? 0);
                    $igstAmount += ($subtotal * $ratePct) / 100.0;
                }
            }
            if ($igstAmount == 0.0 && $taxPct > 0) {
                $igstAmount = ($subtotal * $taxPct) / 100.0;
            }
        }

        $totalTaxAmount = $cgstAmount + $sgstAmount + $igstAmount;
        $grandTotal = $subtotal + $totalTaxAmount;

        return [
            'isInterstate' => $isInterstate,
            'cgstAmount' => round($cgstAmount, 2),
            'sgstAmount' => round($sgstAmount, 2),
            'igstAmount' => round($igstAmount, 2),
            'totalTaxAmount' => round($totalTaxAmount, 2),
            'grandTotal' => round($grandTotal, 2)
        ];
    }
}
