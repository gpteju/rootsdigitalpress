<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class PrintoutTypeController
{
    public function getPrintoutTypes(Request $request, Response $response): Response
    {
        $rows = Database::fetchAll('SELECT * FROM printout_types ORDER BY name ASC');
        return ResponseHelper::sendSuccess($response, $rows, 'Printout types fetched successfully');
    }

    public function createPrintoutType(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $name = trim($body['name'] ?? $body['type_name'] ?? '');

        if (empty($name)) {
            return ResponseHelper::sendError($response, 'Printout type name is required', [], 400);
        }

        Database::execute(
            'INSERT INTO printout_types (name, side_type, color_type, description, is_active) VALUES (?, ?, ?, ?, 1)',
            [
                $name,
                $body['side_type'] ?? 'Single Side',
                $body['color_type'] ?? 'Black & White',
                $body['description'] ?? null
            ]
        );

        $id = Database::lastInsertId();
        $created = Database::fetchOne('SELECT * FROM printout_types WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $created, 'Printout type created successfully', 201);
    }

    public function updatePrintoutType(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $body = (array)$request->getParsedBody();

        $existing = Database::fetchOne('SELECT id FROM printout_types WHERE id = ?', [$id]);
        if (!$existing) {
            return ResponseHelper::sendError($response, 'Printout type not found', [], 404);
        }

        $name = trim($body['name'] ?? $body['type_name'] ?? '');

        Database::execute(
            'UPDATE printout_types SET name = ?, side_type = ?, color_type = ?, description = ?, is_active = ? WHERE id = ?',
            [
                $name,
                $body['side_type'] ?? 'Single Side',
                $body['color_type'] ?? 'Black & White',
                $body['description'] ?? null,
                isset($body['is_active']) ? (int)$body['is_active'] : 1,
                $id
            ]
        );

        $updated = Database::fetchOne('SELECT * FROM printout_types WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $updated, 'Printout type updated successfully');
    }
}
