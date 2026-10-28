<?php

namespace App\Domain\Workstation\Domain\Contracts;

use App\Domain\Workstation\Domain\Exceptions\SlotConflictException;
use App\Domain\Auth\Infrastructure\Models\User;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlotHold;
use Illuminate\Validation\ValidationException;

/**
 * The short-lived "someone is booking this slot" claim.
 *
 * Controllers and other services depend on this interface, never on a
 * concrete class. Which implementation runs is decided in one place
 * (AppServiceProvider), so it can be swapped — e.g. for a Redis-backed one,
 * or a fake in a test — without touching any caller.
 */
interface SlotHolds
{
    /**
     * Hold the slot for $user, or renew the hold they already have.
     *
     * @throws SlotConflictException when the slot is booked or held by someone else
     * @throws ValidationException when the slot's workstation is inactive
     */
    public function acquire(User $user, int $slotId): WorkstationSlotHold;

    /** Give the slot back. Safe to call any number of times, even with no hold. */
    public function release(User $user, int $slotId): void;
}
