<?php

namespace App\Domain\Order\Application\UseCases;

use App\Domain\Auth\Infrastructure\Models\User;
use App\Domain\Order\Domain\Contracts\SlotBooking;
use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Domain\Repositories\OrderRepository;
use App\Domain\Order\Infrastructure\Models\Order;
use App\Domain\Shared\Domain\TransactionManager;
use App\Domain\Workstation\Domain\Contracts\SlotHolds;
use App\Domain\Workstation\Domain\Repositories\WorkstationSlotHoldRepository;
use Illuminate\Support\Str;

/**
 * Crosses into the Workstation feature only through its ports (SlotHolds,
 * WorkstationSlotHoldRepository) — never its Eloquent models directly.
 */
class BookSlotUseCase implements SlotBooking
{
    public function __construct(
        private readonly SlotHolds $holds,
        private readonly OrderRepository $orders,
        private readonly WorkstationSlotHoldRepository $slotHolds,
        private readonly TransactionManager $transactions,
    ) {
    }

    public function book(User $user, int $slotId, string $customerName, ?string $notes): Order
    {
        // "Hold, then turn the hold into an order" in one transaction.
        // acquire() takes the slot's row lock, so two people confirming the
        // same slot are serialized; it also quietly takes a fresh hold if
        // ours lapsed but nobody else grabbed the slot, and throws 409
        // slot_held / slot_booked if someone else did. 3 attempts: a
        // deadlock aborts one transaction and it is simply retried.
        return $this->transactions->run(function () use ($user, $slotId, $customerName, $notes) {
            $hold = $this->holds->acquire($user, $slotId);
            $slot = $hold->slot;

            $order = $this->orders->create([
                'order_number' => 'ORD-'.now()->format('Ymd').'-'.Str::upper(Str::random(6)),
                'workstation_id' => $slot->workstation_id,
                'workstation_slot_id' => $slot->id,
                'user_id' => $user->id,
                'customer_name' => $customerName,
                'status' => OrderStatus::Pending,
                'notes' => $notes,
            ]);

            $this->slotHolds->delete($hold); // the order owns the slot now

            return $order;
        }, 3);
    }
}
