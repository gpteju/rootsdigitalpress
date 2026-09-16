<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class StockController
{
    public function getStockSummary(Request $request, Response $response): Response
    {
        $sql = '
          SELECT 
            p.id AS paper_id,
            p.paper_name,
            pt.name AS paper_type_name,
            pg.gsm_value,
            ps.name AS paper_size_name,
            p.purchase_unit,
            p.opening_stock,
            p.current_stock,
            p.reorder_level,
            CASE WHEN p.current_stock <= p.reorder_level THEN 1 ELSE 0 END AS is_low_stock
          FROM papers p
          JOIN paper_types pt ON p.paper_type_id = pt.id
          JOIN paper_gsm pg ON p.paper_gsm_id = pg.id
          JOIN paper_sizes ps ON p.paper_size_id = ps.id
          ORDER BY p.paper_name ASC
        ';
        $rows = Database::fetchAll($sql);
        return ResponseHelper::sendSuccess($response, $rows, 'Stock summary fetched successfully');
    }

    public function getStockLedger(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $paperId = $queryParams['paper_id'] ?? null;
        $startDate = $queryParams['start_date'] ?? null;
        $endDate = $queryParams['end_date'] ?? null;

        $sql = '
          SELECT 
            sl.*,
            p.paper_name,
            p.purchase_unit
          FROM stock_ledger sl
          JOIN papers p ON sl.paper_id = p.id
          WHERE 1=1
        ';
        $params = [];

        if (!empty($paperId)) {
            $sql .= ' AND sl.paper_id = ?';
            $params[] = $paperId;
        }
        if (!empty($startDate)) {
            $sql .= ' AND sl.transaction_date >= ?';
            $params[] = $startDate;
        }
        if (!empty($endDate)) {
            $sql .= ' AND sl.transaction_date <= ?';
            $params[] = $endDate;
        }

        $sql .= ' ORDER BY sl.id DESC';
        $ledger = Database::fetchAll($sql, $params);

        return ResponseHelper::sendSuccess($response, $ledger, 'Stock ledger history fetched successfully');
    }

    public function adjustStock(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $paperId = $body['paper_id'] ?? null;
        $adjType = strtoupper(trim($body['adjustment_type'] ?? ''));
        $qty = (float)($body['quantity'] ?? 0);
        $remarks = trim($body['remarks'] ?? '');

        if (!$paperId || !in_array($adjType, ['IN', 'OUT']) || $qty <= 0) {
            return ResponseHelper::sendError($response, 'paper_id, valid adjustment_type (IN/OUT), and positive quantity are required', [], 400);
        }

        $paper = Database::fetchOne('SELECT * FROM papers WHERE id = ?', [$paperId]);
        if (!$paper) {
            return ResponseHelper::sendError($response, 'Paper not found', [], 404);
        }

        $qtyIn = 0.0;
        $qtyOut = 0.0;
        $newStock = (float)$paper['current_stock'];

        if ($adjType === 'IN') {
            $qtyIn = $qty;
            $newStock += $qty;
        } else {
            if ($newStock < $qty) {
                return ResponseHelper::sendError($response, "Cannot deduct {$qty} {$paper['purchase_unit']}. Current stock is {$newStock}.", [], 400);
            }
            $qtyOut = $qty;
            $newStock -= $qty;
        }

        Database::execute('UPDATE papers SET current_stock = ? WHERE id = ?', [$newStock, $paperId]);
        Database::execute(
            "INSERT INTO stock_ledger (paper_id, transaction_type, reference_id, qty_in, qty_out, balance_qty, remarks)
             VALUES (?, 'ADJUSTMENT', 'MANUAL', ?, ?, ?, ?)",
            [$paperId, $qtyIn, $qtyOut, $newStock, $remarks ?: 'Manual Stock Adjustment']
        );

        return ResponseHelper::sendSuccess($response, ['paper_id' => $paperId, 'new_stock' => $newStock], 'Stock adjusted successfully');
    }
}
