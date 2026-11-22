import 'package:flutter/material.dart';

import '../../features/network/domain/network.dart';

/// How new alerts reach the user. Local flavor: an in-app message. The AWS
/// flavor will add Firebase Cloud Messaging (STANDARDS §6, docs/local-gaps.md).
abstract interface class AlertNotifier {
  void notify(NetworkAlert alert);
  void cleared();
}

/// Mock notifier for the local flavor: shows a SnackBar through the app's
/// ScaffoldMessenger, so alerts appear on every screen and platform.
class InAppAlertNotifier implements AlertNotifier {
  InAppAlertNotifier(
    this.messengerKey, {
    required this.message,
    required this.clearedMessage,
  });

  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final String Function(NetworkAlert alert) message;
  final String Function() clearedMessage;

  @override
  void notify(NetworkAlert alert) =>
      _show(message(alert), critical: alert.critical);

  @override
  void cleared() => _show(clearedMessage(), critical: false);

  void _show(String text, {required bool critical}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) {
      return;
    }
    final scheme = Theme.of(messenger.context).colorScheme;
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: critical ? scheme.errorContainer : null,
        showCloseIcon: true,
        closeIconColor: critical ? scheme.onErrorContainer : null,
      ),
    );
  }
}

/// Records alerts instead of showing them (tests).
class RecordingAlertNotifier implements AlertNotifier {
  final List<NetworkAlert> notified = [];
  int clearedCount = 0;

  @override
  void notify(NetworkAlert alert) => notified.add(alert);

  @override
  void cleared() => clearedCount++;
}
