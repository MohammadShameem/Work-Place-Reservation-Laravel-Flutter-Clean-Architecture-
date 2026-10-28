<?php

namespace App\Domain\Workstation\Application\UseCases;

use App\Domain\Workstation\Domain\Repositories\WorkstationSlotRepository;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Collection;

class ListWorkstationSlotsUseCase
{
    public function __construct(private readonly WorkstationSlotRepository $slots)
    {
    }

    /** @return Collection<int, WorkstationSlot> */
    public function handle(int $workstationId, CarbonInterface $day): Collection
    {
        return $this->slots->listForDay($workstationId, $day);
    }
}
