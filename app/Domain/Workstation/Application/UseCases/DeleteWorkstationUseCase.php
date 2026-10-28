<?php

namespace App\Domain\Workstation\Application\UseCases;

use App\Domain\Workstation\Domain\Repositories\WorkstationRepository;
use Illuminate\Validation\ValidationException;

class DeleteWorkstationUseCase
{
    public function __construct(private readonly WorkstationRepository $workstations)
    {
    }

    public function handle(int $id): void
    {
        // An order's workstation_id/workstation_slot_id are required columns,
        // so an order can't be left dangling with it set to null — any order
        // history blocks the delete instead.
        if ($this->workstations->hasOrders($id)) {
            throw ValidationException::withMessages([
                'workstation' => ['This workstation has order history and cannot be deleted.'],
            ]);
        }

        $this->workstations->delete($id);
    }
}
