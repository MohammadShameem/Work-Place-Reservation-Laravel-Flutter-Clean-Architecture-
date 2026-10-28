<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Slot Holds
    |--------------------------------------------------------------------------
    |
    | While a user is on the "confirm booking" screen their slot is held so
    | nobody else starts filling in a form for it. A hold lasts
    | hold_ttl_seconds and can be renewed, but never beyond hold_max_seconds
    | in total, so nobody can sit on a slot forever. Values are in seconds.
    |
    */

    'hold_ttl_seconds' => (int) env('SLOT_HOLD_TTL', 180),

    'hold_max_seconds' => (int) env('SLOT_HOLD_MAX', 600),

];
