<?php

namespace App\Domain\Workstation\Infrastructure\Models;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Infrastructure\Models\Order;
use App\Domain\Workstation\Domain\Enums\SlotStatus;
use App\Domain\Workstation\Domain\Services\SlotStatusResolver;
use Database\Factories\WorkstationSlotFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

#[Fillable(['workstation_id', 'starts_at', 'ends_at'])]
class WorkstationSlot extends Model
{
    /** @use HasFactory<WorkstationSlotFactory> */
    use HasFactory;

    protected static function newFactory(): WorkstationSlotFactory
    {
        return WorkstationSlotFactory::new();
    }

    protected function casts(): array
    {
        return [
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
        ];
    }

    public function workstation(): BelongsTo
    {
        return $this->belongsTo(Workstation::class);
    }

    /**
     * Every order ever made for this slot. A cancelled booking doesn't free
     * a row here — it stays for history — so availability is computed from
     * this relation (see HoldSlotUseCase::acquire()), not stored as a flag.
     */
    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    /** The current (possibly already expired) hold row, if any — at most one. */
    public function hold(): HasOne
    {
        return $this->hasOne(WorkstationSlotHold::class);
    }

    /**
     * This slot as seen by one viewer. Uses `active_orders_count` and a
     * preloaded `hold` when the caller eager-loaded them (the slots list
     * does, so a whole day costs no per-slot queries); otherwise asks the
     * database directly.
     */
    public function statusFor(?int $viewerId): SlotStatus
    {
        $isBooked = array_key_exists('active_orders_count', $this->attributes)
            ? (int) $this->active_orders_count > 0
            : $this->orders()->where('status', '!=', OrderStatus::Cancelled->value)->exists();

        return SlotStatusResolver::resolve($isBooked, $this->activeHold(), $viewerId);
    }

    /** The hold that still counts (not expired), or null. */
    public function activeHold(): ?WorkstationSlotHold
    {
        $hold = $this->relationLoaded('hold') ? $this->hold : $this->hold()->first();

        return $hold && ! $hold->isExpired() ? $hold : null;
    }

    /** Nobody has booked it and nobody is holding it. */
    public function isAvailable(): bool
    {
        return $this->statusFor(null) === SlotStatus::Available;
    }
}
