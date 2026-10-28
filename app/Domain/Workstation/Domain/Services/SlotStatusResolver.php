<?php

namespace App\Domain\Workstation\Domain\Services;

use App\Domain\Workstation\Domain\Enums\SlotStatus;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlotHold;

/**
 * The business rule for "what does this slot look like to one viewer" —
 * pulled out of the Eloquent model so it is a pure function over plain
 * inputs, with no query of its own.
 */
class SlotStatusResolver
{
    public static function resolve(bool $isBooked, ?WorkstationSlotHold $activeHold, ?int $viewerId): SlotStatus
    {
        if ($isBooked) {
            return SlotStatus::Booked;
        }

        if (! $activeHold) {
            return SlotStatus::Available;
        }

        return $activeHold->user_id === $viewerId ? SlotStatus::HeldByYou : SlotStatus::Held;
    }
}
