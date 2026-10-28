<?php

namespace App\Domain\Workstation\Infrastructure\Persistence;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Workstation\Domain\Repositories\WorkstationSlotRepository;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;

class EloquentWorkstationSlotRepository implements WorkstationSlotRepository
{
    public function lockWithWorkstation(int $id): WorkstationSlot
    {
        // Always lock the slot row first so every code path takes locks in
        // the same order.
        return WorkstationSlot::with('workstation')->lockForUpdate()->findOrFail($id);
    }

    public function listForDay(int $workstationId, CarbonInterface $day): Collection
    {
        return WorkstationSlot::query()
            ->where('workstation_id', $workstationId)
            ->whereBetween('starts_at', [$day, $day->copy()->addDay()])
            ->withCount([
                'orders as active_orders_count' => fn ($query) => $query->where('status', '!=', OrderStatus::Cancelled->value),
            ])
            ->with('hold')
            ->orderBy('starts_at')
            ->get();
    }
}
