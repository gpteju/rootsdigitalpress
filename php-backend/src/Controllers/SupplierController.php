<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class SupplierController
{
    public function getAll(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $search = trim($queryParams['search'] ?? '');

        $sql = 'SELECT * FROM suppliers WHERE is_active = 1';
        $params = [];

        if (!empty($search)) {
            $sql .= ' AND (supplier_name LIKE ? OR phone LIKE ? OR email LIKE ?)';
            $searchTerm = "%{$search}%";
            $params = array_merge($params, [$searchTerm, $searchTerm, $searchTerm]);
        }

        $sql .= ' ORDER BY supplier_name ASC';
        $suppliers = Database::fetchAll($sql, $params);

        return ResponseHelper::sendSuccess($response, $suppliers, 'Suppliers fetched successfully');
    }

    public function getById(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $supplier = Database::fetchOne('SELECT * FROM suppliers WHERE id = ?', [$id]);

        if (!$supplier) {
            return ResponseHelper::sendError($response, 'Supplier not found', [], 404);
        }

        return ResponseHelper::sendSuccess($response, $supplier, 'Supplier details fetched successfully');
    }

    public function create(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $name = trim($body['supplier_name'] ?? '');

        if (empty($name)) {
            return ResponseHelper::sendError($response, 'Supplier name is required', [], 400);
        }

        Database::execute(
            'INSERT INTO suppliers 
                (supplier_name, contact_person, address, city, state, state_code, pincode, phone, email, gstin, is_active)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)',
            [
                $name,
                $body['contact_person'] ?? null,
                $body['address'] ?? null,
                $body['city'] ?? null,
                $body['state'] ?? 'TAMIL NADU',
                $body['state_code'] ?? '33',
                $body['pincode'] ?? null,
                $body['phone'] ?? null,
                $body['email'] ?? null,
                $body['gstin'] ?? null
            ]
        );

        $id = Database::lastInsertId();
        $created = Database::fetchOne('SELECT * FROM suppliers WHERE id = ?', [$id]);

        return ResponseHelper::sendSuccess($response, $created, 'Supplier created successfully', 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $body = (array)$request->getParsedBody();

        $existing = Database::fetchOne('SELECT id FROM suppliers WHERE id = ?', [$id]);
        if (!$existing) {
            return ResponseHelper::sendError($response, 'Supplier not found', [], 404);
        }

        $name = trim($body['supplier_name'] ?? '');
        if (empty($name)) {
            return ResponseHelper::sendError($response, 'Supplier name is required', [], 400);
        }

        Database::execute(
            'UPDATE suppliers SET 
                supplier_name = ?, contact_person = ?, address = ?, city = ?, state = ?, 
                state_code = ?, pincode = ?, phone = ?, email = ?, gstin = ?, is_active = ?
             WHERE id = ?',
            [
                $name,
                $body['contact_person'] ?? null,
                $body['address'] ?? null,
                $body['city'] ?? null,
                $body['state'] ?? 'TAMIL NADU',
                $body['state_code'] ?? '33',
                $body['pincode'] ?? null,
                $body['phone'] ?? null,
                $body['email'] ?? null,
                $body['gstin'] ?? null,
                isset($body['is_active']) ? (int)$body['is_active'] : 1,
                $id
            ]
        );

        $updated = Database::fetchOne('SELECT * FROM suppliers WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $updated, 'Supplier updated successfully');
    }

    public function delete(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $existing = Database::fetchOne('SELECT id FROM suppliers WHERE id = ?', [$id]);
        if (!$existing) {
            return ResponseHelper::sendError($response, 'Supplier not found', [], 404);
        }

        Database::execute('UPDATE suppliers SET is_active = 0 WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, null, 'Supplier deactivated successfully');
    }
}
