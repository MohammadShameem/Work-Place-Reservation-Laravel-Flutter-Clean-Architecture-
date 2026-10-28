<?php

namespace App\Domain\Shared\Infrastructure;

use App\Domain\Shared\Domain\TransactionManager;
use Illuminate\Support\Facades\DB;

class DatabaseTransactionManager implements TransactionManager
{
    public function run(callable $callback, int $attempts = 1): mixed
    {
        return DB::transaction($callback, $attempts);
    }
}
