<?php

declare(strict_types=1);

namespace App\Domain\Idempotency\Presentation\Http\Middleware;

use App\Domain\Idempotency\Domain\Repositories\IdempotencyKeyRepository;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Throwable;

/**
 * Lets a mobile client safely retry a request (e.g. after a dropped
 * connection) without creating a duplicate order.
 *
 * The client sends a unique "Idempotency-Key" header per logical attempt.
 * The first request runs normally; any retry with the same key+user gets
 * back the exact same response instead of being processed again. Requests
 * that omit the header are not affected.
 */
class EnsureIdempotency
{
    public function __construct(private readonly IdempotencyKeyRepository $keys)
    {
    }

    public function handle(Request $request, Closure $next): Response
    {
        $key = $request->header('Idempotency-Key');

        if (! $key) {
            return $next($request);
        }

        $userId = $request->user()?->id;

        if ($existing = $this->keys->find($userId, $key)) {
            if ($existing->response_status === null) {
                return response()->json([
                    'message' => 'A request with this Idempotency-Key is still being processed.',
                ], 409);
            }

            return response()->json($existing->response_body, $existing->response_status)
                ->header('Idempotency-Replayed', 'true');
        }

        $record = $this->keys->claim($userId, $key);

        if (! $record) {
            return response()->json([
                'message' => 'A request with this Idempotency-Key is still being processed.',
            ], 409);
        }

        try {
            $response = $next($request);
        } catch (Throwable $e) {
            $this->keys->delete($record);

            throw $e;
        }

        if ($response->getStatusCode() >= 500 || $response->getStatusCode() === 409) {
            // Neither is a decision worth remembering, so a retry with the
            // same key is processed afresh. A 5xx is a server hiccup. A 409
            // is a state conflict that can clear on its own — e.g. "slot
            // held by someone else" stops being true when that hold lapses.
            $this->keys->delete($record);
        } else {
            $this->keys->markCompleted($record, $response->getStatusCode(), json_decode($response->getContent(), true));
        }

        return $response;
    }
}
