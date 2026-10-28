<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('workstation_slot_holds', function (Blueprint $table) {
            $table->id();
            // UNIQUE: a slot can have at most one hold row at a time. The
            // service already guarantees this under a row lock; the index is
            // the database-level safety net if that code ever has a bug.
            $table->foreignId('workstation_slot_id')->unique()->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->dateTime('expires_at')->index();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('workstation_slot_holds');
    }
};
