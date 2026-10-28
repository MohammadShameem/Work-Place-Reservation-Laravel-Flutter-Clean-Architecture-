<?php

namespace Database\Factories;

use App\Domain\Workstation\Infrastructure\Models\Workstation;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<WorkstationSlot>
 */
class WorkstationSlotFactory extends Factory
{
    protected $model = WorkstationSlot::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $startsAt = fake()->dateTimeBetween('now', '+7 days')->setTime(fake()->numberBetween(9, 16), 0);

        return [
            'workstation_id' => Workstation::factory(),
            'starts_at' => $startsAt,
            'ends_at' => (clone $startsAt)->modify('+1 hour'),
        ];
    }
}
