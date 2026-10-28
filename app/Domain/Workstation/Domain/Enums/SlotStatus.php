<?php

namespace App\Domain\Workstation\Domain\Enums;

/**
 * How one slot looks to one particular viewer.
 */
enum SlotStatus: string
{
    case Available = 'available';
    case Held = 'held';           // someone else is on the confirm screen
    case HeldByYou = 'held_by_you';
    case Booked = 'booked';       // a non-cancelled order owns it
}
