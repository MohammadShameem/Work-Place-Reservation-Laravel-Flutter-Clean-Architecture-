import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../workstations/domain/entities/workstation.dart';
import '../../domain/entities/slot_hold.dart';
import '../../domain/entities/workstation_slot.dart';
import '../viewmodel/slot_picker_view_model.dart';
import '../widgets/slot_grid.dart';
import 'confirm_booking_page.dart';

/// Step 1 of booking: pick a day, then an available time slot.
///
/// This page only draws what the ViewModel says and forwards taps to it. The
/// polling, the hold and the explanations all live in [SlotPickerViewModel].
class SlotPickerPage extends ConsumerStatefulWidget {
  const SlotPickerPage({super.key, required this.workstation});

  final Workstation workstation;

  @override
  ConsumerState<SlotPickerPage> createState() => _SlotPickerPageState();
}

class _SlotPickerPageState extends ConsumerState<SlotPickerPage> with WidgetsBindingObserver {
  static const _daysAhead = 3; // matches WorkstationSlotSeeder on the backend

  late final _provider = slotPickerViewModelProvider(widget.workstation.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A platform event the ViewModel can't see, so we pass it on.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(_provider.notifier).setForeground(state == AppLifecycleState.resumed);
  }

  void _handle(SlotPickerEvent event) {
    switch (event) {
      case ShowSlotMessage(:final text, :final kind):
        _showMessage(text, kind);
      case OpenConfirm(:final slot, :final hold):
        _openConfirm(slot, hold);
    }
  }

  void _showMessage(String text, SlotMessageKind kind) {
    final icon = switch (kind) {
      SlotMessageKind.held => Icons.hourglass_top,
      SlotMessageKind.booked => Icons.block,
      SlotMessageKind.offline => Icons.cloud_off,
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
  }

  Future<void> _openConfirm(WorkstationSlot slot, SlotHold hold) async {
    final viewModel = ref.read(_provider.notifier);

    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConfirmBookingPage(workstation: widget.workstation, slot: slot, hold: hold),
      ),
    );

    viewModel.confirmClosed(booked: booked == true);
    if (!mounted) return;
    if (booked == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final viewModel = ref.read(_provider.notifier);

    ref.listen(_provider.select((s) => s.event), (previous, event) {
      if (event == null) return;
      viewModel.consumeEvent();
      _handle(event);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workstation.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _DaySelector(
            selectedDay: state.selectedDay,
            daysAhead: _daysAhead,
            onSelect: viewModel.selectDay,
          ),
        ),
      ),
      body: _body(state, viewModel),
    );
  }

  Widget _body(SlotPickerState state, SlotPickerViewModel viewModel) {
    final slots = state.slots;

    if (slots == null) {
      if (state.isLoading) return const LoadingView();
      return ErrorView(
        message: state.error?.message ?? 'Could not load time slots.',
        onRetry: viewModel.retry,
      );
    }

    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (state.refreshFailing)
          Container(
            width: double.infinity,
            color: colors.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              "Can't refresh right now. Showing the last known slots — retrying…",
              style: TextStyle(color: colors.onErrorContainer, fontSize: 12),
            ),
          ),
        const _Legend(),
        Expanded(
          child: slots.isEmpty
              ? const Center(child: Text('No time slots for this day.'))
              : SlotGrid(slots: slots, onSlotTap: viewModel.onSlotTap),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          item(colors.primaryContainer, 'Available'),
          item(colors.tertiaryContainer, 'Being selected by someone'),
          item(colors.surfaceContainerHighest, 'Booked'),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.selectedDay, required this.daysAhead, required this.onSelect});

  final DateTime selectedDay;
  final int daysAhead;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: daysAhead,
        itemBuilder: (context, index) {
          final day = DateTime(today.year, today.month, today.day + index);
          final isSelected =
              day.year == selectedDay.year && day.month == selectedDay.month && day.day == selectedDay.day;
          final label = index == 0 ? 'Today' : DateFormat('EEE d MMM').format(day);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onSelect(day),
            ),
          );
        },
      ),
    );
  }
}
