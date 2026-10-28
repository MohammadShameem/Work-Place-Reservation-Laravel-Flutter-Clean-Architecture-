<?php

namespace App\Domain\Workstation\Domain\Repositories;

use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;

interface WorkstationSlotRepository
{
    /** Locks the slot row (and reads its workstation) for the surrounding transaction. */
    public function lockWithWorkstation(int $id): WorkstationSlot;

    /**
     * One day's slots for a workstation, with `active_orders_count` and the
     * current `hold` eager-loaded so listing a whole day costs no
     * per-slot queries.
     *
     * @return Collection<int, WorkstationSlot>
     */
    public function listForDay(int $workstationId, CarbonInterface $day): Collection;
}
