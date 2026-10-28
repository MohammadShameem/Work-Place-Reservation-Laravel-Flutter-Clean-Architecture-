<?php

declare(strict_types=1);

namespace App\Domain\Auth\Presentation\Http\Controllers;

use App\Domain\Auth\Application\UseCases\LoginUseCase;
use App\Domain\Auth\Application\UseCases\LogoutUseCase;
use App\Domain\Auth\Application\UseCases\RefreshTokenUseCase;
use App\Domain\Auth\Application\UseCases\RegisterUserUseCase;
use App\Domain\Auth\Domain\Exceptions\InvalidCredentialsException;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;
use OpenApi\Attributes as OA;

#[OA\Schema(
    schema: 'User',
    required: ['id', 'name', 'email'],
    properties: [
        new OA\Property(property: 'id', type: 'integer', example: 1),
        new OA\Property(property: 'name', type: 'string', example: 'Momin'),
        new OA\Property(property: 'email', type: 'string', format: 'email', example: 'momin@example.com'),
        new OA\Property(property: 'created_at', type: 'string', format: 'date-time'),
        new OA\Property(property: 'updated_at', type: 'string', format: 'date-time'),
    ]
)]
#[OA\Schema(
    schema: 'ValidationError',
    properties: [
        new OA\Property(property: 'message', type: 'string', example: 'The email field is required.'),
        new OA\Property(
            property: 'errors',
            type: 'object',
            example: ['email' => ['The email field is required.']]
        ),
    ]
)]
#[OA\Schema(
    schema: 'TokenPair',
    properties: [
        new OA\Property(property: 'user', ref: '#/components/schemas/User'),
        new OA\Property(property: 'access_token', type: 'string', example: '3|accessTokenPlainText...', description: 'Send as "Authorization: Bearer <access_token>" on every request'),
        new OA\Property(property: 'access_token_expires_at', type: 'string', format: 'date-time'),
        new OA\Property(property: 'refresh_token', type: 'string', example: '4|refreshTokenPlainText...', description: 'Keep this safe; use it only to call /api/refresh'),
        new OA\Property(property: 'refresh_token_expires_at', type: 'string', format: 'date-time'),
    ]
)]
class AuthController extends Controller
{
    public function __construct(
        private readonly RegisterUserUseCase $registerUser,
        private readonly LoginUseCase $login,
        private readonly RefreshTokenUseCase $refreshToken,
        private readonly LogoutUseCase $logout,
    ) {
    }

    #[OA\Post(
        path: '/api/register',
        description: 'Creates a user and immediately returns an access/refresh token pair, so the app can log the user straight in.',
        summary: 'Register a new account',
        tags: ['Auth'],
        requestBody: new OA\RequestBody(
            required: true,
            content: new OA\JsonContent(
                required: ['name', 'email', 'password'],
                properties: [
                    new OA\Property(property: 'name', type: 'string', example: 'Momin'),
                    new OA\Property(property: 'email', type: 'string', format: 'email', example: 'momin@example.com'),
                    new OA\Property(property: 'password', type: 'string', format: 'password', example: 'password123'),
                    new OA\Property(property: 'device_name', type: 'string', nullable: true, example: 'flutter-android', description: 'Free-text label for the issued tokens'),
                ]
            )
        ),
        responses: [
            new OA\Response(response: 201, description: 'Account created', content: new OA\JsonContent(ref: '#/components/schemas/TokenPair')),
            new OA\Response(response: 422, description: 'Validation failed (e.g. email already taken)', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
        ]
    )]
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', Password::defaults()],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $result = $this->registerUser->handle($data, $data['device_name'] ?? null);

        return response()->json(
            array_merge(['user' => $result['user']], $result['tokens']->toArray()),
            201
        );
    }

    #[OA\Post(
        path: '/api/login',
        description: 'Verifies the email/password and issues a new access/refresh token pair. Previous sessions (other devices) stay valid.',
        summary: 'Log in',
        tags: ['Auth'],
        requestBody: new OA\RequestBody(
            required: true,
            content: new OA\JsonContent(
                required: ['email', 'password'],
                properties: [
                    new OA\Property(property: 'email', type: 'string', format: 'email', example: 'momin@example.com'),
                    new OA\Property(property: 'password', type: 'string', format: 'password', example: 'password123'),
                    new OA\Property(property: 'device_name', type: 'string', nullable: true, example: 'flutter-android'),
                ]
            )
        ),
        responses: [
            new OA\Response(response: 200, description: 'Logged in', content: new OA\JsonContent(ref: '#/components/schemas/TokenPair')),
            new OA\Response(response: 422, description: 'Wrong email or password', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
        ]
    )]
    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        try {
            $result = $this->login->handle($data['email'], $data['password'], $data['device_name'] ?? null);
        } catch (InvalidCredentialsException $e) {
            throw ValidationException::withMessages(['email' => [$e->getMessage()]]);
        }

        return response()->json(array_merge(['user' => $result['user']], $result['tokens']->toArray()));
    }

    #[OA\Post(
        path: '/api/refresh',
        description: 'Trades a still-valid refresh token for a brand new access/refresh pair (rotation: the refresh '
            .'token just used stops working). Call this when the API starts returning 401 with an access token. '
            .'Must be called with the refresh token itself as the Bearer token, not the access token.',
        summary: 'Get a new access token',
        security: [['sanctum' => []]],
        tags: ['Auth'],
        responses: [
            new OA\Response(response: 200, description: 'New token pair', content: new OA\JsonContent(ref: '#/components/schemas/TokenPair')),
            new OA\Response(response: 401, description: 'Refresh token missing, invalid, or expired — the user must log in again'),
            new OA\Response(response: 403, description: 'A valid token was sent, but it is an access token, not a refresh token'),
        ]
    )]
    public function refresh(Request $request): JsonResponse
    {
        $result = $this->refreshToken->handle($request->user());

        return response()->json(array_merge(['user' => $result['user']], $result['tokens']->toArray()));
    }

    #[OA\Get(
        path: '/api/user',
        description: 'Returns the account that owns the access token used on this request.',
        summary: 'Current user',
        security: [['sanctum' => []]],
        tags: ['Auth'],
        responses: [
            new OA\Response(response: 200, description: 'The current user', content: new OA\JsonContent(ref: '#/components/schemas/User')),
            new OA\Response(response: 401, description: 'Missing, invalid or expired access token'),
        ]
    )]
    public function me(Request $request): JsonResponse
    {
        return response()->json($request->user());
    }

    #[OA\Post(
        path: '/api/logout',
        description: 'Revokes both the access token and its matching refresh token for this session. Other devices/sessions are unaffected.',
        summary: 'Log out',
        security: [['sanctum' => []]],
        tags: ['Auth'],
        responses: [
            new OA\Response(response: 200, description: 'Session revoked'),
            new OA\Response(response: 401, description: 'Missing or invalid access token'),
        ]
    )]
    public function logout(Request $request): JsonResponse
    {
        $this->logout->handle($request->user());

        return response()->json(['message' => 'Logged out.']);
    }
}
