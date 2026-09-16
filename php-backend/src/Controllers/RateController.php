<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class RateController
{
    public function getRates(Request $request, Response $response): Response
    {
        $sql = '
          SELECT 
            r.*,
            p.paper_name,
            pt.name AS printout_type_name
          FROM rates r
          JOIN papers p ON r.paper_id = p.id
          JOIN printout_types pt ON r.printout_type_id = pt.id
          ORDER BY p.paper_name ASC, pt.name ASC
        ';
        $rows = Database::fetchAll($sql);
        return ResponseHelper::sendSuccess($response, $rows, 'Rates fetched successfully');
    }

    public function lookupRate(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $paperId = $queryParams['paper_id'] ?? null;
        $printoutTypeId = $queryParams['printout_type_id'] ?? null;

        if (!$paperId || !$printoutTypeId) {
            return ResponseHelper::sendError($response, 'paper_id and printout_type_id query parameters are required', [], 400);
        }

        $sql = '
          SELECT r.*, p.paper_name, pt.name AS printout_type_name
          FROM rates r
          JOIN papers p ON r.paper_id = p.id
          JOIN printout_types pt ON r.printout_type_id = pt.id
          WHERE r.paper_id = ? AND r.printout_type_id = ? AND r.is_active = 1
        ';
        $rate = Database::fetchOne($sql, [$paperId, $printoutTypeId]);

        if (!$rate) {
            return ResponseHelper::sendError($response, 'No active rate configuration found for selected paper and printout type', [], 404);
        }

        return ResponseHelper::sendSuccess($response, $rate, 'Rate configuration lookup successful');
    }

    public function createRate(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $paperId = $body['paper_id'] ?? null;
        $printoutTypeId = $body['printout_type_id'] ?? null;
        $firstRate = $body['first_copy_rate'] ?? null;
        $addRate = $body['additional_copy_rate'] ?? null;

        if (!$paperId || !$printoutTypeId || $firstRate === null || $addRate === null) {
            return ResponseHelper::sendError($response, 'paper_id, printout_type_id, first_copy_rate, and additional_copy_rate are required', [], 400);
        }

        $existing = Database::fetchOne('SELECT id FROM rates WHERE paper_id = ? AND printout_type_id = ? AND is_active = 1', [$paperId, $printoutTypeId]);
        if ($existing) {
            return ResponseHelper::sendError($response, 'Rate configuration already exists for this Paper and Printout Type combination', [], 409);
        }

        Database::execute(
            'INSERT INTO rates (paper_id, printout_type_id, first_copy_rate, additional_copy_rate, click_rate, is_active) VALUES (?, ?, ?, ?, ?, 1)',
            [
                $paperId,
                $printoutTypeId,
                $firstRate,
                $addRate,
                $body['click_rate'] ?? null
            ]
        );

        $id = Database::lastInsertId();
        $created = Database::fetchOne('SELECT * FROM rates WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $created, 'Rate master created successfully', 201);
    }

    public function updateRate(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $body = (array)$request->getParsedBody();

        $existing = Database::fetchOne('SELECT id FROM rates WHERE id = ?', [$id]);
        if (!$existing) {
            return ResponseHelper::sendError($response, 'Rate master not found', [], 404);
        }

        Database::execute(
            'UPDATE rates SET paper_id = ?, printout_type_id = ?, first_copy_rate = ?, additional_copy_rate = ?, click_rate = ?, is_active = ? WHERE id = ?',
            [
                $body['paper_id'] ?? null,
                $body['printout_type_id'] ?? null,
                $body['first_copy_rate'] ?? 0.00,
                $body['additional_copy_rate'] ?? 0.00,
                $body['click_rate'] ?? null,
                isset($body['is_active']) ? (int)$body['is_active'] : 1,
                $id
            ]
        );

        $updated = Database::fetchOne('SELECT * FROM rates WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $updated, 'Rate master updated successfully');
    }
}
