<?php

namespace App\Domain\Order\Application\UseCases;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Domain\Repositories\OrderRepository;
use Illuminate\Validation\ValidationException;

class DeleteOrderUseCase
{
    public function __construct(private readonly OrderRepository $orders)
    {
    }

    public function handle(int $id): void
    {
        $order = $this->orders->findWithRelations($id);

        if ($order->status === OrderStatus::Completed || $order->status === OrderStatus::InProgress) {
            throw ValidationException::withMessages([
                'status' => ['Only pending or cancelled orders can be deleted.'],
            ]);
        }

        $this->orders->delete($id);
    }
}
