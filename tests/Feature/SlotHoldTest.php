<?php

namespace Tests\Feature;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Infrastructure\Models\Order;
use App\Domain\Auth\Infrastructure\Models\User;
use App\Domain\Workstation\Infrastructure\Models\Workstation;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlotHold;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * The "someone is already on this slot" rules. Two people are simulated by
 * switching the acting user between calls — requests run one after another
 * here, so the lock-based protection against truly simultaneous requests is
 * covered separately (see the multi-process check in the project notes).
 */
class SlotHoldTest extends TestCase
{
    use RefreshDatabase;

    private User $alice;

    private User $bob;

    protected function setUp(): void
    {
        parent::setUp();

        config(['booking.hold_ttl_seconds' => 180, 'booking.hold_max_seconds' => 600]);

        $this->alice = User::factory()->create();
        $this->bob = User::factory()->create();
    }

    private function actAs(User $user): void
    {
        Sanctum::actingAs($user, ['access-api']);
    }

    private function todaysSlot(?Workstation $workstation = null, int $hour = 9): WorkstationSlot
    {
        $factory = WorkstationSlot::factory();

        return ($workstation ? $factory->for($workstation) : $factory)->create([
            'starts_at' => now()->startOfDay()->setTime($hour, 0),
            'ends_at' => now()->startOfDay()->setTime($hour + 1, 0),
        ]);
    }

    private function hold(WorkstationSlot $slot)
    {
        return $this->postJson("/api/workstation-slots/{$slot->id}/hold");
    }

    public function test_holding_a_slot_returns_when_it_lapses_and_the_servers_clock(): void
    {
        $slot = $this->todaysSlot();
        $this->actAs($this->alice);

        $this->hold($slot)
            ->assertCreated()
            ->assertJsonPath('data.workstation_slot_id', $slot->id)
            ->assertJsonStructure(['data' => ['expires_at', 'server_time']]);

        $this->assertDatabaseHas('workstation_slot_holds', ['workstation_slot_id' => $slot->id, 'user_id' => $this->alice->id]);
    }

    public function test_a_second_user_is_told_the_slot_is_held_and_when_to_retry(): void
    {
        $slot = $this->todaysSlot();

        $this->actAs($this->alice);
        $this->hold($slot)->assertCreated();

        $this->actAs($this->bob);
        $response = $this->hold($slot)
            ->assertConflict()
            ->assertJsonPath('code', 'slot_held')
            ->assertHeader('Retry-After');

        $this->assertStringContainsString('may become available again', $response->json('message'));
        $this->assertGreaterThan(0, $response->json('retry_after'));
        $this->assertLessThanOrEqual(180, $response->json('retry_after'));

        // Bob's failed attempt must not have taken anything over.
        $this->assertDatabaseHas('workstation_slot_holds', ['workstation_slot_id' => $slot->id, 'user_id' => $this->alice->id]);
        $this->assertDatabaseCount('workstation_slot_holds', 1);
    }

    public function test_the_slot_list_shows_each_viewer_their_own_view_without_naming_the_holder(): void
    {
        $workstation = Workstation::factory()->create();
        $held = $this->todaysSlot($workstation, 9);
        $free = $this->todaysSlot($workstation, 10);
        $booked = $this->todaysSlot($workstation, 11);
        Order::factory()->create(['workstation_id' => $workstation->id, 'workstation_slot_id' => $booked->id]);

        $this->actAs($this->alice);
        $this->hold($held)->assertCreated();

        $statusOf = fn (array $rows, WorkstationSlot $slot) => collect($rows)->firstWhere('id', $slot->id);

        $aliceView = $this->getJson("/api/workstations/{$workstation->id}/slots")->assertOk()->json('data');
        $this->assertSame('held_by_you', $statusOf($aliceView, $held)['status']);
        $this->assertNotNull($statusOf($aliceView, $held)['held_until']);

        $this->actAs($this->bob);
        $bobResponse = $this->getJson("/api/workstations/{$workstation->id}/slots")->assertOk();
        $bobView = $bobResponse->json('data');

        $this->assertSame('held', $statusOf($bobView, $held)['status']);
        $this->assertFalse($statusOf($bobView, $held)['is_available']);
        $this->assertNotNull($statusOf($bobView, $held)['held_until']);
        $this->assertSame('available', $statusOf($bobView, $free)['status']);
        $this->assertTrue($statusOf($bobView, $free)['is_available']);
        $this->assertSame('booked', $statusOf($bobView, $booked)['status']);
        $this->assertNull($statusOf($bobView, $booked)['held_until']);

        // Who is holding it is never part of the response.
        $this->assertStringNotContainsString((string) $this->alice->email, $bobResponse->getContent());
        $this->assertStringNotContainsString('user_id', $bobResponse->getContent());
    }

    public function test_a_lapsed_hold_frees_the_slot_for_someone_else(): void
    {
        $slot = $this->todaysSlot();

        $this->actAs($this->alice);
        $this->hold($slot)->assertCreated();

        $this->travel(179)->seconds();
        $this->actAs($this->bob);
        $this->hold($slot)->assertConflict();

        $this->travel(2)->seconds(); // now 181s after Alice took it
        $this->hold($slot)->assertCreated();

        $this->assertDatabaseHas('workstation_slot_holds', ['workstation_slot_id' => $slot->id, 'user_id' => $this->bob->id]);
        $this->assertDatabaseCount('workstation_slot_holds', 1);
    }

    public function test_holding_again_renews_instead_of_conflicting_but_never_past_the_cap(): void
    {
        $slot = $this->todaysSlot();
        $this->actAs($this->alice);

        $first = $this->hold($slot)->assertCreated()->json('data.expires_at');

        $this->travel(100)->seconds();
        $second = $this->hold($slot)->assertSuccessful()->json('data.expires_at');
        $this->assertGreaterThan(strtotime($first), strtotime($second));
        $this->assertDatabaseCount('workstation_slot_holds', 1);

        // Keep renewing (each call lands before the previous hold lapses). However
        // often she does, the hold stops at 10 minutes counted from the start.
        $createdAt = WorkstationSlotHold::firstOrFail()->created_at->timestamp;
        foreach ([170, 170, 100] as $seconds) { // 270s, 440s, 540s after the start
            $this->travel($seconds)->seconds();
            $this->hold($slot)->assertSuccessful();
        }

        $this->assertSame($createdAt + 600, WorkstationSlotHold::firstOrFail()->expires_at->timestamp);

        // And once that cap passes, the slot really is free for someone else.
        $this->travel(61)->seconds();
        $this->actAs($this->bob);
        $this->hold($slot)->assertCreated();
    }

    public function test_holding_a_new_slot_releases_the_previous_one(): void
    {
        $first = $this->todaysSlot(null, 9);
        $second = $this->todaysSlot(null, 10);

        $this->actAs($this->alice);
        $this->hold($first)->assertCreated();
        $this->hold($second)->assertCreated();

        $this->assertDatabaseMissing('workstation_slot_holds', ['workstation_slot_id' => $first->id]);
        $this->assertDatabaseHas('workstation_slot_holds', ['workstation_slot_id' => $second->id, 'user_id' => $this->alice->id]);

        // …so someone else can take the one Alice walked away from.
        $this->actAs($this->bob);
        $this->hold($first)->assertCreated();
    }

    public function test_confirming_turns_the_hold_into_an_order_and_removes_the_hold(): void
    {
        $slot = $this->todaysSlot();
        $this->actAs($this->alice);
        $this->hold($slot)->assertCreated();

        $this->postJson('/api/orders', ['customer_name' => 'Rahim', 'workstation_slot_id' => $slot->id])
            ->assertCreated();

        $this->assertDatabaseCount('workstation_slot_holds', 0);
        $this->assertDatabaseHas('orders', ['workstation_slot_id' => $slot->id, 'user_id' => $this->alice->id]);
    }

    public function test_confirming_while_someone_else_holds_the_slot_is_refused(): void
    {
        $slot = $this->todaysSlot();

        $this->actAs($this->alice);
        $this->hold($slot)->assertCreated();

        $this->actAs($this->bob);
        $this->postJson('/api/orders', ['customer_name' => 'Karim', 'workstation_slot_id' => $slot->id])
            ->assertConflict()->assertJsonPath('code', 'slot_held');

        $this->assertDatabaseCount('orders', 0);
        $this->assertDatabaseHas('workstation_slot_holds', ['user_id' => $this->alice->id]);
    }

    public function test_a_confirm_after_your_hold_lapsed_and_someone_took_over_is_refused(): void
    {
        $slot = $this->todaysSlot();

        $this->actAs($this->alice);
        $this->hold($slot)->assertCreated();

        $this->travel(181)->seconds();
        $this->actAs($this->bob);
        $this->hold($slot)->assertCreated();

        $this->actAs($this->alice);
        $this->postJson('/api/orders', ['customer_name' => 'Rahim', 'workstation_slot_id' => $slot->id])
            ->assertConflict()->assertJsonPath('code', 'slot_held');

        $this->assertDatabaseCount('orders', 0);
    }

    public function test_a_confirm_after_your_hold_lapsed_still_works_if_nobody_else_took_the_slot(): void
    {
        $slot = $this->todaysSlot();
        $this->actAs($this->alice);
        $this->hold($slot)->assertCreated();

        $this->travel(181)->seconds();

        $this->postJson('/api/orders', ['customer_name' => 'Rahim', 'workstation_slot_id' => $slot->id])
            ->assertCreated();
    }

    public function test_only_the_holder_can_release_and_releasing_is_always_safe(): void
    {
        $slot = $this->todaysSlot();

        $this->actAs($this->alice);
        $this->hold($slot)->assertCreated();

        $this->actAs($this->bob);
        $this->deleteJson("/api/workstation-slots/{$slot->id}/hold")->assertNoContent();
        $this->assertDatabaseHas('workstation_slot_holds', ['user_id' => $this->alice->id]); // untouched

        $this->actAs($this->alice);
        $this->deleteJson("/api/workstation-slots/{$slot->id}/hold")->assertNoContent();
        $this->deleteJson("/api/workstation-slots/{$slot->id}/hold")->assertNoContent(); // nothing left; still fine
        $this->assertDatabaseCount('workstation_slot_holds', 0);

        $this->actAs($this->bob);
        $this->hold($slot)->assertCreated();
    }

    public function test_booked_and_inactive_slots_cannot_be_held_but_a_cancelled_booking_frees_its_slot(): void
    {
        $this->actAs($this->alice);

        $slot = $this->todaysSlot();
        $order = Order::factory()->create(['workstation_id' => $slot->workstation_id, 'workstation_slot_id' => $slot->id]);

        $this->hold($slot)->assertConflict()->assertJsonPath('code', 'slot_booked');

        $order->update(['status' => OrderStatus::Cancelled]);
        $this->hold($slot)->assertCreated();

        $inactive = $this->todaysSlot(Workstation::factory()->create(['is_active' => false]));
        $this->hold($inactive)->assertUnprocessable()->assertJsonValidationErrors('workstation_slot_id');
    }

    public function test_a_conflict_is_not_remembered_by_the_idempotency_key(): void
    {
        $slot = $this->todaysSlot();
        $key = (string) Str::uuid();
        $payload = ['customer_name' => 'Karim', 'workstation_slot_id' => $slot->id];

        $this->actAs($this->alice);
        $this->hold($slot)->assertCreated();

        $this->actAs($this->bob);
        $this->withHeaders(['Idempotency-Key' => $key])->postJson('/api/orders', $payload)->assertConflict();

        // Alice walks away; the same retry (same key) must now be processed afresh.
        $this->actAs($this->alice);
        $this->deleteJson("/api/workstation-slots/{$slot->id}/hold")->assertNoContent();

        $this->actAs($this->bob);
        $this->withHeaders(['Idempotency-Key' => $key])->postJson('/api/orders', $payload)
            ->assertCreated()
            ->assertHeaderMissing('Idempotency-Replayed');
    }

    public function test_the_database_itself_refuses_a_second_hold_on_one_slot(): void
    {
        $slot = $this->todaysSlot();
        WorkstationSlotHold::create(['workstation_slot_id' => $slot->id, 'user_id' => $this->alice->id, 'expires_at' => now()->addMinute()]);

        $this->expectException(QueryException::class);

        WorkstationSlotHold::create(['workstation_slot_id' => $slot->id, 'user_id' => $this->bob->id, 'expires_at' => now()->addMinute()]);
    }
}
