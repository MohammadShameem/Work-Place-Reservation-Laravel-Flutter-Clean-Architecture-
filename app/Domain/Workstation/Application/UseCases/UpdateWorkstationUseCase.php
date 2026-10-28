<?php

namespace App\Domain\Workstation\Application\UseCases;

use App\Domain\Workstation\Domain\Repositories\WorkstationRepository;
use App\Domain\Workstation\Infrastructure\Models\Workstation;

class UpdateWorkstationUseCase
{
    public function __construct(private readonly WorkstationRepository $workstations)
    {
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function handle(int $id, array $data): Workstation
    {
        return $this->workstations->update($id, $data);
    }
}
