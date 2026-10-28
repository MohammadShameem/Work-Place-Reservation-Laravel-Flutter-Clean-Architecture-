<?php

namespace App\Domain\Workstation\Infrastructure\Persistence;

use App\Domain\Workstation\Domain\Repositories\WorkstationSlotHoldRepository;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlotHold;

class EloquentWorkstationSlotHoldRepository implements WorkstationSlotHoldRepository
{
    public function lockForSlot(int $slotId): ?WorkstationSlotHold
    {
        return WorkstationSlotHold::where('workstation_slot_id', $slotId)->lockForUpdate()->first();
    }

    public function deleteOtherHoldsForUser(int $userId, int $exceptSlotId): void
    {
        WorkstationSlotHold::where('user_id', $userId)
            ->where('workstation_slot_id', '!=', $exceptSlotId)
            ->delete();
    }

    public function create(array $attributes): WorkstationSlotHold
    {
        return WorkstationSlotHold::create($attributes);
    }

    public function save(WorkstationSlotHold $hold): void
    {
        $hold->save();
    }

    public function delete(WorkstationSlotHold $hold): void
    {
        $hold->delete();
    }

    public function deleteForSlotAndUser(int $slotId, int $userId): void
    {
        WorkstationSlotHold::where('workstation_slot_id', $slotId)
            ->where('user_id', $userId)
            ->delete();
    }
}
