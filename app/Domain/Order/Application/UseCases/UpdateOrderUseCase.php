<?php

namespace App\Domain\Order\Application\UseCases;

use App\Domain\Order\Domain\Repositories\OrderRepository;
use App\Domain\Order\Infrastructure\Models\Order;
use Illuminate\Validation\ValidationException;

class UpdateOrderUseCase
{
    public function __construct(private readonly OrderRepository $orders)
    {
    }

    /**
     * @param  array<string, mixed>  $data
     */
    public function handle(int $id, array $data): Order
    {
        $order = $this->orders->findWithRelations($id);
        $this->ensureOpen($order);

        return $this->orders->update($id, $data);
    }

    private function ensureOpen(Order $order): void
    {
        if ($order->status->isClosed()) {
            throw ValidationException::withMessages([
                'status' => ["A {$order->status->value} order can no longer be edited."],
            ]);
        }
    }
}
