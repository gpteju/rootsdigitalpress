<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class PaperMastersController
{
    // 1. PAPER TYPES
    public function getPaperTypes(Request $request, Response $response): Response
    {
        $rows = Database::fetchAll('SELECT * FROM paper_types ORDER BY name ASC');
        return ResponseHelper::sendSuccess($response, $rows, 'Paper types fetched successfully');
    }

    public function createPaperType(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $name = trim($body['name'] ?? '');
        if (empty($name)) {
            return ResponseHelper::sendError($response, 'Paper type name is required', [], 400);
        }
        Database::execute('INSERT INTO paper_types (name, description, is_active) VALUES (?, ?, 1)', [$name, $body['description'] ?? null]);
        $id = Database::lastInsertId();
        $created = Database::fetchOne('SELECT * FROM paper_types WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $created, 'Paper type created successfully', 201);
    }

    public function updatePaperType(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $body = (array)$request->getParsedBody();
        $name = trim($body['name'] ?? '');
        Database::execute('UPDATE paper_types SET name = ?, description = ?, is_active = ? WHERE id = ?', [
            $name,
            $body['description'] ?? null,
            isset($body['is_active']) ? (int)$body['is_active'] : 1,
            $id
        ]);
        $updated = Database::fetchOne('SELECT * FROM paper_types WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $updated, 'Paper type updated successfully');
    }

    // 2. PAPER GSM
    public function getPaperGsm(Request $request, Response $response): Response
    {
        $rows = Database::fetchAll('SELECT * FROM paper_gsm ORDER BY gsm_value ASC');
        return ResponseHelper::sendSuccess($response, $rows, 'Paper GSM values fetched successfully');
    }

    public function createPaperGsm(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $val = $body['gsm_value'] ?? null;
        if (!$val) {
            return ResponseHelper::sendError($response, 'GSM value is required', [], 400);
        }
        Database::execute('INSERT INTO paper_gsm (gsm_value, description, is_active) VALUES (?, ?, 1)', [$val, $body['description'] ?? null]);
        $id = Database::lastInsertId();
        $created = Database::fetchOne('SELECT * FROM paper_gsm WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $created, 'Paper GSM created successfully', 201);
    }

    public function updatePaperGsm(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $body = (array)$request->getParsedBody();
        $val = $body['gsm_value'] ?? null;
        Database::execute('UPDATE paper_gsm SET gsm_value = ?, description = ?, is_active = ? WHERE id = ?', [
            $val,
            $body['description'] ?? null,
            isset($body['is_active']) ? (int)$body['is_active'] : 1,
            $id
        ]);
        $updated = Database::fetchOne('SELECT * FROM paper_gsm WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $updated, 'Paper GSM updated successfully');
    }

    // 3. PAPER SIZES
    public function getPaperSizes(Request $request, Response $response): Response
    {
        $rows = Database::fetchAll('SELECT * FROM paper_sizes ORDER BY name ASC');
        return ResponseHelper::sendSuccess($response, $rows, 'Paper sizes fetched successfully');
    }

    public function createPaperSize(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $name = trim($body['name'] ?? '');
        if (empty($name)) {
            return ResponseHelper::sendError($response, 'Paper size name is required', [], 400);
        }
        Database::execute('INSERT INTO paper_sizes (name, description, is_active) VALUES (?, ?, 1)', [$name, $body['description'] ?? null]);
        $id = Database::lastInsertId();
        $created = Database::fetchOne('SELECT * FROM paper_sizes WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $created, 'Paper size created successfully', 201);
    }

    public function updatePaperSize(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $body = (array)$request->getParsedBody();
        $name = trim($body['name'] ?? '');
        Database::execute('UPDATE paper_sizes SET name = ?, description = ?, is_active = ? WHERE id = ?', [
            $name,
            $body['description'] ?? null,
            isset($body['is_active']) ? (int)$body['is_active'] : 1,
            $id
        ]);
        $updated = Database::fetchOne('SELECT * FROM paper_sizes WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $updated, 'Paper size updated successfully');
    }

    // 4. UNIFIED PAPERS
    public function getAllPapers(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $activeOnly = ($queryParams['active_only'] ?? '') === 'true';

        $sql = '
          SELECT 
            p.*,
            pt.name AS paper_type_name,
            pg.gsm_value AS gsm_value,
            ps.name AS paper_size_name
          FROM papers p
          JOIN paper_types pt ON p.paper_type_id = pt.id
          JOIN paper_gsm pg ON p.paper_gsm_id = pg.id
          JOIN paper_sizes ps ON p.paper_size_id = ps.id
        ';
        if ($activeOnly) {
            $sql .= ' WHERE p.is_active = 1';
        }
        $sql .= ' ORDER BY p.paper_name ASC';

        $rows = Database::fetchAll($sql);
        return ResponseHelper::sendSuccess($response, $rows, 'Papers fetched successfully');
    }

    public function createPaper(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $paperName = trim($body['paper_name'] ?? '');
        $typeId = $body['paper_type_id'] ?? null;
        $gsmId = $body['paper_gsm_id'] ?? null;
        $sizeId = $body['paper_size_id'] ?? null;

        if (empty($paperName) || !$typeId || !$gsmId || !$sizeId) {
            return ResponseHelper::sendError($response, 'Paper name, type, GSM, and size are required', [], 400);
        }

        $openStock = (float)($body['opening_stock'] ?? 0.00);

        Database::execute(
            'INSERT INTO papers 
                (paper_name, paper_type_id, paper_gsm_id, paper_size_id, purchase_unit, opening_stock, current_stock, reorder_level, is_active) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)',
            [
                $paperName,
                $typeId,
                $gsmId,
                $sizeId,
                $body['purchase_unit'] ?? 'Sheet',
                $openStock,
                $openStock,
                $body['reorder_level'] ?? 100.00
            ]
        );

        $paperId = Database::lastInsertId();

        if ($openStock > 0) {
            Database::execute(
                "INSERT INTO stock_ledger 
                    (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks) 
                 VALUES (?, 'OPENING_STOCK', 'INIT', ?, 0.00, ?, 'Initial opening stock')",
                [$paperId, $openStock, $openStock]
            );
        }

        $created = Database::fetchOne('SELECT * FROM papers WHERE id = ?', [$paperId]);
        return ResponseHelper::sendSuccess($response, $created, 'Paper master created successfully', 201);
    }

    public function updatePaper(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $body = (array)$request->getParsedBody();

        $existing = Database::fetchOne('SELECT id FROM papers WHERE id = ?', [$id]);
        if (!$existing) {
            return ResponseHelper::sendError($response, 'Paper not found', [], 404);
        }

        Database::execute(
            'UPDATE papers SET 
                paper_name = ?, paper_type_id = ?, paper_gsm_id = ?, paper_size_id = ?, 
                purchase_unit = ?, reorder_level = ?, is_active = ? 
             WHERE id = ?',
            [
                $body['paper_name'] ?? '',
                $body['paper_type_id'] ?? null,
                $body['paper_gsm_id'] ?? null,
                $body['paper_size_id'] ?? null,
                $body['purchase_unit'] ?? 'Sheet',
                $body['reorder_level'] ?? 100.00,
                isset($body['is_active']) ? (int)$body['is_active'] : 1,
                $id
            ]
        );

        $updated = Database::fetchOne('SELECT * FROM papers WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $updated, 'Paper master updated successfully');
    }
}
