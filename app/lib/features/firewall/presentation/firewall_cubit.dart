import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../network/presentation/topology_cubit.dart' show LoadStatus;
import '../domain/firewall.dart';

class FirewallState extends Equatable {
  const FirewallState({
    this.status = LoadStatus.loading,
    this.rules = const [],
    this.failure,
    this.busy = const {},
    this.actionFailure,
  });

  final LoadStatus status;
  final List<FirewallRuleItem> rules;
  final AppFailure? failure;
  final Set<String> busy;
  final AppFailure? actionFailure;

  bool get hasPending => rules.any((r) => r.status == ChangeState.pending);

  FirewallState copyWith({
    LoadStatus? status,
    List<FirewallRuleItem>? rules,
    AppFailure? failure,
    Set<String>? busy,
    AppFailure? actionFailure,
  }) => FirewallState(
    status: status ?? this.status,
    rules: rules ?? this.rules,
    failure: failure,
    busy: busy ?? this.busy,
    actionFailure: actionFailure,
  );

  @override
  List<Object?> get props => [status, rules, failure, busy, actionFailure];
}

/// Screen-scope: API-managed firewall rules. While any rule is still being
/// applied by Terraform it re-checks every few seconds.
class FirewallCubit extends Cubit<FirewallState> {
  FirewallCubit(
    this._repo, {
    Duration pendingPoll = const Duration(seconds: 3),
    Uuid? uuid,
  }) : _pendingPoll = pendingPoll,
       _uuid = uuid ?? const Uuid(),
       super(const FirewallState());

  final FirewallRepository _repo;
  final Duration _pendingPoll;
  final Uuid _uuid;
  Timer? _timer;

  /// Idempotency key for the submission being edited. Reused on retry,
  /// replaced after a success (STANDARDS §5).
  String _submissionKey = '';

  String newSubmissionKey() => _submissionKey = _uuid.v4();

  Future<void> load() async {
    final result = await _repo.list();
    if (isClosed) {
      return;
    }
    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        status: LoadStatus.ready,
        rules: value,
      ),
      Err(:final failure) =>
        state.rules.isEmpty
            ? state.copyWith(status: LoadStatus.failure, failure: failure)
            : state.copyWith(),
    });
    _schedulePendingCheck();
  }

  void _schedulePendingCheck() {
    _timer?.cancel();
    if (state.hasPending && !isClosed) {
      _timer = Timer(_pendingPoll, () => unawaited(load()));
    }
  }

  /// Returns null on success, or the failure to show in the form.
  Future<AppFailure?> create(NewFirewallRule rule) async {
    if (_submissionKey.isEmpty) {
      newSubmissionKey();
    }
    final result = await _repo.create(rule, idempotencyKey: _submissionKey);
    if (isClosed) {
      return null;
    }
    switch (result) {
      case Ok(:final value):
        _submissionKey = '';
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            rules: [...state.rules, value],
          ),
        );
        _schedulePendingCheck();
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  Future<void> toggle(String id, {required bool enabled}) =>
      _mutate(id, () async {
        final result = await _repo.setEnabled(id, enabled: enabled);
        return switch (result) {
          Ok(:final value) => Ok([
            for (final r in state.rules) r.id == id ? value : r,
          ]),
          Err(:final failure) => Err(failure),
        };
      });

  Future<void> delete(String id) => _mutate(id, () async {
    final result = await _repo.delete(id);
    return switch (result) {
      Ok() => Ok([
        for (final r in state.rules)
          if (r.id != id) r,
      ]),
      Err(:final failure) => Err(failure),
    };
  });

  Future<void> _mutate(
    String id,
    Future<Result<List<FirewallRuleItem>>> Function() op,
  ) async {
    emit(state.copyWith(busy: {...state.busy, id}));
    final result = await op();
    if (isClosed) {
      return;
    }
    final busy = {...state.busy}..remove(id);
    emit(switch (result) {
      Ok(:final value) => state.copyWith(rules: value, busy: busy),
      Err(:final failure) => state.copyWith(busy: busy, actionFailure: failure),
    });
    _schedulePendingCheck();
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
