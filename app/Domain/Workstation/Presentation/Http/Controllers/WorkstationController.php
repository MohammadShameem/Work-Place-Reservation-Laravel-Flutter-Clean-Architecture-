<?php

declare(strict_types=1);

namespace App\Domain\Workstation\Presentation\Http\Controllers;

use App\Domain\Workstation\Application\UseCases\CreateWorkstationUseCase;
use App\Domain\Workstation\Application\UseCases\DeleteWorkstationUseCase;
use App\Domain\Workstation\Application\UseCases\GetWorkstationUseCase;
use App\Domain\Workstation\Application\UseCases\ListWorkstationOrdersUseCase;
use App\Domain\Workstation\Application\UseCases\ListWorkstationSlotsUseCase;
use App\Domain\Workstation\Application\UseCases\ListWorkstationsUseCase;
use App\Domain\Workstation\Application\UseCases\UpdateWorkstationUseCase;
use App\Domain\Workstation\Infrastructure\Models\Workstation;
use App\Domain\Workstation\Presentation\Http\Resources\WorkstationResource;
use App\Domain\Workstation\Presentation\Http\Resources\WorkstationSlotResource;
use App\Domain\Order\Presentation\Http\Resources\OrderResource;
use App\Http\Controllers\Controller;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Validation\Rule;
use OpenApi\Attributes as OA;

class WorkstationController extends Controller
{
    public function __construct(
        private readonly ListWorkstationsUseCase $listWorkstations,
        private readonly CreateWorkstationUseCase $createWorkstation,
        private readonly GetWorkstationUseCase $getWorkstation,
        private readonly UpdateWorkstationUseCase $updateWorkstation,
        private readonly DeleteWorkstationUseCase $deleteWorkstation,
        private readonly ListWorkstationOrdersUseCase $listWorkstationOrders,
        private readonly ListWorkstationSlotsUseCase $listWorkstationSlots,
    ) {
    }

    #[OA\Get(
        path: '/api/workstations',
        description: 'Returns all workstations, each with its order count, ordered by code.',
        summary: 'List workstations',
        security: [['sanctum' => []]],
        tags: ['Workstations'],
        responses: [
            new OA\Response(
                response: 200,
                description: 'OK',
                content: new OA\JsonContent(
                    properties: [new OA\Property(property: 'data', type: 'array', items: new OA\Items(ref: '#/components/schemas/Workstation'))]
                )
            ),
            new OA\Response(response: 401, description: 'Missing or invalid token'),
        ]
    )]
    public function index(): AnonymousResourceCollection
    {
        return WorkstationResource::collection($this->listWorkstations->handle());
    }

    #[OA\Post(
        path: '/api/workstations',
        summary: 'Create a workstation',
        security: [['sanctum' => []]],
        tags: ['Workstations'],
        requestBody: new OA\RequestBody(
            required: true,
            content: new OA\JsonContent(
                required: ['name', 'code', 'location'],
                properties: [
                    new OA\Property(property: 'name', type: 'string', example: 'Workstation 5'),
                    new OA\Property(property: 'code', type: 'string', example: 'WS-05', description: 'Must be unique'),
                    new OA\Property(property: 'location', type: 'string', example: 'Building A - Floor 1'),
                    new OA\Property(property: 'is_active', type: 'boolean', example: true),
                ]
            )
        ),
        responses: [
            new OA\Response(response: 201, description: 'Created', content: new OA\JsonContent(properties: [new OA\Property(property: 'data', ref: '#/components/schemas/Workstation')])),
            new OA\Response(response: 422, description: 'Validation failed (e.g. duplicate code)', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
        ]
    )]
    public function store(Request $request): WorkstationResource
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'code' => ['required', 'string', 'max:50', 'unique:workstations,code'],
            'location' => ['required', 'string', 'max:255'],
            'is_active' => ['boolean'],
        ]);

        return new WorkstationResource($this->createWorkstation->handle($data));
    }

    #[OA\Get(
        path: '/api/workstations/{workstation}',
        summary: 'Get one workstation',
        security: [['sanctum' => []]],
        tags: ['Workstations'],
        parameters: [new OA\Parameter(name: 'workstation', in: 'path', required: true, description: 'Workstation id', schema: new OA\Schema(type: 'integer'))],
        responses: [
            new OA\Response(response: 200, description: 'OK', content: new OA\JsonContent(properties: [new OA\Property(property: 'data', ref: '#/components/schemas/Workstation')])),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function show(Workstation $workstation): WorkstationResource
    {
        return new WorkstationResource($this->getWorkstation->handle($workstation->id));
    }

    #[OA\Put(
        path: '/api/workstations/{workstation}',
        summary: 'Update a workstation',
        security: [['sanctum' => []]],
        tags: ['Workstations'],
        parameters: [new OA\Parameter(name: 'workstation', in: 'path', required: true, description: 'Workstation id', schema: new OA\Schema(type: 'integer'))],
        requestBody: new OA\RequestBody(
            content: new OA\JsonContent(
                properties: [
                    new OA\Property(property: 'name', type: 'string', example: 'Workstation 5'),
                    new OA\Property(property: 'code', type: 'string', example: 'WS-05'),
                    new OA\Property(property: 'location', type: 'string', example: 'Building A - Floor 1'),
                    new OA\Property(property: 'is_active', type: 'boolean', example: false, description: 'Inactive workstations cannot be booked'),
                ]
            )
        ),
        responses: [
            new OA\Response(response: 200, description: 'Updated', content: new OA\JsonContent(properties: [new OA\Property(property: 'data', ref: '#/components/schemas/Workstation')])),
            new OA\Response(response: 422, description: 'Validation failed', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function update(Request $request, Workstation $workstation): WorkstationResource
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'code' => ['sometimes', 'required', 'string', 'max:50', Rule::unique('workstations', 'code')->ignore($workstation)],
            'location' => ['sometimes', 'required', 'string', 'max:255'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        return new WorkstationResource($this->updateWorkstation->handle($workstation->id, $data));
    }

    #[OA\Delete(
        path: '/api/workstations/{workstation}',
        description: 'Deletes the workstation and its unbooked slots. Refused if any order — past or present — was ever made against it.',
        summary: 'Delete a workstation',
        security: [['sanctum' => []]],
        tags: ['Workstations'],
        parameters: [new OA\Parameter(name: 'workstation', in: 'path', required: true, description: 'Workstation id', schema: new OA\Schema(type: 'integer'))],
        responses: [
            new OA\Response(response: 204, description: 'Deleted'),
            new OA\Response(response: 422, description: 'This workstation has order history and cannot be deleted', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function destroy(Workstation $workstation): Response
    {
        $this->deleteWorkstation->handle($workstation->id);

        return response()->noContent();
    }

    #[OA\Get(
        path: '/api/workstations/{workstation}/orders',
        summary: 'List a workstation\'s orders',
        security: [['sanctum' => []]],
        tags: ['Workstations'],
        parameters: [new OA\Parameter(name: 'workstation', in: 'path', required: true, description: 'Workstation id', schema: new OA\Schema(type: 'integer'))],
        responses: [
            new OA\Response(
                response: 200,
                description: 'Paginated orders for this workstation, newest first',
                content: new OA\JsonContent(properties: [new OA\Property(property: 'data', type: 'array', items: new OA\Items(ref: '#/components/schemas/Order'))])
            ),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function orders(Workstation $workstation): AnonymousResourceCollection
    {
        return OrderResource::collection($this->listWorkstationOrders->handle($workstation->id));
    }

    #[OA\Get(
        path: '/api/workstations/{workstation}/slots',
        description: 'One day\'s worth of bookable time slots (defaults to today). Each slot has a status: available, '
            .'held (another user is on the confirm screen — temporary), held_by_you, or booked. Poll this every few '
            .'seconds while the slot picker is open to keep it current.',
        summary: 'List a workstation\'s time slots',
        security: [['sanctum' => []]],
        tags: ['Workstations'],
        parameters: [
            new OA\Parameter(name: 'workstation', in: 'path', required: true, description: 'Workstation id', schema: new OA\Schema(type: 'integer')),
            new OA\Parameter(name: 'date', in: 'query', required: false, description: 'Defaults to today', schema: new OA\Schema(type: 'string', format: 'date')),
        ],
        responses: [
            new OA\Response(
                response: 200,
                description: 'OK',
                content: new OA\JsonContent(properties: [new OA\Property(property: 'data', type: 'array', items: new OA\Items(ref: '#/components/schemas/WorkstationSlot'))])
            ),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function slots(Request $request, Workstation $workstation): AnonymousResourceCollection
    {
        $data = $request->validate([
            'date' => ['nullable', 'date'],
        ]);

        $day = isset($data['date']) ? Carbon::parse($data['date'])->startOfDay() : now()->startOfDay();

        return WorkstationSlotResource::collection($this->listWorkstationSlots->handle($workstation->id, $day));
    }
}
