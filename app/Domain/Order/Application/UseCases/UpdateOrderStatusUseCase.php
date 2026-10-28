<?php

namespace App\Domain\Order\Application\UseCases;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Domain\Repositories\OrderRepository;
use App\Domain\Order\Infrastructure\Models\Order;
use Illuminate\Validation\ValidationException;

class UpdateOrderStatusUseCase
{
    public function __construct(private readonly OrderRepository $orders)
    {
    }

    public function handle(int $id, OrderStatus $next): Order
    {
        $order = $this->orders->findWithRelations($id);

        if (! $order->status->canTransitionTo($next)) {
            throw ValidationException::withMessages([
                'status' => ["An order that is {$order->status->value} cannot change to {$next->value}."],
            ]);
        }

        return $this->orders->update($id, ['status' => $next]);
    }
}
