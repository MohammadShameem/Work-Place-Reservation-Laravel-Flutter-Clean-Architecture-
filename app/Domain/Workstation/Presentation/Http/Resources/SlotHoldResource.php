<?php

namespace App\Domain\Workstation\Presentation\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use OpenApi\Attributes as OA;

#[OA\Schema(
    schema: 'SlotHold',
    required: ['workstation_slot_id', 'expires_at', 'server_time'],
    properties: [
        new OA\Property(property: 'workstation_slot_id', type: 'integer', example: 10),
        new OA\Property(property: 'expires_at', type: 'string', format: 'date-time'),
        new OA\Property(
            property: 'server_time',
            type: 'string',
            format: 'date-time',
            description: 'The server\'s clock when this was issued. Count down from expires_at - server_time, '
                .'not from the phone\'s own clock, which may be wrong.'
        ),
    ]
)]
/** @mixin \App\Domain\Workstation\Infrastructure\Models\WorkstationSlotHold */
class SlotHoldResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'workstation_slot_id' => $this->workstation_slot_id,
            'expires_at' => $this->expires_at,
            'server_time' => now(),
        ];
    }
}
