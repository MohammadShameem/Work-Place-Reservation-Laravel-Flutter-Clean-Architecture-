<?php

namespace App\Domain\Workstation\Domain\Repositories;

use App\Domain\Workstation\Infrastructure\Models\WorkstationSlotHold;

interface WorkstationSlotHoldRepository
{
    /** Locks the slot's current hold row (if any) for the surrounding transaction. */
    public function lockForSlot(int $slotId): ?WorkstationSlotHold;

    /** One live hold per person: drops any other slot this user was holding. */
    public function deleteOtherHoldsForUser(int $userId, int $exceptSlotId): void;

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function create(array $attributes): WorkstationSlotHold;

    public function save(WorkstationSlotHold $hold): void;

    public function delete(WorkstationSlotHold $hold): void;

    public function deleteForSlotAndUser(int $slotId, int $userId): void;
}
