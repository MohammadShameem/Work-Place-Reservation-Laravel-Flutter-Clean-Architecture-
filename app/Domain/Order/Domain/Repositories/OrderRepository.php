<?php

namespace App\Domain\Order\Domain\Repositories;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Infrastructure\Models\Order;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

interface OrderRepository
{
    public function paginate(?OrderStatus $status, ?int $workstationId, int $perPage = 15): LengthAwarePaginator;

    public function paginateForWorkstation(int $workstationId, int $perPage = 15): LengthAwarePaginator;

    /** @throws \Illuminate\Database\Eloquent\ModelNotFoundException */
    public function findWithRelations(int $id): Order;

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function create(array $attributes): Order;

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function update(int $id, array $attributes): Order;

    public function delete(int $id): void;

    /**
     * Whether any non-cancelled order already owns this slot. Locks the
     * matching rows for the surrounding transaction.
     */
    public function existsActiveForSlot(int $slotId): bool;
}
