import 'package:flutter/material.dart';

import '../../domain/entities/order_status.dart';
import 'order_status_label.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      OrderStatus.pending => (Colors.orange.shade800, Icons.schedule),
      OrderStatus.inProgress => (Colors.blue.shade800, Icons.autorenew),
      OrderStatus.completed => (Colors.green.shade800, Icons.check_circle),
      OrderStatus.cancelled => (Colors.red.shade800, Icons.cancel),
    };

    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(status.label),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      visualDensity: VisualDensity.compact,
    );
  }
}
