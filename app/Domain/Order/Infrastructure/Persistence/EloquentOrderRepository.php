<?php

namespace App\Domain\Order\Infrastructure\Persistence;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Domain\Repositories\OrderRepository;
use App\Domain\Order\Infrastructure\Models\Order;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class EloquentOrderRepository implements OrderRepository
{
    public function paginate(?OrderStatus $status, ?int $workstationId, int $perPage = 15): LengthAwarePaginator
    {
        return Order::query()
            ->with(['workstation', 'workstationSlot'])
            ->when($status, fn ($query, $status) => $query->where('status', $status))
            ->when($workstationId, fn ($query, $id) => $query->where('workstation_id', $id))
            ->latest('id')
            ->paginate($perPage);
    }

    public function paginateForWorkstation(int $workstationId, int $perPage = 15): LengthAwarePaginator
    {
        return Order::query()
            ->where('workstation_id', $workstationId)
            ->with('workstationSlot')
            ->latest('id')
            ->paginate($perPage);
    }

    public function findWithRelations(int $id): Order
    {
        return Order::with(['workstation', 'workstationSlot'])->findOrFail($id);
    }

    public function create(array $attributes): Order
    {
        return Order::create($attributes)->load('workstation', 'workstationSlot');
    }

    public function update(int $id, array $attributes): Order
    {
        $order = Order::findOrFail($id);
        $order->update($attributes);

        return $order->load('workstation', 'workstationSlot');
    }

    public function delete(int $id): void
    {
        Order::findOrFail($id)->delete();
    }

    public function existsActiveForSlot(int $slotId): bool
    {
        // Locking read (not a plain one) so this sees what another
        // transaction committed while it waited for the slot lock, instead
        // of this transaction's older snapshot.
        return Order::where('workstation_slot_id', $slotId)
            ->where('status', '!=', OrderStatus::Cancelled->value)
            ->lockForUpdate()
            ->exists();
    }
}
