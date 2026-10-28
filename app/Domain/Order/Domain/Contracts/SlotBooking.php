<?php

namespace App\Domain\Order\Domain\Contracts;

use App\Domain\Workstation\Domain\Exceptions\SlotConflictException;
use App\Domain\Order\Infrastructure\Models\Order;
use App\Domain\Auth\Infrastructure\Models\User;

/**
 * Turns "this user wants this slot" into an Order. An order IS the booking.
 */
interface SlotBooking
{
    /**
     * @throws SlotConflictException when the slot is booked or held by someone else
     */
    public function book(User $user, int $slotId, string $customerName, ?string $notes): Order;
}
