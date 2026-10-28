<?php

use App\Domain\Auth\Presentation\Http\Controllers\AuthController;
use App\Domain\Order\Presentation\Http\Controllers\OrderController;
use App\Domain\Workstation\Presentation\Http\Controllers\WorkstationController;
use App\Domain\Workstation\Presentation\Http\Controllers\WorkstationSlotHoldController;
use Illuminate\Support\Facades\Route;

// Public: tokens are issued here. Throttled to slow down password guessing.
Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:10,1');
Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

// Only a refresh token (ability: issue-access-token) may call this — an
// access token is rejected with 403, so a leaked access token alone can
// never be used to mint new tokens.
Route::post('/refresh', [AuthController::class, 'refresh'])
    ->middleware(['auth:sanctum', 'abilities:issue-access-token', 'throttle:10,1']);

// Protected: send "Authorization: Bearer <access_token>" from the Flutter app
// (mobile or web). Only tokens with the access-api ability are accepted here,
// so a refresh token cannot be used to call these business endpoints.
Route::middleware(['auth:sanctum', 'abilities:access-api'])->group(function () {
    Route::get('/user', [AuthController::class, 'me']);
    Route::post('/logout', [AuthController::class, 'logout']);

    Route::apiResource('workstations', WorkstationController::class);
    Route::get('workstations/{workstation}/orders', [WorkstationController::class, 'orders']);
    Route::get('workstations/{workstation}/slots', [WorkstationController::class, 'slots']);

    // Hold a slot while the user is on the confirm screen (see HoldSlotUseCase).
    Route::post('workstation-slots/{workstationSlot}/hold', [WorkstationSlotHoldController::class, 'store']);
    Route::delete('workstation-slots/{workstationSlot}/hold', [WorkstationSlotHoldController::class, 'destroy']);

    // POST (create) is retry-safe: send an "Idempotency-Key" header to avoid
    // creating a duplicate order if the response is lost on a flaky mobile connection.
    Route::apiResource('orders', OrderController::class)
        ->middlewareFor('store', 'idempotent');
    Route::patch('orders/{order}/status', [OrderController::class, 'updateStatus']);
});
