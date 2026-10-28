<?php

namespace App\Domain\Workstation\Infrastructure\Models;

use App\Domain\Auth\Infrastructure\Models\User;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['workstation_slot_id', 'user_id', 'expires_at'])]
class WorkstationSlotHold extends Model
{
    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
        ];
    }

    public function slot(): BelongsTo
    {
        return $this->belongsTo(WorkstationSlot::class, 'workstation_slot_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isExpired(): bool
    {
        return $this->expires_at->lte(now());
    }

    /** Holds that still count. Correctness never depends on expired rows being deleted. */
    public function scopeActive(Builder $query): void
    {
        $query->where('expires_at', '>', now());
    }
}
