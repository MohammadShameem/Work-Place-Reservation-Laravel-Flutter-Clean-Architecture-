<?php

namespace App\Domain\Workstation\Domain\Exceptions;

use Illuminate\Http\JsonResponse;
use RuntimeException;

/**
 * The slot can't be taken right now. Rendered as 409 (a state conflict, not
 * a validation error) with a machine-readable `code` so the app can tell
 * the temporary case (held — try again soon) from the permanent one (booked).
 */
class SlotConflictException extends RuntimeException
{
    public const HELD = 'slot_held';

    public const BOOKED = 'slot_booked';

    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly ?int $retryAfter = null,
    ) {
        parent::__construct($message);
    }

    /** Someone else is on the confirm screen for this slot; it frees up in $retryAfter seconds at most. */
    public static function held(int $retryAfter): self
    {
        return new self(
            self::HELD,
            'Another user is selecting this slot right now. It is not available at the moment, '
                .'but it may become available again shortly.',
            $retryAfter,
        );
    }

    public static function booked(): self
    {
        return new self(self::BOOKED, 'This time slot has already been booked. Please pick another one.');
    }

    public function render(): JsonResponse
    {
        $body = ['message' => $this->getMessage(), 'code' => $this->errorCode];
        $headers = [];

        if ($this->retryAfter !== null) {
            $body['retry_after'] = $this->retryAfter;
            $headers['Retry-After'] = (string) $this->retryAfter;
        }

        return response()->json($body, 409, $headers);
    }
}
