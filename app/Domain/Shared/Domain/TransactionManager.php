<?php

namespace App\Domain\Shared\Domain;

/**
 * Lets use cases run work atomically without depending on Eloquent/the DB
 * facade directly. The Infrastructure implementation decides how a
 * transaction (and retries on deadlock) actually happen.
 */
interface TransactionManager
{
    /**
     * @template TReturn
     *
     * @param  callable(): TReturn  $callback
     * @param  int  $attempts  Retries on deadlock before giving up.
     * @return TReturn
     */
    public function run(callable $callback, int $attempts = 1): mixed;
}
