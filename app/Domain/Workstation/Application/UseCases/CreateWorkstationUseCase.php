<?php

namespace App\Domain\Workstation\Application\UseCases;

use App\Domain\Workstation\Domain\Repositories\WorkstationRepository;
use App\Domain\Workstation\Infrastructure\Models\Workstation;

class CreateWorkstationUseCase
{
    public function __construct(private readonly WorkstationRepository $workstations)
    {
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function handle(array $data): Workstation
    {
        return $this->workstations->create($data);
    }
}
