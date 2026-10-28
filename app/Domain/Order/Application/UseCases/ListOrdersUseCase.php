<?php

namespace App\Domain\Order\Application\UseCases;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Domain\Repositories\OrderRepository;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class ListOrdersUseCase
{
    public function __construct(private readonly OrderRepository $orders)
    {
    }

    public function handle(?OrderStatus $status, ?int $workstationId): LengthAwarePaginator
    {
        return $this->orders->paginate($status, $workstationId);
    }
}
