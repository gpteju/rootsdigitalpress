<?php

namespace App\Controllers;

use App\Config\Database;
use App\Helpers\ResponseHelper;
use Firebase\JWT\JWT;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class AuthController
{
    public function login(Request $request, Response $response): Response
    {
        $body = (array)$request->getParsedBody();
        $username = trim($body['username'] ?? '');
        $password = trim($body['password'] ?? '');

        if (empty($username) || empty($password)) {
            return ResponseHelper::sendError($response, 'Username and password are required', [], 400);
        }

        $user = Database::fetchOne('SELECT * FROM users WHERE username = ? AND is_active = 1', [$username]);
        if (!$user) {
            return ResponseHelper::sendError($response, 'Invalid username or password', [], 401);
        }

        $isMatch = password_verify($password, $user['password_hash']);
        if (!$isMatch) {
            return ResponseHelper::sendError($response, 'Invalid username or password', [], 401);
        }

        $jwtSecret = $_ENV['JWT_SECRET'] ?? 'supersecret_printout_billing_jwt_key_2026';
        $payload = [
            'id' => $user['id'],
            'username' => $user['username'],
            'full_name' => $user['full_name'],
            'email' => $user['email'],
            'role' => $user['role'],
            'iat' => time(),
            'exp' => time() + (24 * 60 * 60)
        ];

        $token = JWT::encode($payload, $jwtSecret, 'HS256');

        unset($user['password_hash']);

        return ResponseHelper::sendSuccess($response, [
            'token' => $token,
            'user' => $user
        ], 'Login successful');
    }

    public function getMe(Request $request, Response $response): Response
    {
        $userData = $request->getAttribute('user');
        if (!$userData || empty($userData['id'])) {
            return ResponseHelper::sendError($response, 'User not authenticated', [], 401);
        }

        $user = Database::fetchOne('SELECT id, username, full_name, email, role, is_active, created_at FROM users WHERE id = ?', [$userData['id']]);
        if (!$user) {
            return ResponseHelper::sendError($response, 'User profile not found', [], 404);
        }

        return ResponseHelper::sendSuccess($response, ['user' => $user], 'User profile fetched successfully');
    }
}
