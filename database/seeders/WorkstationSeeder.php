<?php

namespace Database\Seeders;

use App\Domain\Workstation\Infrastructure\Models\Workstation;
use Illuminate\Database\Seeder;

class WorkstationSeeder extends Seeder
{
    private const LOCATIONS = [
        1 => 'Building A - Floor 1',
        2 => 'Building A - Floor 2',
        3 => 'Building B - Floor 1',
        4 => 'Building B - Floor 2',
    ];

    /**
     * Create the four workstations. Safe to run more than once.
     */
    public function run(): void
    {
        foreach (range(1, 4) as $number) {
            Workstation::updateOrCreate(
                ['code' => sprintf('WS-%02d', $number)],
                [
                    'name' => "Workstation {$number}",
                    'location' => self::LOCATIONS[$number],
                    'is_active' => true,
                ],
            );
        }
    }
}
