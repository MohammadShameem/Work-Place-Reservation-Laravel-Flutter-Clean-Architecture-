<?php

namespace App\Http\Controllers;

use OpenApi\Attributes as OA;

#[OA\Info(
    version: '1.0.0',
    description: "API for the workstation order system. Register or log in to get a Bearer token, "
        ."then send it as `Authorization: Bearer <token>` on every other request. ".
        "`POST /orders` accepts an `Idempotency-Key` header so a retried request from a flaky mobile ".
        "connection never creates a duplicate order.",
    title: 'Hello Laravel — Order API'
)]
#[OA\Server(url: '/', description: 'Current host')]
#[OA\SecurityScheme(
    securityScheme: 'sanctum',
    type: 'http',
    scheme: 'bearer',
    bearerFormat: 'Token',
    description: 'Token returned by /api/register or /api/login.'
)]
#[OA\Tag(name: 'Auth', description: 'Registration, login and the current token')]
#[OA\Tag(name: 'Workstations', description: 'The four physical order stations')]
#[OA\Tag(name: 'Orders', description: 'Orders and their line items')]
abstract class Controller
{
    //
}
