<?php

namespace App\Domain\Workstation\Infrastructure\Models;

use App\Domain\Order\Infrastructure\Models\Order;
use Database\Factories\WorkstationFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

#[Fillable(['name', 'code', 'location', 'is_active'])]
class Workstation extends Model
{
    /** @use HasFactory<WorkstationFactory> */
    use HasFactory;

    protected static function newFactory(): WorkstationFactory
    {
        return WorkstationFactory::new();
    }

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function slots(): HasMany
    {
        return $this->hasMany(WorkstationSlot::class);
    }
}
