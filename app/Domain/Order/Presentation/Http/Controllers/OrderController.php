<?php

declare(strict_types=1);

namespace App\Domain\Order\Presentation\Http\Controllers;

use App\Domain\Order\Application\UseCases\BookSlotUseCase;
use App\Domain\Order\Application\UseCases\DeleteOrderUseCase;
use App\Domain\Order\Application\UseCases\GetOrderUseCase;
use App\Domain\Order\Application\UseCases\ListOrdersUseCase;
use App\Domain\Order\Application\UseCases\UpdateOrderStatusUseCase;
use App\Domain\Order\Application\UseCases\UpdateOrderUseCase;
use App\Domain\Order\Domain\Enums\OrderStatus;
use App\Domain\Order\Infrastructure\Models\Order;
use App\Domain\Order\Presentation\Http\Resources\OrderResource;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;
use Illuminate\Validation\Rule;
use OpenApi\Attributes as OA;

class OrderController extends Controller
{
    public function __construct(
        private readonly ListOrdersUseCase $listOrders,
        private readonly BookSlotUseCase $bookSlot,
        private readonly GetOrderUseCase $getOrder,
        private readonly UpdateOrderUseCase $updateOrder,
        private readonly UpdateOrderStatusUseCase $updateOrderStatus,
        private readonly DeleteOrderUseCase $deleteOrder,
    ) {
    }

    #[OA\Get(
        path: '/api/orders',
        description: 'Newest first, 15 per page. Both filters are optional and can be combined.',
        summary: 'List orders',
        security: [['sanctum' => []]],
        tags: ['Orders'],
        parameters: [
            new OA\Parameter(name: 'status', in: 'query', required: false, schema: new OA\Schema(ref: '#/components/schemas/OrderStatus')),
            new OA\Parameter(name: 'workstation_id', in: 'query', required: false, schema: new OA\Schema(type: 'integer')),
        ],
        responses: [
            new OA\Response(
                response: 200,
                description: 'OK',
                content: new OA\JsonContent(properties: [new OA\Property(property: 'data', type: 'array', items: new OA\Items(ref: '#/components/schemas/Order'))])
            ),
            new OA\Response(response: 422, description: 'Invalid filter value', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
        ]
    )]
    public function index(Request $request): AnonymousResourceCollection
    {
        $filters = $request->validate([
            'status' => ['nullable', Rule::enum(OrderStatus::class)],
            'workstation_id' => ['nullable', 'integer', 'exists:workstations,id'],
        ]);

        $status = isset($filters['status']) ? OrderStatus::from($filters['status']) : null;
        $workstationId = isset($filters['workstation_id']) ? (int) $filters['workstation_id'] : null;

        return OrderResource::collection($this->listOrders->handle($status, $workstationId));
    }

    #[OA\Post(
        path: '/api/orders',
        description: 'Books one of a workstation\'s time slots — this *is* the order, there are no line items. '
            .'Send a unique "Idempotency-Key" header so retrying this call after a lost response (common on mobile '
            .'networks) replays the first result instead of double-booking.',
        summary: 'Book a workstation slot',
        security: [['sanctum' => []]],
        tags: ['Orders'],
        parameters: [
            new OA\Parameter(
                name: 'Idempotency-Key',
                in: 'header',
                required: false,
                description: 'A client-generated UUID, one per logical attempt. Reusing it returns the original response unchanged.',
                schema: new OA\Schema(type: 'string', format: 'uuid')
            ),
        ],
        requestBody: new OA\RequestBody(
            required: true,
            content: new OA\JsonContent(
                required: ['customer_name', 'workstation_slot_id'],
                properties: [
                    new OA\Property(property: 'customer_name', type: 'string', example: 'Rahim'),
                    new OA\Property(property: 'workstation_slot_id', type: 'integer', example: 10, description: 'From GET /workstations/{id}/slots — must still be available'),
                    new OA\Property(property: 'notes', type: 'string', nullable: true, example: 'Rush order'),
                ]
            )
        ),
        responses: [
            new OA\Response(response: 201, description: 'Booked, status is "pending"', content: new OA\JsonContent(properties: [new OA\Property(property: 'data', ref: '#/components/schemas/Order')])),
            new OA\Response(
                response: 409,
                description: 'slot_held (another user is on it right now — temporary, try again soon), slot_booked (permanent), '
                    .'or the same Idempotency-Key is still being processed by another in-flight request (no code)',
                content: new OA\JsonContent(ref: '#/components/schemas/SlotConflict')
            ),
            new OA\Response(response: 422, description: 'Validation failed or the workstation is inactive', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
        ]
    )]
    public function store(Request $request): OrderResource
    {
        $data = $request->validate([
            'customer_name' => ['required', 'string', 'max:255'],
            'workstation_slot_id' => ['required', 'integer', 'exists:workstation_slots,id'],
            'notes' => ['nullable', 'string', 'max:2000'],
        ]);

        $order = $this->bookSlot->book(
            $request->user(),
            (int) $data['workstation_slot_id'],
            $data['customer_name'],
            $data['notes'] ?? null,
        );

        return new OrderResource($order);
    }

    #[OA\Get(
        path: '/api/orders/{order}',
        summary: 'Get one order',
        security: [['sanctum' => []]],
        tags: ['Orders'],
        parameters: [new OA\Parameter(name: 'order', in: 'path', required: true, description: 'Order id', schema: new OA\Schema(type: 'integer'))],
        responses: [
            new OA\Response(response: 200, description: 'OK', content: new OA\JsonContent(properties: [new OA\Property(property: 'data', ref: '#/components/schemas/Order')])),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function show(Order $order): OrderResource
    {
        return new OrderResource($this->getOrder->handle($order->id));
    }

    #[OA\Put(
        path: '/api/orders/{order}',
        description: 'The workstation/slot is fixed at booking time and can\'t be changed here — cancel and rebook '
            .'instead. Only pending or in-progress orders can be edited.',
        summary: 'Update an order',
        security: [['sanctum' => []]],
        tags: ['Orders'],
        parameters: [new OA\Parameter(name: 'order', in: 'path', required: true, description: 'Order id', schema: new OA\Schema(type: 'integer'))],
        requestBody: new OA\RequestBody(
            content: new OA\JsonContent(
                properties: [
                    new OA\Property(property: 'customer_name', type: 'string', example: 'Karim'),
                    new OA\Property(property: 'notes', type: 'string', nullable: true, example: 'Rush order'),
                ]
            )
        ),
        responses: [
            new OA\Response(response: 200, description: 'Updated', content: new OA\JsonContent(properties: [new OA\Property(property: 'data', ref: '#/components/schemas/Order')])),
            new OA\Response(response: 422, description: 'Validation failed, or the order is already completed/cancelled', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function update(Request $request, Order $order): OrderResource
    {
        $data = $request->validate([
            'customer_name' => ['sometimes', 'required', 'string', 'max:255'],
            'notes' => ['sometimes', 'nullable', 'string', 'max:2000'],
        ]);

        return new OrderResource($this->updateOrder->handle($order->id, $data));
    }

    #[OA\Patch(
        path: '/api/orders/{order}/status',
        description: "Allowed moves: pending → in_progress or cancelled; in_progress → completed or cancelled. "
            .'completed and cancelled are final. Cancelling frees the slot for others to book.',
        summary: 'Change order status',
        security: [['sanctum' => []]],
        tags: ['Orders'],
        parameters: [new OA\Parameter(name: 'order', in: 'path', required: true, description: 'Order id', schema: new OA\Schema(type: 'integer'))],
        requestBody: new OA\RequestBody(
            required: true,
            content: new OA\JsonContent(required: ['status'], properties: [new OA\Property(property: 'status', ref: '#/components/schemas/OrderStatus')])
        ),
        responses: [
            new OA\Response(response: 200, description: 'Status changed', content: new OA\JsonContent(properties: [new OA\Property(property: 'data', ref: '#/components/schemas/Order')])),
            new OA\Response(response: 422, description: 'That status change is not allowed from the current status', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function updateStatus(Request $request, Order $order): OrderResource
    {
        $data = $request->validate([
            'status' => ['required', Rule::enum(OrderStatus::class)],
        ]);

        return new OrderResource(
            $this->updateOrderStatus->handle($order->id, OrderStatus::from($data['status']))
        );
    }

    #[OA\Delete(
        path: '/api/orders/{order}',
        description: 'Only pending or cancelled orders can be deleted. Deleting a pending order also frees its slot.',
        summary: 'Delete an order',
        security: [['sanctum' => []]],
        tags: ['Orders'],
        parameters: [new OA\Parameter(name: 'order', in: 'path', required: true, description: 'Order id', schema: new OA\Schema(type: 'integer'))],
        responses: [
            new OA\Response(response: 204, description: 'Deleted'),
            new OA\Response(response: 422, description: 'The order is in_progress or completed and cannot be deleted', content: new OA\JsonContent(ref: '#/components/schemas/ValidationError')),
            new OA\Response(response: 404, description: 'Not found'),
        ]
    )]
    public function destroy(Order $order): Response
    {
        $this->deleteOrder->handle($order->id);

        return response()->noContent();
    }
}
