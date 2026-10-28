<?php

namespace App\Providers;

use App\Domain\Auth\Domain\Repositories\UserRepository;
use App\Domain\Auth\Infrastructure\Persistence\EloquentUserRepository;
use App\Domain\Idempotency\Domain\Repositories\IdempotencyKeyRepository;
use App\Domain\Idempotency\Infrastructure\Persistence\EloquentIdempotencyKeyRepository;
use App\Domain\Order\Application\UseCases\BookSlotUseCase;
use App\Domain\Order\Domain\Contracts\SlotBooking;
use App\Domain\Order\Domain\Repositories\OrderRepository;
use App\Domain\Order\Infrastructure\Persistence\EloquentOrderRepository;
use App\Domain\Shared\Domain\TransactionManager;
use App\Domain\Shared\Infrastructure\DatabaseTransactionManager;
use App\Domain\Workstation\Application\UseCases\HoldSlotUseCase;
use App\Domain\Workstation\Domain\Contracts\SlotHolds;
use App\Domain\Workstation\Domain\Repositories\WorkstationRepository;
use App\Domain\Workstation\Domain\Repositories\WorkstationSlotHoldRepository;
use App\Domain\Workstation\Domain\Repositories\WorkstationSlotRepository;
use App\Domain\Workstation\Infrastructure\Persistence\EloquentWorkstationRepository;
use App\Domain\Workstation\Infrastructure\Persistence\EloquentWorkstationSlotHoldRepository;
use App\Domain\Workstation\Infrastructure\Persistence\EloquentWorkstationSlotRepository;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     *
     * This is the only place that knows which class backs each port. Every
     * Application-layer use case depends only on the interfaces bound here —
     * never on an Eloquent model or the DB facade directly — so swapping an
     * implementation (a Redis-backed hold store, a fake in a test) never
     * touches a use case or controller.
     */
    public function register(): void
    {
        $this->app->bind(TransactionManager::class, DatabaseTransactionManager::class);

        $this->app->bind(UserRepository::class, EloquentUserRepository::class);
        $this->app->bind(WorkstationRepository::class, EloquentWorkstationRepository::class);
        $this->app->bind(WorkstationSlotRepository::class, EloquentWorkstationSlotRepository::class);
        $this->app->bind(WorkstationSlotHoldRepository::class, EloquentWorkstationSlotHoldRepository::class);
        $this->app->bind(OrderRepository::class, EloquentOrderRepository::class);
        $this->app->bind(IdempotencyKeyRepository::class, EloquentIdempotencyKeyRepository::class);

        // bind() (not singleton()) so config changes — e.g. in a test —
        // apply on the next resolution; the use case holds no state of its own.
        $this->app->bind(SlotHolds::class, fn ($app) => new HoldSlotUseCase(
            $app->make(WorkstationSlotRepository::class),
            $app->make(WorkstationSlotHoldRepository::class),
            $app->make(OrderRepository::class),
            $app->make(TransactionManager::class),
            holdTtlSeconds: (int) config('booking.hold_ttl_seconds'),
            holdMaxSeconds: (int) config('booking.hold_max_seconds'),
        ));

        // BookSlotUseCase itself needs a SlotHolds; the container supplies
        // whichever one is bound above.
        $this->app->bind(SlotBooking::class, BookSlotUseCase::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
