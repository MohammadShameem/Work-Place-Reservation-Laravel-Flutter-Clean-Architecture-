<?php

namespace App\Domain\Auth\Application\UseCases;

use App\Domain\Auth\Application\DTOs\TokenPair;
use App\Domain\Auth\Application\Support\TokenPairIssuer;
use App\Domain\Auth\Infrastructure\Models\User;
use Illuminate\Support\Str;

class RefreshTokenUseCase
{
    public function __construct(private readonly TokenPairIssuer $tokenIssuer)
    {
    }

    /**
     * Rotate: retire this whole session's pair (this refresh token + its
     * matching access token) and start a fresh one.
     *
     * @return array{user: User, tokens: TokenPair}
     */
    public function handle(User $user): array
    {
        $refreshToken = $user->currentAccessToken();
        $prefix = TokenPairIssuer::prefixOf($refreshToken->name);
        $deviceName = Str::contains($prefix, '|') ? Str::before($prefix, '|') : null;

        $user->tokens()->where('name', 'like', "{$prefix}|%")->delete();

        return ['user' => $user, 'tokens' => $this->tokenIssuer->issue($user, $deviceName)];
    }
}
