<?php

namespace App\Domain\Auth\Application\DTOs;

use DateTimeInterface;

final class TokenPair
{
    public function __construct(
        public readonly string $accessToken,
        public readonly DateTimeInterface $accessTokenExpiresAt,
        public readonly string $refreshToken,
        public readonly DateTimeInterface $refreshTokenExpiresAt,
    ) {
    }

    /**
     * @return array<string, string>
     */
    public function toArray(): array
    {
        return [
            'access_token' => $this->accessToken,
            'access_token_expires_at' => $this->accessTokenExpiresAt->format(DateTimeInterface::ATOM),
            'refresh_token' => $this->refreshToken,
            'refresh_token_expires_at' => $this->refreshTokenExpiresAt->format(DateTimeInterface::ATOM),
        ];
    }
}
