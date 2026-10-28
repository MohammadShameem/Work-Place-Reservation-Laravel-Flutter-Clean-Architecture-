<?php

namespace App\Domain\Workstation\Application\UseCases;

use App\Domain\Order\Domain\Repositories\OrderRepository;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

/**
 * Crosses into the Order feature through its repository port — never its
 * Eloquent model — to list one workstation's orders.
 */
class ListWorkstationOrdersUseCase
{
    public function __construct(private readonly OrderRepository $orders)
    {
    }

    public function handle(int $workstationId): LengthAwarePaginator
    {
        return $this->orders->paginateForWorkstation($workstationId);
    }
}
