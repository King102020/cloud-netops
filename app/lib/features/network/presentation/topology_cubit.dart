import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/network.dart';

enum LoadStatus { loading, ready, failure }

class TopologyState extends Equatable {
  const TopologyState({
    this.status = LoadStatus.loading,
    this.snapshot,
    this.failure,
    this.busyLinks = const {},
    this.actionFailure,
    this.updatedAt,
  });

  final LoadStatus status;
  final NetworkSnapshot? snapshot;
  final AppFailure? failure;
  final Set<String> busyLinks;

  /// Failure of the last link change (shown once as a message).
  final AppFailure? actionFailure;
  final DateTime? updatedAt;

  TopologyState copyWith({
    LoadStatus? status,
    NetworkSnapshot? snapshot,
    AppFailure? failure,
    Set<String>? busyLinks,
    AppFailure? actionFailure,
    bool clearActionFailure = false,
    DateTime? updatedAt,
  }) => TopologyState(
    status: status ?? this.status,
    snapshot: snapshot ?? this.snapshot,
    failure: failure,
    busyLinks: busyLinks ?? this.busyLinks,
    actionFailure: clearActionFailure
        ? null
        : actionFailure ?? this.actionFailure,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  List<Object?> get props => [
    status,
    snapshot,
    failure,
    busyLinks,
    actionFailure,
    updatedAt,
  ];
}

/// Screen-scope: the live topology, refreshed on a timer while visible.
class TopologyCubit extends Cubit<TopologyState> {
  TopologyCubit(
    this._repo, {
    Duration refreshEvery = const Duration(seconds: 5),
    DateTime Function()? clock,
  }) : _every = refreshEvery,
       _now = clock ?? DateTime.now,
       super(const TopologyState());

  final NetworkRepository _repo;
  final Duration _every;
  final DateTime Function() _now;
  Timer? _timer;

  Future<void> load() async {
    if (state.snapshot == null) {
      emit(state.copyWith(status: LoadStatus.loading));
    }
    final result = await _repo.topology();
    if (isClosed) {
      return;
    }
    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        status: LoadStatus.ready,
        snapshot: value,
        updatedAt: _now(),
      ),
      // Keep showing the last good snapshot if a background refresh fails.
      Err(:final failure) =>
        state.snapshot == null
            ? state.copyWith(status: LoadStatus.failure, failure: failure)
            : state.copyWith(status: LoadStatus.ready),
    });
  }

  void startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_every, (_) => unawaited(load()));
  }

  void stopPolling() => _timer?.cancel();

  Future<void> setLink(String id, {required bool up}) async {
    emit(
      state.copyWith(
        busyLinks: {...state.busyLinks, id},
        clearActionFailure: true,
      ),
    );
    final result = await _repo.setLink(id, up: up);
    if (isClosed) {
      return;
    }
    final busy = {...state.busyLinks}..remove(id);
    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        busyLinks: busy,
        snapshot: state.snapshot?.withLink(value),
        updatedAt: _now(),
      ),
      Err(:final failure) => state.copyWith(
        busyLinks: busy,
        actionFailure: failure,
      ),
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
