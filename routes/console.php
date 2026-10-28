<?php

use App\Domain\Workstation\Infrastructure\Models\WorkstationSlotHold;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Housekeeping only. Expired holds are already ignored everywhere (and
// replaced lazily when someone takes the slot), so nothing breaks if the
// scheduler isn't running. Needs `php artisan schedule:work` in development.
Schedule::call(fn () => WorkstationSlotHold::where('expires_at', '<', now()->subMinute())->delete())
    ->everyMinute()
    ->name('prune-expired-slot-holds');
