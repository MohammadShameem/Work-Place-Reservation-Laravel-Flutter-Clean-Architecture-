import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/countdown.dart';
import '../../../workstations/domain/entities/workstation.dart';
import '../../domain/entities/slot_hold.dart';
import '../../domain/entities/workstation_slot.dart';
import '../viewmodel/confirm_booking_view_model.dart';

/// Step 2 of booking: confirm who the booking is for. The slot is held for
/// this user while they are here; the countdown shows how long. All the
/// logic (ticking, booking, giving the slot back) is in the ViewModel.
class ConfirmBookingPage extends ConsumerStatefulWidget {
  const ConfirmBookingPage({
    super.key,
    required this.workstation,
    required this.slot,
    required this.hold,
  });

  final Workstation workstation;
  final WorkstationSlot slot;
  final SlotHold hold;

  @override
  ConsumerState<ConfirmBookingPage> createState() => _ConfirmBookingPageState();
}

class _ConfirmBookingPageState extends ConsumerState<ConfirmBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();

  late final _provider = confirmBookingViewModelProvider(
    ConfirmBookingArgs(slotId: widget.slot.id, hold: widget.hold),
  );

  @override
  void dispose() {
    _customerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final notes = _notesController.text.trim();
    ref.read(_provider.notifier).submit(
      customerName: _customerController.text.trim(),
      notes: notes.isEmpty ? null : notes,
    );
  }

  void _handle(ConfirmBookingEvent event) {
    switch (event) {
      case Finished(:final booked):
        Navigator.of(context).pop(booked);
      case HoldExpired():
        _showExpiredDialog();
    }
  }

  Future<void> _showExpiredDialog() async {
    final viewModel = ref.read(_provider.notifier);

    final tryAgain = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.timer_off_outlined),
        title: const Text('Your hold expired'),
        content: const Text(
          'This slot was released because the time ran out. '
          'You can try to hold it again, if nobody else has taken it meanwhile.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back to slots')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Try again')),
        ],
      ),
    );

    if (tryAgain == true) {
      viewModel.retryHold();
    } else {
      viewModel.leave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);

    ref.listen(_provider.select((s) => s.event), (previous, event) {
      if (event == null) return;
      ref.read(_provider.notifier).consumeEvent();
      _handle(event);
    });

    final dateFormat = DateFormat('EEEE, d MMMM');
    final timeFormat = DateFormat('h:mm a');
    final colors = Theme.of(context).colorScheme;
    // Shown exactly as the server sends them, same as the orders screens do.
    final startsAt = widget.slot.startsAt;
    final endsAt = widget.slot.endsAt;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm booking')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!state.slotLost) _CountdownBanner(remaining: state.remaining, warn: state.isRunningOut),
            if (state.errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: colors.errorContainer, borderRadius: BorderRadius.circular(8)),
                child: Text(state.errorMessage!, style: TextStyle(color: colors.onErrorContainer)),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.workstation.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    _DetailRow(icon: Icons.place_outlined, text: widget.workstation.location),
                    const SizedBox(height: 8),
                    _DetailRow(icon: Icons.event_outlined, text: dateFormat.format(startsAt)),
                    const SizedBox(height: 4),
                    _DetailRow(
                      icon: Icons.schedule,
                      text: '${timeFormat.format(startsAt)} - ${timeFormat.format(endsAt)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _customerController,
              enabled: !state.slotLost,
              decoration: const InputDecoration(labelText: 'Customer name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              enabled: !state.slotLost,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: state.isSubmitting ? null : _submit,
              child: state.isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(state.slotLost ? 'Back to time slots' : 'Confirm booking'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }
}

class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner({required this.remaining, required this.warn});

  final Duration remaining;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = warn ? colors.errorContainer : colors.secondaryContainer;
    final foreground = warn ? colors.onErrorContainer : colors.onSecondaryContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              warn ? 'Hurry — this slot is released soon' : 'This slot is held for you while you confirm',
              style: TextStyle(color: foreground),
            ),
          ),
          Text(
            formatCountdown(remaining),
            style: TextStyle(color: foreground, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }
}
