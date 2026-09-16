<?php

namespace App\Middleware;

use App\Helpers\ResponseHelper;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\RequestHandlerInterface as RequestHandler;
use Slim\Psr7\Response as SlimResponse;

class AuthMiddleware
{
    public function __invoke(Request $request, RequestHandler $handler): Response
    {
        $authHeader = $request->getHeaderLine('Authorization');
        $token = null;

        if (!empty($authHeader) && str_starts_with($authHeader, 'Bearer ')) {
            $token = substr($authHeader, 7);
        }

        if (!$token) {
            $res = new SlimResponse();
            return ResponseHelper::sendError($res, 'Authentication token required. Please log in.', [], 401);
        }

        $jwtSecret = $_ENV['JWT_SECRET'] ?? 'supersecret_printout_billing_jwt_key_2026';

        try {
            $decoded = JWT::decode($token, new Key($jwtSecret, 'HS256'));
            $request = $request->withAttribute('user', (array)$decoded);
        } catch (\Throwable $e) {
            $res = new SlimResponse();
            return ResponseHelper::sendError($res, 'Invalid or expired authentication token. Please log in again.', [], 403);
        }

        return $handler->handle($request);
    }
}
