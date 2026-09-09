import 'package:flutter/material.dart';

abstract final class AppSemantics {
  static const incoming = Color(0xFF35D07F);
  static const outgoing = Color(0xFFFF647C);
  static const warning = Color(0xFFFFC857);
  static const info = Color(0xFF58A6FF);
  static const successSoft = Color(0xFF123628);
  static const dangerSoft = Color(0xFF421C25);
  static const warningSoft = Color(0xFF3E3218);
  static const infoSoft = Color(0xFF153454);

  static Color statusColor(String value) {
    switch (value.toLowerCase()) {
      case 'paid':
      case 'completed':
      case 'settled':
      case 'success':
        return incoming;
      case 'overdue':
      case 'failed':
      case 'error':
      case 'deleted':
        return outgoing;
      case 'in_progress':
      case 'pending':
      case 'warning':
        return warning;
      default:
        return info;
    }
  }

  static Color priorityColor(String value) {
    switch (value.toLowerCase()) {
      case 'high': return outgoing;
      case 'medium': return warning;
      case 'low': return incoming;
      default: return info;
    }
  }

  static Color amountColor({required bool incomingMoney, bool settled = false}) {
    if (settled) return Colors.grey;
    return incomingMoney ? incoming : outgoing;
  }

  static Color soft(Color color) => color.withValues(alpha: .13);
}
