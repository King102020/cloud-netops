import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/result.dart';
import '../../../core/notifications/alert_notifier.dart';
import '../domain/network.dart';

class AlertsState extends Equatable {
  const AlertsState({this.alerts = const [], this.reachable = true});

  final List<NetworkAlert> alerts;

  /// false when the last poll could not reach the API.
  final bool reachable;

  int get criticalCount => alerts.where((a) => a.critical).length;

  @override
  List<Object?> get props => [alerts, reachable];
}

/// App-scope: polls /v1/alerts and hands NEW alerts to the notifier
/// (in-app locally, FCM in the AWS phase).
class AlertsCubit extends Cubit<AlertsState> {
  AlertsCubit(
    this._repo,
    this._notifier, {
    Duration pollEvery = const Duration(seconds: 10),
  }) : _every = pollEvery,
       super(const AlertsState());

  final NetworkRepository _repo;
  final AlertNotifier _notifier;
  final Duration _every;
  final Set<String> _seen = {};
  bool _first = true;
  Timer? _timer;

  Future<void> poll() async {
    final result = await _repo.alerts();
    if (isClosed) {
      return;
    }
    switch (result) {
      case Ok(:final value):
        final fresh = value.where((a) => !_seen.contains(a.id)).toList();
        final hadAlerts = state.alerts.isNotEmpty;
        _seen
          ..clear()
          ..addAll(value.map((a) => a.id));
        // Do not notify for alerts that already existed when the app opened.
        if (!_first) {
          fresh.forEach(_notifier.notify);
          if (hadAlerts && value.isEmpty) {
            _notifier.cleared();
          }
        }
        _first = false;
        emit(AlertsState(alerts: value));
      case Err():
        emit(AlertsState(alerts: state.alerts, reachable: false));
    }
  }

  void start() {
    unawaited(poll());
    _timer?.cancel();
    _timer = Timer.periodic(_every, (_) => unawaited(poll()));
  }

  void stop() {
    _timer?.cancel();
    _seen.clear();
    _first = true;
    emit(const AlertsState());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
