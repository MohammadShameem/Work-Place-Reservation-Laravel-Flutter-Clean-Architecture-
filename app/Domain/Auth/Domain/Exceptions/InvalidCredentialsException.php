<?php

namespace App\Domain\Auth\Domain\Exceptions;

use RuntimeException;

/**
 * The email/password pair didn't check out. Deliberately carries no HTTP
 * knowledge — the controller decides that a 422 with this message is the
 * right way to tell the caller.
 */
class InvalidCredentialsException extends RuntimeException
{
    public function __construct()
    {
        parent::__construct('The provided credentials are incorrect.');
    }
}
