<?php

namespace App\Domain\Auth\Infrastructure\Persistence;

use App\Domain\Auth\Domain\Repositories\UserRepository;
use App\Domain\Auth\Infrastructure\Models\User;

class EloquentUserRepository implements UserRepository
{
    public function findByEmail(string $email): ?User
    {
        return User::where('email', $email)->first();
    }

    public function create(array $attributes): User
    {
        return User::create($attributes);
    }
}
