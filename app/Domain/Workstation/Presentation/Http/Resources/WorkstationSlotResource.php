<?php

namespace App\Domain\Workstation\Presentation\Http\Resources;

use App\Domain\Workstation\Domain\Enums\SlotStatus;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use OpenApi\Attributes as OA;

#[OA\Schema(
    schema: 'SlotStatus',
    type: 'string',
    enum: ['available', 'held', 'held_by_you', 'booked'],
    description: 'held = another user is on the confirm screen right now (temporary); '
        .'held_by_you = you are; booked = a non-cancelled order owns it (until cancelled).',
    example: 'available'
)]
#[OA\Schema(
    schema: 'WorkstationSlot',
    required: ['id', 'starts_at', 'ends_at', 'status', 'is_available'],
    properties: [
        new OA\Property(property: 'id', type: 'integer', example: 10),
        new OA\Property(property: 'starts_at', type: 'string', format: 'date-time'),
        new OA\Property(property: 'ends_at', type: 'string', format: 'date-time'),
        new OA\Property(property: 'status', ref: '#/components/schemas/SlotStatus'),
        new OA\Property(
            property: 'is_available',
            type: 'boolean',
            example: true,
            description: 'True only for status "available" — anyone can take it right now'
        ),
        new OA\Property(
            property: 'held_until',
            type: 'string',
            format: 'date-time',
            nullable: true,
            description: 'For held / held_by_you: the latest moment the hold lapses on its own. A held slot may free up sooner.'
        ),
    ]
)]
/**
 * @mixin \App\Domain\Workstation\Infrastructure\Models\WorkstationSlot
 *
 * The slots-listing endpoint eager-loads `active_orders_count` and `hold`
 * for the whole day (see WorkstationController::slots()) so this costs no
 * per-slot queries there. Nested under a single order it falls back to
 * direct lookups, which is fine for one record.
 */
class WorkstationSlotResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $status = $this->statusFor($request->user()?->id);

        // Only the time is exposed, never who holds it.
        $heldUntil = in_array($status, [SlotStatus::Held, SlotStatus::HeldByYou], true)
            ? $this->activeHold()?->expires_at
            : null;

        return [
            'id' => $this->id,
            'starts_at' => $this->starts_at,
            'ends_at' => $this->ends_at,
            'status' => $status,
            'is_available' => $status === SlotStatus::Available,
            'held_until' => $heldUntil,
        ];
    }
}
