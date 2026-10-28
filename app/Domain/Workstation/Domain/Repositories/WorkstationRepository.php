<?php

namespace App\Domain\Workstation\Domain\Repositories;

use App\Domain\Workstation\Infrastructure\Models\Workstation;
use Illuminate\Database\Eloquent\Collection;

interface WorkstationRepository
{
    /** @return Collection<int, Workstation> */
    public function listWithOrderCounts(): Collection;

    /** @throws \Illuminate\Database\Eloquent\ModelNotFoundException */
    public function findWithOrderCount(int $id): Workstation;

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function create(array $attributes): Workstation;

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function update(int $id, array $attributes): Workstation;

    public function delete(int $id): void;

    public function hasOrders(int $id): bool;
}
