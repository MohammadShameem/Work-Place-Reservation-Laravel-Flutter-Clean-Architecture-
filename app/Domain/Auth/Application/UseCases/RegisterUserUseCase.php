<?php

namespace App\Domain\Auth\Application\UseCases;

use App\Domain\Auth\Application\DTOs\TokenPair;
use App\Domain\Auth\Application\Support\TokenPairIssuer;
use App\Domain\Auth\Domain\Repositories\UserRepository;
use App\Domain\Auth\Infrastructure\Models\User;

class RegisterUserUseCase
{
    public function __construct(
        private readonly UserRepository $users,
        private readonly TokenPairIssuer $tokenIssuer,
    ) {
    }

    /**
     * @param  array{name: string, email: string, password: string}  $data
     * @return array{user: User, tokens: TokenPair}
     */
    public function handle(array $data, ?string $deviceName): array
    {
        $user = $this->users->create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => $data['password'], // hashed by the model cast
        ]);

        return ['user' => $user, 'tokens' => $this->tokenIssuer->issue($user, $deviceName)];
    }
}
