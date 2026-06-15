import 'package:flutter/material.dart';
import '../models/ta_session.dart';

class StatusBadgeWidget extends StatelessWidget {
  final SessionStatus status;
  final bool compact;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: compact ? 10 : 13,
            color: config.foregroundColor,
          ),
          SizedBox(width: compact ? 3 : 5),
          Text(
            config.label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: config.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }

  _StatusConfig _statusConfig(SessionStatus status) {
    switch (status) {
      case SessionStatus.fresh:
        return _StatusConfig(
          label: 'Fresh',
          icon: Icons.edit_outlined,
          backgroundColor: const Color(0xFFFFF3E0),
          foregroundColor: const Color(0xFFE65100),
        );
      case SessionStatus.draft:
        return _StatusConfig(
          label: 'Draft',
          icon: Icons.edit_outlined,
          backgroundColor: const Color(0xFFFFF3E0),
          foregroundColor: const Color(0xFFE65100),
        );
      case SessionStatus.submitted:
        return _StatusConfig(
          label: 'Submitted',
          icon: Icons.upload_outlined,
          backgroundColor: const Color(0xFFEDE7F6),
          foregroundColor: const Color(0xFF4527A0),
        );
    }
  }
}

class _StatusConfig {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const _StatusConfig({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}
