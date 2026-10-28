<?php

namespace Tests\Feature;

use App\Domain\Order\Domain\Contracts\SlotBooking;
use App\Domain\Workstation\Domain\Contracts\SlotHolds;
use App\Domain\Workstation\Domain\Exceptions\SlotConflictException;
use App\Domain\Auth\Infrastructure\Models\User;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlotHold;
use App\Domain\Order\Application\UseCases\BookSlotUseCase;
use App\Domain\Workstation\Application\UseCases\HoldSlotUseCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * The controllers know only the interfaces. These tests show that is real:
 * the container decides what runs, and a stand-in can replace it.
 */
class DependencyInjectionTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_container_hands_out_the_bound_implementations(): void
    {
        $this->assertInstanceOf(HoldSlotUseCase::class, app(SlotHolds::class));
        $this->assertInstanceOf(BookSlotUseCase::class, app(SlotBooking::class));
    }

    public function test_the_hold_lifetime_comes_from_config_through_the_binding(): void
    {
        config(['booking.hold_ttl_seconds' => 42]);
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $slot = WorkstationSlot::factory()->create();

        $data = $this->postJson("/api/workstation-slots/{$slot->id}/hold")->assertCreated()->json('data');

        // expires_at is stored in whole seconds but server_time carries a
        // fraction, so the gap can read 41 or 42; what matters is that it is
        // the configured 42, not the 180 default.
        $this->assertEqualsWithDelta(42, strtotime($data['expires_at']) - strtotime($data['server_time']), 1);
    }

    public function test_a_stand_in_for_slot_holds_changes_behaviour_without_touching_the_controllers(): void
    {
        $this->app->instance(SlotHolds::class, new class implements SlotHolds
        {
            public function acquire(User $user, int $slotId): WorkstationSlotHold
            {
                throw SlotConflictException::held(30);
            }

            public function release(User $user, int $slotId): void {}
        });

        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $slot = WorkstationSlot::factory()->create();

        // Both entry points reach the same (fake) service...
        $this->postJson("/api/workstation-slots/{$slot->id}/hold")
            ->assertConflict()->assertJsonPath('code', 'slot_held')->assertJsonPath('retry_after', 30);

        // ...including the booking path, because BookSlotUseCase was handed
        // the fake by the container rather than building its own.
        $this->postJson('/api/orders', ['customer_name' => 'Rahim', 'workstation_slot_id' => $slot->id])
            ->assertConflict()->assertJsonPath('code', 'slot_held')->assertJsonPath('retry_after', 30);

        $this->assertDatabaseCount('orders', 0);
        $this->assertDatabaseCount('workstation_slot_holds', 0);
    }
}
