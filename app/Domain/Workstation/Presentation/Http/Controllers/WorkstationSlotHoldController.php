<?php

declare(strict_types=1);

namespace App\Domain\Workstation\Presentation\Http\Controllers;

use App\Domain\Workstation\Domain\Contracts\SlotHolds;
use App\Http\Controllers\Controller;
use App\Domain\Workstation\Presentation\Http\Resources\SlotHoldResource;
use App\Domain\Workstation\Infrastructure\Models\WorkstationSlot;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use OpenApi\Attributes as OA;

#[OA\Schema(
    schema: 'SlotConflict',
    required: ['message', 'code'],
    properties: [
        new OA\Property(property: 'message', type: 'string', example: 'Another user is selecting this slot right now. It is not available at the moment, but it may become available again shortly.'),
        new OA\Property(property: 'code', type: 'string', enum: ['slot_held', 'slot_booked'], example: 'slot_held'),
        new OA\Property(property: 'retry_after', type: 'integer', example: 142, description: 'Only for slot_held: seconds until the hold lapses at the latest'),
    ]
)]
class WorkstationSlotHoldController extends Controller
{
    public function __construct(private readonly SlotHolds $holds)
    {
    }

    #[OA\Post(
        path: '/api/workstation-slots/{workstationSlot}/hold',
        description: 'Call this when the user taps a slot, before showing the confirm screen. It reserves the slot for a few '
            .'minutes so nobody else starts booking it. Calling it again while you still hold the slot renews the hold '
            .'(up to an overall cap). You can only hold one slot at a time: holding a new one releases your previous one.',
        summary: 'Hold a slot while confirming a booking',
        security: [['sanctum' => []]],
        tags: ['Workstations'],
        parameters: [new OA\Parameter(name: 'workstationSlot', in: 'path', required: true, description: 'Slot id', schema: new OA\Schema(type: 'integer'))],
        responses: [
            new OA\Response(response: 200, description: 'Held (or renewed)', content: new OA\JsonContent(properties: [new OA\Property(property: 'data', ref: '#/components/schemas/SlotHold')])),
            new OA\Response(response: 201, description: 'Held (new hold)', content: new OA\JsonContent(properties: [new OA\Property(property: 'data', ref: '#/components/schemas/SlotHold')])),
            new OA\Response(response: 409, description: 'slot_held (someone else is on it; temporary) or slot_booked (permanent)', content: new OA\JsonContent(ref: '#/components/schemas/SlotConflict')),
            new OA\Response(response: 422, description: 'The slot\'s workstation is not active', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function store(Request $request, WorkstationSlot $workstationSlot): SlotHoldResource
    {
        return new SlotHoldResource($this->holds->acquire($request->user(), $workstationSlot->id));
    }

    #[OA\Delete(
        path: '/api/workstation-slots/{workstationSlot}/hold',
        description: 'Call when the user leaves the confirm screen without booking. Always succeeds, even if there is no '
            .'hold to release. Skipping it is harmless: the hold lapses on its own after a few minutes.',
        summary: 'Release your hold on a slot',
        security: [['sanctum' => []]],
        tags: ['Workstations'],
        parameters: [new OA\Parameter(name: 'workstationSlot', in: 'path', required: true, description: 'Slot id', schema: new OA\Schema(type: 'integer'))],
        responses: [
            new OA\Response(response: 204, description: 'Released'),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function destroy(Request $request, WorkstationSlot $workstationSlot): Response
    {
        $this->holds->release($request->user(), $workstationSlot->id);

        return response()->noContent();
    }
}
