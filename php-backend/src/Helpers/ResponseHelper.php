<?php

namespace App\Helpers;

use Psr\Http\Message\ResponseInterface as Response;

class ResponseHelper
{
    public static function sendSuccess(Response $response, mixed $data = [], string $message = 'Success', int $statusCode = 200): Response
    {
        $payload = json_encode([
            'success' => true,
            'message' => $message,
            'data' => $data ?? [],
            'errors' => []
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

        $response->getBody()->write($payload);
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus($statusCode);
    }

    public static function sendError(Response $response, string $message = 'An error occurred', array|string $errors = [], int $statusCode = 400): Response
    {
        $errArray = is_array($errors) ? $errors : ($errors !== '' ? [$errors] : []);
        $payload = json_encode([
            'success' => false,
            'message' => $message,
            'data' => null,
            'errors' => $errArray
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

        $response->getBody()->write($payload);
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus($statusCode);
    }
}
