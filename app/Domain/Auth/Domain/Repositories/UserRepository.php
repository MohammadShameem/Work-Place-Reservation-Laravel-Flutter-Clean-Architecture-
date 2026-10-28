<?php

namespace App\Domain\Auth\Domain\Repositories;

use App\Domain\Auth\Infrastructure\Models\User;

interface UserRepository
{
    public function findByEmail(string $email): ?User;

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function create(array $attributes): User;
}
