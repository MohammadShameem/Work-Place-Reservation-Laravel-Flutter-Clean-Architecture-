<?php

namespace App\Domain\Auth\Application\UseCases;

use App\Domain\Auth\Application\DTOs\TokenPair;
use App\Domain\Auth\Application\Support\TokenPairIssuer;
use App\Domain\Auth\Domain\Exceptions\InvalidCredentialsException;
use App\Domain\Auth\Domain\Repositories\UserRepository;
use App\Domain\Auth\Infrastructure\Models\User;
use Illuminate\Support\Facades\Hash;

class LoginUseCase
{
    public function __construct(
        private readonly UserRepository $users,
        private readonly TokenPairIssuer $tokenIssuer,
    ) {
    }

    /**
     * @return array{user: User, tokens: TokenPair}
     *
     * @throws InvalidCredentialsException
     */
    public function handle(string $email, string $password, ?string $deviceName): array
    {
        $user = $this->users->findByEmail($email);

        if (! $user || ! Hash::check($password, $user->password)) {
            throw new InvalidCredentialsException();
        }

        return ['user' => $user, 'tokens' => $this->tokenIssuer->issue($user, $deviceName)];
    }
}
