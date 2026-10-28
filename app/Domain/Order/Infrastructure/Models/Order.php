<?php

namespace App\Domain\Order\Infrastructure\Models;

use App\Domain\Auth\Infrastructure\Models\User;
use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Workstation\Infrastructure\Models\Workstation;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Database\Factories\OrderFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'order_number',
    'workstation_id',
    'workstation_slot_id',
    'user_id',
    'customer_name',
    'status',
    'notes',
])]
class Order extends Model
{
    /** @use HasFactory<OrderFactory> */
    use HasFactory;

    protected static function newFactory(): OrderFactory
    {
        return OrderFactory::new();
    }

    protected function casts(): array
    {
        return [
            'status' => OrderStatus::class,
        ];
    }

    public function workstation(): BelongsTo
    {
        return $this->belongsTo(Workstation::class);
    }

    public function workstationSlot(): BelongsTo
    {
        return $this->belongsTo(WorkstationSlot::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
