<?php

namespace App\Domain\Workstation\Application\UseCases;

use App\Domain\Workstation\Domain\Repositories\WorkstationRepository;
use App\Domain\Workstation\Infrastructure\Models\Workstation;
use Illuminate\Database\Eloquent\Collection;

class ListWorkstationsUseCase
{
    public function __construct(private readonly WorkstationRepository $workstations)
    {
    }

    /** @return Collection<int, Workstation> */
    public function handle(): Collection
    {
        return $this->workstations->listWithOrderCounts();
    }
}
