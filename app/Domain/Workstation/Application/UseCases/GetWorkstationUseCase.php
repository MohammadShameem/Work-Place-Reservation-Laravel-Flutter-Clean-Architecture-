<?php

namespace App\Domain\Workstation\Application\UseCases;

use App\Domain\Workstation\Domain\Repositories\WorkstationRepository;
use App\Domain\Workstation\Infrastructure\Models\Workstation;

class GetWorkstationUseCase
{
    public function __construct(private readonly WorkstationRepository $workstations)
    {
    }

    public function handle(int $id): Workstation
    {
        return $this->workstations->findWithOrderCount($id);
    }
}
