<?php

namespace App\Domain\Workstation\Infrastructure\Persistence;

use App\Domain\Workstation\Domain\Repositories\WorkstationRepository;
use App\Domain\Workstation\Infrastructure\Models\Workstation;
use Illuminate\Database\Eloquent\Collection;

class EloquentWorkstationRepository implements WorkstationRepository
{
    public function listWithOrderCounts(): Collection
    {
        return Workstation::withCount('orders')->orderBy('code')->get();
    }

    public function findWithOrderCount(int $id): Workstation
    {
        return Workstation::withCount('orders')->findOrFail($id);
    }

    public function create(array $attributes): Workstation
    {
        return Workstation::create($attributes);
    }

    public function update(int $id, array $attributes): Workstation
    {
        $workstation = Workstation::findOrFail($id);
        $workstation->update($attributes);

        return $workstation->loadCount('orders');
    }

    public function delete(int $id): void
    {
        Workstation::findOrFail($id)->delete();
    }

    public function hasOrders(int $id): bool
    {
        return Workstation::findOrFail($id)->orders()->exists();
    }
}
