<?php

namespace App\Domain\Idempotency\Infrastructure\Persistence;

use App\Domain\Idempotency\Domain\Repositories\IdempotencyKeyRepository;
use App\Domain\Idempotency\Infrastructure\Models\IdempotencyKey;
use Illuminate\Database\QueryException;

class EloquentIdempotencyKeyRepository implements IdempotencyKeyRepository
{
    public function find(?int $userId, string $key): ?IdempotencyKey
    {
        return IdempotencyKey::query()->where('user_id', $userId)->where('key', $key)->first();
    }

    public function claim(?int $userId, string $key): ?IdempotencyKey
    {
        try {
            // Claim the key first. If two identical requests arrive at the
            // same time, the table's unique(user_id, key) index lets only
            // one win.
            return IdempotencyKey::query()->create(['key' => $key, 'user_id' => $userId]);
        } catch (QueryException) {
            return null;
        }
    }

    public function markCompleted(IdempotencyKey $record, int $status, mixed $body): void
    {
        $record->update([
            'response_status' => $status,
            'response_body' => $body,
        ]);
    }

    public function delete(IdempotencyKey $record): void
    {
        $record->delete();
    }
}
