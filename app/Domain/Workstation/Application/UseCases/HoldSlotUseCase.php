<?php

namespace App\Domain\Workstation\Application\UseCases;

use App\Domain\Auth\Infrastructure\Models\User;
use App\Domain\Order\Domain\Repositories\OrderRepository;
use App\Domain\Shared\Domain\TransactionManager;
use App\Domain\Workstation\Domain\Contracts\SlotHolds;
use App\Domain\Workstation\Domain\Exceptions\SlotConflictException;
use App\Domain\Workstation\Domain\Repositories\WorkstationSlotHoldRepository;
use App\Domain\Workstation\Domain\Repositories\WorkstationSlotRepository;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlotHold;
use Illuminate\Validation\ValidationException;

/**
 * Short-lived "someone is booking this" claim on a slot.
 *
 * Every rule that decides who wins runs inside one transaction under a row
 * lock on the slot, so two people grabbing the same slot at the same instant
 * are serialized: the second one finds the first one's hold and is turned
 * away. Nothing here depends on the clients behaving or on a cleanup job.
 */
class HoldSlotUseCase implements SlotHolds
{
    /**
     * The lifetimes are handed in rather than read from config() in here, so
     * this class has no hidden inputs: a test can build one with a 5-second
     * hold, and the container decides what production gets (AppServiceProvider).
     */
    public function __construct(
        private readonly WorkstationSlotRepository $slots,
        private readonly WorkstationSlotHoldRepository $holds,
        private readonly OrderRepository $orders,
        private readonly TransactionManager $transactions,
        private readonly int $holdTtlSeconds,
        private readonly int $holdMaxSeconds,
    ) {
    }

    public function acquire(User $user, int $slotId): WorkstationSlotHold
    {
        // 3 attempts: two users each swapping to the other's slot can
        // deadlock on the lock order; the database aborts one, we retry it.
        return $this->transactions->run(function () use ($user, $slotId) {
            $slot = $this->slots->lockWithWorkstation($slotId);

            if (! $slot->workstation->is_active) {
                throw ValidationException::withMessages([
                    'workstation_slot_id' => ['This workstation is not currently active.'],
                ]);
            }

            if ($this->orders->existsActiveForSlot($slot->id)) {
                throw SlotConflictException::booked();
            }

            $existing = $this->holds->lockForSlot($slot->id);

            if ($existing && ! $existing->isExpired() && $existing->user_id !== $user->id) {
                $secondsLeft = (int) ceil(now()->diffInSeconds($existing->expires_at, false));

                throw SlotConflictException::held(max(1, $secondsLeft));
            }

            // One live hold per person, so nobody can sit on many slots.
            $this->holds->deleteOtherHoldsForUser($user->id, $slot->id);

            if ($existing && $existing->user_id === $user->id && ! $existing->isExpired()) {
                // Renew, but never past the overall cap counted from when
                // this continuous hold began.
                $cap = $existing->created_at->copy()->addSeconds($this->holdMaxSeconds);
                $renewed = now()->addSeconds($this->holdTtlSeconds)->min($cap);

                if ($renewed->gt($existing->expires_at)) {
                    $existing->expires_at = $renewed;
                    $this->holds->save($existing);
                }

                return $existing->setRelation('slot', $slot);
            }

            // Expired leftovers (anyone's) are cleared here, lazily.
            if ($existing) {
                $this->holds->delete($existing);
            }

            $hold = $this->holds->create([
                'workstation_slot_id' => $slot->id,
                'user_id' => $user->id,
                'expires_at' => now()->addSeconds($this->holdTtlSeconds),
            ]);

            return $hold->setRelation('slot', $slot);
        }, 3);
    }

    public function release(User $user, int $slotId): void
    {
        $this->holds->deleteForSlotAndUser($slotId, $user->id);
    }
}
