<?php

namespace Database\Seeders;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Infrastructure\Models\Order;
use App\Domain\Auth\Infrastructure\Models\User;
use App\Domain\Workstation\Infrastructure\Models\Workstation;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

class DemoOrderSeeder extends Seeder
{
    /**
     * Books a few of today's slots so the app has something to show out of
     * the box: one pending, one in progress, one completed, and one
     * cancelled — the cancelled one demonstrates that its slot is available
     * again. Safe to run more than once (keyed by order_number).
     */
    public function run(): void
    {
        $user = User::where('email', 'test@example.com')->first();

        $bookings = [
            ['workstation_code' => 'WS-01', 'hour' => 9, 'customer' => 'Rahim Uddin', 'status' => OrderStatus::Pending],
            ['workstation_code' => 'WS-01', 'hour' => 10, 'customer' => 'Karim Hossain', 'status' => OrderStatus::InProgress],
            ['workstation_code' => 'WS-02', 'hour' => 9, 'customer' => 'Fatima Begum', 'status' => OrderStatus::Completed],
            ['workstation_code' => 'WS-03', 'hour' => 9, 'customer' => 'Jamal Ahmed', 'status' => OrderStatus::Cancelled],
        ];

        foreach ($bookings as $booking) {
            $workstation = Workstation::where('code', $booking['workstation_code'])->first();
            if (! $workstation) {
                continue;
            }

            $slot = WorkstationSlot::where('workstation_id', $workstation->id)
                ->where('starts_at', Carbon::today()->setTime($booking['hour'], 0))
                ->first();

            if (! $slot) {
                continue;
            }

            Order::updateOrCreate(
                ['workstation_slot_id' => $slot->id, 'customer_name' => $booking['customer']],
                [
                    'order_number' => 'ORD-DEMO-'.Str::upper(Str::random(6)),
                    'workstation_id' => $workstation->id,
                    'user_id' => $user?->id,
                    'status' => $booking['status'],
                    'notes' => null,
                ],
            );
        }
    }
}
