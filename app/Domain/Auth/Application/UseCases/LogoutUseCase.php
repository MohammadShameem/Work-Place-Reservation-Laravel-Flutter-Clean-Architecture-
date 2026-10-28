<?php

namespace App\Domain\Auth\Application\UseCases;

use App\Domain\Auth\Application\Support\TokenPairIssuer;
use App\Domain\Auth\Infrastructure\Models\User;

class LogoutUseCase
{
    /** Revokes both the access token and its matching refresh token for this session. */
    public function handle(User $user): void
    {
        $prefix = TokenPairIssuer::prefixOf($user->currentAccessToken()->name);

        $user->tokens()->where('name', 'like', "{$prefix}|%")->delete();
    }
}
