<?php

namespace Database\Factories;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Infrastructure\Models\Order;
use App\Domain\Workstation\Infrastructure\Models\Workstation;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Order>
 */
class OrderFactory extends Factory
{
    protected $model = Order::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_number' => fake()->unique()->bothify('ORD-########'),
            'workstation_slot_id' => WorkstationSlot::factory(),
            'customer_name' => fake()->name(),
            'status' => OrderStatus::Pending,
            'notes' => null,
        ];
    }

    /**
     * Book a slot belonging to a specific workstation — for tests that need
     * an order pinned to a known workstation rather than a random one.
     */
    public function forWorkstation(Workstation $workstation): static
    {
        return $this->state(fn () => [
            'workstation_id' => $workstation->id,
            'workstation_slot_id' => WorkstationSlot::factory()->for($workstation)->create()->id,
        ]);
    }

    /**
     * A workstation_id is always required alongside workstation_slot_id, and
     * it must be the SAME workstation the slot belongs to. configure() runs
     * after the factory resolves relations, so the slot already has an id.
     */
    public function configure(): static
    {
        return $this->afterMaking(function (Order $order) {
            if (! $order->workstation_id) {
                $order->workstation_id = WorkstationSlot::find($order->workstation_slot_id)?->workstation_id;
            }
        });
    }
}
