<?php

namespace Database\Factories;

use App\Domain\Workstation\Infrastructure\Models\Workstation;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Workstation>
 */
class WorkstationFactory extends Factory
{
    protected $model = Workstation::class;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => 'Workstation '.fake()->unique()->numberBetween(5, 999),
            'code' => fake()->unique()->bothify('WS-###'),
            'location' => fake()->randomElement(['Building A - Floor 1', 'Building A - Floor 2', 'Building B - Floor 1']),
            'is_active' => true,
        ];
    }
}
