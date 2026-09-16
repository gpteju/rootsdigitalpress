<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class CustomerController
{
    public function getAll(Request $request, Response $response): Response
    {
        $queryParams = $request->getQueryParams();
        $search = trim($queryParams['search'] ?? '');
        $type = trim($queryParams['customer_type'] ?? '');

        $sql = 'SELECT * FROM customers WHERE is_active = 1';
        $params = [];

        if (!empty($search)) {
            $sql .= ' AND (customer_name LIKE ? OR phone LIKE ? OR email LIKE ?)';
            $searchTerm = "%{$search}%";
            $params = array_merge($params, [$searchTerm, $searchTerm, $searchTerm]);
        }
        if (!empty($type)) {
            $sql .= ' AND customer_type = ?';
            $params[] = $type;
        }

        $sql .= ' ORDER BY customer_name ASC';
        $customers = Database::fetchAll($sql, $params);

        return ResponseHelper::sendSuccess($response, $customers, 'Customers fetched successfully');
    }

    public function getById(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $customer = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$id]);

        if (!$customer) {
            return ResponseHelper::sendError($response, 'Customer not found', [], 404);
        }

        return ResponseHelper::sendSuccess($response, $customer, 'Customer details fetched successfully');
    }

    public function create(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $name = trim($body['customer_name'] ?? '');

        if (empty($name)) {
            return ResponseHelper::sendError($response, 'Customer name is required', [], 400);
        }

        Database::execute(
            'INSERT INTO customers 
                (customer_name, customer_type, address, city, state, state_code, pincode, phone, email, gstin, advance_credit, is_active)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)',
            [
                $name,
                $body['customer_type'] ?? 'NORMAL',
                $body['address'] ?? null,
                $body['city'] ?? null,
                $body['state'] ?? 'TAMIL NADU',
                $body['state_code'] ?? '33',
                $body['pincode'] ?? null,
                $body['phone'] ?? null,
                $body['email'] ?? null,
                $body['gstin'] ?? null,
                $body['advance_credit'] ?? 0.00
            ]
        );

        $id = Database::lastInsertId();
        $created = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$id]);

        return ResponseHelper::sendSuccess($response, $created, 'Customer created successfully', 201);
    }

    public function update(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $body = (array)$request->getParsedBody();

        $existing = Database::fetchOne('SELECT id FROM customers WHERE id = ?', [$id]);
        if (!$existing) {
            return ResponseHelper::sendError($response, 'Customer not found', [], 404);
        }

        $name = trim($body['customer_name'] ?? '');
        if (empty($name)) {
            return ResponseHelper::sendError($response, 'Customer name is required', [], 400);
        }

        Database::execute(
            'UPDATE customers SET 
                customer_name = ?, customer_type = ?, address = ?, city = ?, state = ?, 
                state_code = ?, pincode = ?, phone = ?, email = ?, gstin = ?, 
                advance_credit = ?, is_active = ?
             WHERE id = ?',
            [
                $name,
                $body['customer_type'] ?? 'NORMAL',
                $body['address'] ?? null,
                $body['city'] ?? null,
                $body['state'] ?? 'TAMIL NADU',
                $body['state_code'] ?? '33',
                $body['pincode'] ?? null,
                $body['phone'] ?? null,
                $body['email'] ?? null,
                $body['gstin'] ?? null,
                $body['advance_credit'] ?? 0.00,
                isset($body['is_active']) ? (int)$body['is_active'] : 1,
                $id
            ]
        );

        $updated = Database::fetchOne('SELECT * FROM customers WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, $updated, 'Customer updated successfully');
    }

    public function delete(Request $request, Response $response, array $args): Response
    {
        $id = (int)$args['id'];
        $existing = Database::fetchOne('SELECT id FROM customers WHERE id = ?', [$id]);
        if (!$existing) {
            return ResponseHelper::sendError($response, 'Customer not found', [], 404);
        }

        Database::execute('UPDATE customers SET is_active = 0 WHERE id = ?', [$id]);
        return ResponseHelper::sendSuccess($response, null, 'Customer deactivated successfully');
    }
}
