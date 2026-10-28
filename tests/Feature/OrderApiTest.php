<?php

namespace Tests\Feature;

use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Infrastructure\Models\Order;
use App\Domain\Auth\Infrastructure\Models\User;
use App\Domain\Workstation\Infrastructure\Models\Workstation;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderApiTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Sanctum's guard caches the resolved user on itself after the first
     * lookup in a request cycle. In production that guard is rebuilt fresh
     * per process, but within a single test method it survives across
     * multiple calls, so a later request with a different (or now-revoked)
     * token would otherwise keep seeing the first one's result. Forgetting
     * the guard before each call that intentionally switches tokens forces
     * a real re-authentication against the current database state.
     */
    private function asToken(?string $token)
    {
        Auth::forgetGuards();

        return $token ? $this->withToken($token) : $this;
    }

    public function test_register_and_login_return_an_access_and_refresh_token(): void
    {
        $this->postJson('/api/register', [
            'name' => 'Momin',
            'email' => 'momin@example.com',
            'password' => 'password123',
            'device_name' => 'flutter-android',
        ])->assertCreated()
            ->assertJsonStructure([
                'user' => ['id', 'email'],
                'access_token', 'access_token_expires_at',
                'refresh_token', 'refresh_token_expires_at',
            ])
            ->assertJsonMissingPath('user.password');

        $this->postJson('/api/login', [
            'email' => 'momin@example.com',
            'password' => 'password123',
        ])->assertOk()->assertJsonStructure(['access_token', 'refresh_token']);

        $this->postJson('/api/login', [
            'email' => 'momin@example.com',
            'password' => 'wrong-password',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');

        $this->assertDatabaseCount('personal_access_tokens', 4); // 2 logins x (access + refresh)
    }

    public function test_access_token_authenticates_requests_and_logout_revokes_the_pair(): void
    {
        $tokens = $this->postJson('/api/register', [
            'name' => 'Momin',
            'email' => 'momin@example.com',
            'password' => 'password123',
        ])->json();

        $this->asToken($tokens['access_token'])->getJson('/api/user')
            ->assertOk()->assertJsonPath('email', 'momin@example.com');

        $this->asToken($tokens['access_token'])->postJson('/api/logout')->assertOk();

        $this->assertDatabaseCount('personal_access_tokens', 0); // both access + refresh gone

        $this->asToken($tokens['access_token'])->getJson('/api/user')->assertUnauthorized();
    }

    public function test_refresh_token_issues_a_new_pair_and_retires_itself(): void
    {
        $tokens = $this->postJson('/api/register', [
            'name' => 'Momin',
            'email' => 'momin@example.com',
            'password' => 'password123',
        ])->json();

        $fresh = $this->asToken($tokens['refresh_token'])->postJson('/api/refresh')
            ->assertOk()
            ->assertJsonStructure(['access_token', 'refresh_token'])
            ->json();

        $this->assertNotSame($tokens['access_token'], $fresh['access_token']);
        $this->assertNotSame($tokens['refresh_token'], $fresh['refresh_token']);

        // Old pair is dead, including the refresh token just used (no reuse).
        $this->asToken($tokens['access_token'])->getJson('/api/user')->assertUnauthorized();
        $this->asToken($tokens['refresh_token'])->postJson('/api/refresh')->assertUnauthorized();

        // New access token works for business endpoints.
        $this->asToken($fresh['access_token'])->getJson('/api/user')->assertOk();

        $this->assertDatabaseCount('personal_access_tokens', 2);
    }

    public function test_an_access_token_cannot_be_used_to_refresh_and_a_refresh_token_cannot_call_business_endpoints(): void
    {
        $tokens = $this->postJson('/api/register', [
            'name' => 'Momin',
            'email' => 'momin@example.com',
            'password' => 'password123',
        ])->json();

        $this->asToken($tokens['access_token'])->postJson('/api/refresh')->assertForbidden();
        $this->asToken($tokens['refresh_token'])->getJson('/api/workstations')->assertForbidden();
    }

    public function test_guests_cannot_use_protected_endpoints(): void
    {
        $this->getJson('/api/workstations')->assertUnauthorized();
        $this->getJson('/api/orders')->assertUnauthorized();
        $this->postJson('/api/orders', ['customer_name' => 'Rahim'])->assertUnauthorized();
    }

    public function test_workstations_can_be_listed_created_and_updated(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        Workstation::factory()->create(['name' => 'Workstation 1', 'code' => 'WS-01', 'location' => 'Building A - Floor 1']);

        $this->getJson('/api/workstations')->assertOk()->assertJsonCount(1, 'data');

        $this->postJson('/api/workstations', ['name' => 'Workstation 2', 'code' => 'WS-02', 'location' => 'Building A - Floor 2'])
            ->assertCreated()
            ->assertJsonPath('data.code', 'WS-02')
            ->assertJsonPath('data.location', 'Building A - Floor 2');

        $this->postJson('/api/workstations', ['name' => 'Duplicate', 'code' => 'WS-02', 'location' => 'Anywhere'])
            ->assertUnprocessable()->assertJsonValidationErrors('code');

        $this->postJson('/api/workstations', ['name' => 'No location', 'code' => 'WS-09'])
            ->assertUnprocessable()->assertJsonValidationErrors('location');

        $workstation = Workstation::where('code', 'WS-02')->first();

        // Keeping its own code on update must not trip the unique rule.
        $this->patchJson("/api/workstations/{$workstation->id}", ['code' => 'WS-02', 'is_active' => false])
            ->assertOk()->assertJsonPath('data.is_active', false);
    }

    public function test_a_workstations_slots_show_their_availability(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $workstation = Workstation::factory()->create();
        $today = now()->startOfDay();

        $openSlot = WorkstationSlot::factory()->for($workstation)->create([
            'starts_at' => $today->copy()->setTime(9, 0),
            'ends_at' => $today->copy()->setTime(10, 0),
        ]);
        $bookedSlot = WorkstationSlot::factory()->for($workstation)->create([
            'starts_at' => $today->copy()->setTime(10, 0),
            'ends_at' => $today->copy()->setTime(11, 0),
        ]);
        Order::factory()->create(['workstation_id' => $workstation->id, 'workstation_slot_id' => $bookedSlot->id]);

        $response = $this->getJson("/api/workstations/{$workstation->id}/slots")
            ->assertOk()
            ->assertJsonCount(2, 'data');

        $byId = collect($response->json('data'))->keyBy('id');
        $this->assertTrue($byId[$openSlot->id]['is_available']);
        $this->assertFalse($byId[$bookedSlot->id]['is_available']);
    }

    public function test_booking_a_slot_creates_a_pending_order_against_its_workstation(): void
    {
        $user = User::factory()->create();
        $workstation = Workstation::factory()->create();
        $slot = WorkstationSlot::factory()->for($workstation)->create();
        Sanctum::actingAs($user, ['access-api']);

        $response = $this->postJson('/api/orders', [
            'customer_name' => 'Rahim',
            'workstation_slot_id' => $slot->id,
        ])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.workstation.id', $workstation->id)
            ->assertJsonPath('data.workstation_slot.id', $slot->id)
            ->assertJsonPath('data.workstation_slot.is_available', false);

        $this->assertStringStartsWith('ORD-', $response->json('data.order_number'));
        $this->assertDatabaseHas('orders', [
            'user_id' => $user->id,
            'workstation_id' => $workstation->id,
            'workstation_slot_id' => $slot->id,
        ]);
    }

    public function test_idempotency_key_prevents_a_retried_booking_from_being_created_twice(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $slot = WorkstationSlot::factory()->create();
        $payload = ['customer_name' => 'Rahim', 'workstation_slot_id' => $slot->id];
        $key = (string) Str::uuid();

        $first = $this->withHeaders(['Idempotency-Key' => $key])
            ->postJson('/api/orders', $payload)
            ->assertCreated();

        $second = $this->withHeaders(['Idempotency-Key' => $key])
            ->postJson('/api/orders', $payload)
            ->assertCreated()
            ->assertHeader('Idempotency-Replayed', 'true');

        $this->assertSame($first->json('data.id'), $second->json('data.id'));
        $this->assertDatabaseCount('orders', 1);
    }

    public function test_a_slot_cannot_be_double_booked_or_booked_on_an_inactive_workstation(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $takenSlot = WorkstationSlot::factory()->create();
        Order::factory()->create([
            'workstation_id' => $takenSlot->workstation_id,
            'workstation_slot_id' => $takenSlot->id,
        ]);

        // A booked slot is a state conflict (409, code slot_booked), not a validation error.
        $this->postJson('/api/orders', ['customer_name' => 'Rahim', 'workstation_slot_id' => $takenSlot->id])
            ->assertConflict()->assertJsonPath('code', 'slot_booked');

        $inactiveWorkstation = Workstation::factory()->create(['is_active' => false]);
        $slotOnInactive = WorkstationSlot::factory()->for($inactiveWorkstation)->create();

        $this->postJson('/api/orders', ['customer_name' => 'Rahim', 'workstation_slot_id' => $slotOnInactive->id])
            ->assertUnprocessable()->assertJsonValidationErrors('workstation_slot_id');

        $this->postJson('/api/orders', ['customer_name' => 'Rahim', 'workstation_slot_id' => 999999])
            ->assertUnprocessable()->assertJsonValidationErrors('workstation_slot_id');

        $this->assertDatabaseCount('orders', 1); // only the pre-existing booking above
    }

    public function test_cancelling_an_order_frees_its_slot_for_rebooking(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $slot = WorkstationSlot::factory()->create([
            'starts_at' => now()->startOfDay()->setTime(9, 0),
            'ends_at' => now()->startOfDay()->setTime(10, 0),
        ]);
        $order = Order::factory()->create([
            'workstation_id' => $slot->workstation_id,
            'workstation_slot_id' => $slot->id,
        ]);

        $this->patchJson("/api/orders/{$order->id}/status", ['status' => 'cancelled'])->assertOk();

        $slots = $this->getJson("/api/workstations/{$slot->workstation_id}/slots")->json('data');
        $thisSlot = collect($slots)->firstWhere('id', $slot->id);
        $this->assertTrue($thisSlot['is_available']);

        // Someone else can now book the freed slot.
        $this->postJson('/api/orders', ['customer_name' => 'Karim', 'workstation_slot_id' => $slot->id])
            ->assertCreated();
    }

    public function test_orders_can_be_filtered_by_status_and_workstation(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $ws1 = Workstation::factory()->create();
        $ws2 = Workstation::factory()->create();

        Order::factory()->forWorkstation($ws1)->create();
        Order::factory()->forWorkstation($ws1)->create(['status' => OrderStatus::Completed]);
        Order::factory()->forWorkstation($ws2)->create();

        $this->getJson('/api/orders')->assertOk()->assertJsonCount(3, 'data');
        $this->getJson("/api/orders?workstation_id={$ws1->id}")->assertJsonCount(2, 'data');
        $this->getJson('/api/orders?status=completed')->assertJsonCount(1, 'data');
        $this->getJson("/api/workstations/{$ws2->id}/orders")->assertOk()->assertJsonCount(1, 'data');
        $this->getJson('/api/orders?status=bogus')->assertUnprocessable();
    }

    public function test_status_follows_the_order_lifecycle(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $order = Order::factory()->create();

        // pending cannot jump straight to completed
        $this->patchJson("/api/orders/{$order->id}/status", ['status' => 'completed'])
            ->assertUnprocessable()->assertJsonValidationErrors('status');

        $this->patchJson("/api/orders/{$order->id}/status", ['status' => 'in_progress'])
            ->assertOk()->assertJsonPath('data.status', 'in_progress');

        $this->patchJson("/api/orders/{$order->id}/status", ['status' => 'completed'])
            ->assertOk()->assertJsonPath('data.status', 'completed');

        // closed orders cannot change, be edited or be deleted
        $this->patchJson("/api/orders/{$order->id}/status", ['status' => 'cancelled'])->assertUnprocessable();
        $this->patchJson("/api/orders/{$order->id}", ['customer_name' => 'Karim'])->assertUnprocessable();
        $this->deleteJson("/api/orders/{$order->id}")->assertUnprocessable();
        $this->assertDatabaseHas('orders', ['id' => $order->id]);
    }

    public function test_pending_orders_can_be_edited_and_deleted(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $slot = WorkstationSlot::factory()->create();

        $id = $this->postJson('/api/orders', ['customer_name' => 'Rahim', 'workstation_slot_id' => $slot->id])
            ->json('data.id');

        $this->patchJson("/api/orders/{$id}", ['notes' => 'Rush'])
            ->assertOk()->assertJsonPath('data.notes', 'Rush');

        $this->deleteJson("/api/orders/{$id}")->assertNoContent();
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_a_workstation_with_order_history_cannot_be_deleted(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $workstation = Workstation::factory()->create();
        Order::factory()->forWorkstation($workstation)->create();

        $this->deleteJson("/api/workstations/{$workstation->id}")
            ->assertUnprocessable()->assertJsonValidationErrors('workstation');

        $this->assertDatabaseHas('workstations', ['id' => $workstation->id]);
    }

    public function test_a_workstation_with_no_orders_can_be_deleted(): void
    {
        Sanctum::actingAs(User::factory()->create(), ['access-api']);
        $workstation = Workstation::factory()->create();
        WorkstationSlot::factory()->for($workstation)->create();

        $this->deleteJson("/api/workstations/{$workstation->id}")->assertNoContent();
        $this->assertDatabaseMissing('workstations', ['id' => $workstation->id]);
    }
}
