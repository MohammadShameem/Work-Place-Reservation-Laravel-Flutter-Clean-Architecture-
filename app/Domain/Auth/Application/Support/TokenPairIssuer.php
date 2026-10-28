<?php

namespace App\Domain\Auth\Application\Support;

use App\Domain\Auth\Application\DTOs\TokenPair;
use App\Domain\Auth\Infrastructure\Models\User;
use Illuminate\Support\Str;

/**
 * Issues one access + refresh token pair for a login session. Both tokens
 * share a "{deviceName}|{sessionId}" prefix so logout/refresh can find and
 * revoke the two of them together without touching the user's other
 * sessions/devices.
 */
class TokenPairIssuer
{
    public function issue(User $user, ?string $deviceName): TokenPair
    {
        $prefix = ($deviceName !== null && $deviceName !== '' ? $deviceName : 'api').'|'.Str::uuid();

        $accessExpiresAt = now()->addMinutes((int) config('sanctum.access_token_ttl'));
        $refreshExpiresAt = now()->addMinutes((int) config('sanctum.refresh_token_ttl'));

        $accessToken = $user->createToken("{$prefix}|access", ['access-api'], $accessExpiresAt);
        $refreshToken = $user->createToken("{$prefix}|refresh", ['issue-access-token'], $refreshExpiresAt);

        return new TokenPair(
            accessToken: $accessToken->plainTextToken,
            accessTokenExpiresAt: $accessExpiresAt,
            refreshToken: $refreshToken->plainTextToken,
            refreshTokenExpiresAt: $refreshExpiresAt,
        );
    }

    /** Strip the trailing "|access" or "|refresh" off a token name. */
    public static function prefixOf(string $tokenName): string
    {
        return Str::beforeLast($tokenName, '|');
    }
}
