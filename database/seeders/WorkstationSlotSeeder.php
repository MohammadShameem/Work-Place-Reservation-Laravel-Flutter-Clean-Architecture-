<?php

namespace Database\Seeders;

use App\Domain\Workstation\Infrastructure\Models\Workstation;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

class WorkstationSlotSeeder extends Seeder
{
    private const START_HOUR = 9;

    private const END_HOUR = 17; // last slot starts at 16:00, ends 17:00

    private const DAYS_AHEAD = 3; // today + the next 2 days

    /**
     * Hourly slots, 09:00-17:00, for today and the next couple of days, for
     * every workstation. Safe to run more than once — existing slots for the
     * same workstation + start time are left as-is (updateOrCreate).
     */
    public function run(): void
    {
        $workstations = Workstation::all();

        foreach ($workstations as $workstation) {
            for ($day = 0; $day < self::DAYS_AHEAD; $day++) {
                $date = Carbon::today()->addDays($day);

                for ($hour = self::START_HOUR; $hour < self::END_HOUR; $hour++) {
                    $startsAt = $date->copy()->setTime($hour, 0);

                    WorkstationSlot::updateOrCreate(
                        ['workstation_id' => $workstation->id, 'starts_at' => $startsAt],
                        ['ends_at' => $startsAt->copy()->addHour()],
                    );
                }
            }
        }
    }
}
