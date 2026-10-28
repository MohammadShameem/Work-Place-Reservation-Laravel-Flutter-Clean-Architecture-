<?php

namespace App\Domain\Order\Presentation\Http\Resources;

use App\Domain\Workstation\Presentation\Http\Resources\WorkstationResource;
use App\Domain\Workstation\Presentation\Http\Resources\WorkstationSlotResource;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use OpenApi\Attributes as OA;

#[OA\Schema(
    schema: 'Order',
    required: ['id', 'order_number', 'customer_name', 'status'],
    properties: [
        new OA\Property(property: 'id', type: 'integer', example: 1),
        new OA\Property(property: 'order_number', type: 'string', example: 'ORD-20261014-AB12CD'),
        new OA\Property(property: 'customer_name', type: 'string', example: 'Rahim'),
        new OA\Property(property: 'status', ref: '#/components/schemas/OrderStatus'),
        new OA\Property(property: 'notes', type: 'string', nullable: true, example: null),
        new OA\Property(property: 'workstation', ref: '#/components/schemas/Workstation'),
        new OA\Property(property: 'workstation_slot', ref: '#/components/schemas/WorkstationSlot'),
        new OA\Property(property: 'created_at', type: 'string', format: 'date-time'),
        new OA\Property(property: 'updated_at', type: 'string', format: 'date-time'),
    ]
)]
#[OA\Schema(
    schema: 'OrderStatus',
    type: 'string',
    enum: ['pending', 'in_progress', 'completed', 'cancelled'],
    example: 'pending'
)]
/** @mixin \App\Domain\Order\Infrastructure\Models\Order */
class OrderResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'order_number' => $this->order_number,
            'customer_name' => $this->customer_name,
            'status' => $this->status,
            'notes' => $this->notes,
            'workstation' => new WorkstationResource($this->whenLoaded('workstation')),
            'workstation_slot' => new WorkstationSlotResource($this->whenLoaded('workstationSlot')),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
