<?php

namespace App\Domain\Idempotency\Domain\Repositories;

use App\Domain\Idempotency\Infrastructure\Models\IdempotencyKey;

interface IdempotencyKeyRepository
{
    public function find(?int $userId, string $key): ?IdempotencyKey;

    /** Claims the key, or returns null if another in-flight request already won the race. */
    public function claim(?int $userId, string $key): ?IdempotencyKey;

    public function markCompleted(IdempotencyKey $record, int $status, mixed $body): void;

    public function delete(IdempotencyKey $record): void;
}
