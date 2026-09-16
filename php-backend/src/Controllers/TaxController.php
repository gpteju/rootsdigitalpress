<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class TaxController
{
    public function getTaxes(Request $request, Response $response): Response
    {
        $taxes = Database::fetchAll('SELECT * FROM taxes ORDER BY tax_name ASC');
        foreach ($taxes as &$tax) {
            $subTaxes = Database::fetchAll('SELECT * FROM tax_sub_taxes WHERE tax_id = ?', [$tax['id']]);
            $tax['sub_taxes'] = $subTaxes;
            $tax['subTaxes'] = $subTaxes;
        }
        return ResponseHelper::sendSuccess($response, $taxes, 'Tax master fetched successfully');
    }

    public function getTaxById(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $tax = Database::fetchOne('SELECT * FROM taxes WHERE id = ?', [$id]);
        if (!$tax) {
            return ResponseHelper::sendError($response, 'Tax master record not found', [], 404);
        }

        $subTaxes = Database::fetchAll('SELECT * FROM tax_sub_taxes WHERE tax_id = ?', [$id]);
        $tax['sub_taxes'] = $subTaxes;
        $tax['subTaxes'] = $subTaxes;
        return ResponseHelper::sendSuccess($response, $tax, 'Tax master details fetched successfully');
    }

    public function createTax(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $taxName = trim($body['tax_name'] ?? '');
        $taxPct = $body['tax_percentage'] ?? null;
        $subTaxes = $body['sub_taxes'] ?? $body['subTaxes'] ?? $body['tax_sub_taxes'] ?? [];

        if (empty($taxName) || $taxPct === null) {
            return ResponseHelper::sendError($response, 'tax_name and tax_percentage are required', [], 400);
        }

        $createdTax = Database::withTransaction(function ($pdo) use ($taxName, $taxPct, $subTaxes) {
            $stmt = $pdo->prepare('INSERT INTO taxes (tax_name, tax_percentage, is_active) VALUES (?, ?, 1)');
            $stmt->execute([$taxName, $taxPct]);
            $taxId = $pdo->lastInsertId();

            if (is_array($subTaxes)) {
                $subStmt = $pdo->prepare('INSERT INTO tax_sub_taxes (tax_id, sub_tax_name, rate_percentage, tax_type) VALUES (?, ?, ?, ?)');
                foreach ($subTaxes as $st) {
                    $subStmt->execute([
                        $taxId,
                        $st['sub_tax_name'] ?? '',
                        $st['rate_percentage'] ?? 0,
                        $st['tax_type'] ?? 'INTRA_STATE'
                    ]);
                }
            }

            $tStmt = $pdo->prepare('SELECT * FROM taxes WHERE id = ?');
            $tStmt->execute([$taxId]);
            $tax = $tStmt->fetch();

            $stStmt = $pdo->prepare('SELECT * FROM tax_sub_taxes WHERE tax_id = ?');
            $stStmt->execute([$taxId]);
            $subList = $stStmt->fetchAll();
            $tax['sub_taxes'] = $subList;
            $tax['subTaxes'] = $subList;

            return $tax;
        });

        return ResponseHelper::sendSuccess($response, $createdTax, 'Tax master created successfully', 201);
    }

    public function updateTax(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $body = (array)$request->getParsedBody();

        $existing = Database::fetchOne('SELECT id FROM taxes WHERE id = ?', [$id]);
        if (!$existing) {
            return ResponseHelper::sendError($response, 'Tax master not found', [], 404);
        }

        $taxName = trim($body['tax_name'] ?? '');
        $taxPct = $body['tax_percentage'] ?? null;
        $subTaxes = $body['sub_taxes'] ?? $body['subTaxes'] ?? $body['tax_sub_taxes'] ?? [];

        $updatedTax = Database::withTransaction(function ($pdo) use ($id, $taxName, $taxPct, $subTaxes, $body) {
            $stmt = $pdo->prepare('UPDATE taxes SET tax_name = ?, tax_percentage = ?, is_active = ? WHERE id = ?');
            $stmt->execute([
                $taxName,
                $taxPct,
                isset($body['is_active']) ? (int)$body['is_active'] : 1,
                $id
            ]);

            $delStmt = $pdo->prepare('DELETE FROM tax_sub_taxes WHERE tax_id = ?');
            $delStmt->execute([$id]);

            if (is_array($subTaxes)) {
                $subStmt = $pdo->prepare('INSERT INTO tax_sub_taxes (tax_id, sub_tax_name, rate_percentage, tax_type) VALUES (?, ?, ?, ?)');
                foreach ($subTaxes as $st) {
                    $subStmt->execute([
                        $id,
                        $st['sub_tax_name'] ?? '',
                        $st['rate_percentage'] ?? 0,
                        $st['tax_type'] ?? 'INTRA_STATE'
                    ]);
                }
            }

            $tStmt = $pdo->prepare('SELECT * FROM taxes WHERE id = ?');
            $tStmt->execute([$id]);
            $tax = $tStmt->fetch();

            $stStmt = $pdo->prepare('SELECT * FROM tax_sub_taxes WHERE tax_id = ?');
            $stStmt->execute([$id]);
            $subList = $stStmt->fetchAll();
            $tax['sub_taxes'] = $subList;
            $tax['subTaxes'] = $subList;

            return $tax;
        });

        return ResponseHelper::sendSuccess($response, $updatedTax, 'Tax master updated successfully');
    }
}
