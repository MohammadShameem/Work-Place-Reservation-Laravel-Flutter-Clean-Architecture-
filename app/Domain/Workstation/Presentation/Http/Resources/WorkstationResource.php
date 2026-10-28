<?php

namespace App\Domain\Workstation\Presentation\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use OpenApi\Attributes as OA;

#[OA\Schema(
    schema: 'Workstation',
    required: ['id', 'name', 'code', 'location', 'is_active'],
    properties: [
        new OA\Property(property: 'id', type: 'integer', example: 1),
        new OA\Property(property: 'name', type: 'string', example: 'Workstation 1'),
        new OA\Property(property: 'code', type: 'string', example: 'WS-01'),
        new OA\Property(property: 'location', type: 'string', example: 'Building A - Floor 1'),
        new OA\Property(property: 'is_active', type: 'boolean', example: true),
        new OA\Property(property: 'orders_count', type: 'integer', example: 3, nullable: true, description: 'Present only when requested with a count'),
        new OA\Property(property: 'created_at', type: 'string', format: 'date-time'),
        new OA\Property(property: 'updated_at', type: 'string', format: 'date-time'),
    ]
)]
/** @mixin \App\Domain\Workstation\Infrastructure\Models\Workstation */
class WorkstationResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'code' => $this->code,
            'location' => $this->location,
            'is_active' => $this->is_active,
            'orders_count' => $this->whenCounted('orders'),
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,
        ];
    }
}
