<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class CompanyController
{
    public function getCompany(Request $request, Response $response): Response
    {
        $company = Database::fetchOne('SELECT * FROM companies ORDER BY id ASC LIMIT 1');
        return ResponseHelper::sendSuccess($response, $company ?: new \stdClass(), 'Company details fetched successfully');
    }

    public function saveCompany(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $companyName = trim($body['company_name'] ?? '');

        if (empty($companyName)) {
            return ResponseHelper::sendError($response, 'Company name is required', [], 400);
        }

        $existing = Database::fetchOne('SELECT id FROM companies ORDER BY id ASC LIMIT 1');

        if ($existing) {
            Database::execute(
                'UPDATE companies SET 
                    company_name = ?, gstin = ?, address = ?, city = ?, state = ?, 
                    state_code = ?, pincode = ?, phone = ?, email = ?, bank_name = ?, 
                    account_number = ?, ifsc_code = ?, branch_name = ?
                 WHERE id = ?',
                [
                    $companyName,
                    $body['gstin'] ?? null,
                    $body['address'] ?? null,
                    $body['city'] ?? null,
                    $body['state'] ?? 'TAMIL NADU',
                    $body['state_code'] ?? '33',
                    $body['pincode'] ?? null,
                    $body['phone'] ?? null,
                    $body['email'] ?? null,
                    $body['bank_name'] ?? null,
                    $body['account_number'] ?? null,
                    $body['ifsc_code'] ?? null,
                    $body['branch_name'] ?? null,
                    $existing['id']
                ]
            );
            $companyId = $existing['id'];
        } else {
            Database::execute(
                'INSERT INTO companies 
                    (company_name, gstin, address, city, state, state_code, pincode, phone, email, bank_name, account_number, ifsc_code, branch_name)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [
                    $companyName,
                    $body['gstin'] ?? null,
                    $body['address'] ?? null,
                    $body['city'] ?? null,
                    $body['state'] ?? 'TAMIL NADU',
                    $body['state_code'] ?? '33',
                    $body['pincode'] ?? null,
                    $body['phone'] ?? null,
                    $body['email'] ?? null,
                    $body['bank_name'] ?? null,
                    $body['account_number'] ?? null,
                    $body['ifsc_code'] ?? null,
                    $body['branch_name'] ?? null
                ]
            );
            $companyId = Database::lastInsertId();
        }

        $updated = Database::fetchOne('SELECT * FROM companies WHERE id = ?', [$companyId]);
        return ResponseHelper::sendSuccess($response, $updated, 'Company profile saved successfully');
    }
}
