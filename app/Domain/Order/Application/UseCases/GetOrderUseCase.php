<?php

namespace App\Domain\Order\Application\UseCases;

use App\Domain\Order\Domain\Repositories\OrderRepository;
use App\Domain\Order\Infrastructure\Models\Order;

class GetOrderUseCase
{
    public function __construct(private readonly OrderRepository $orders)
    {
    }

    public function handle(int $id): Order
    {
        return $this->orders->findWithRelations($id);
    }
}
