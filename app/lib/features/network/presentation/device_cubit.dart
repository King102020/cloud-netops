import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../domain/network.dart';
import 'topology_cubit.dart' show LoadStatus;

class DeviceState extends Equatable {
  const DeviceState({
    this.status = LoadStatus.loading,
    this.device,
    this.health,
    this.failure,
  });

  final LoadStatus status;
  final NetworkNode? device;
  final DeviceHealthInfo? health;
  final AppFailure? failure;

  @override
  List<Object?> get props => [status, device, health, failure];
}

/// Screen-scope: one device's detail and health.
class DeviceCubit extends Cubit<DeviceState> {
  DeviceCubit(this._repo, this.deviceId) : super(const DeviceState());

  final NetworkRepository _repo;
  final String deviceId;

  Future<void> load() async {
    final results = await Future.wait([
      _repo.device(deviceId),
      _repo.health(deviceId),
    ]);
    if (isClosed) {
      return;
    }
    final device = results[0] as Result<NetworkNode>;
    final health = results[1] as Result<DeviceHealthInfo>;
    emit(switch ((device, health)) {
      (Ok(value: final d), Ok(value: final h)) => DeviceState(
        status: LoadStatus.ready,
        device: d,
        health: h,
      ),
      (Err(:final failure), _) || (_, Err(:final failure)) => DeviceState(
        status: LoadStatus.failure,
        failure: failure,
      ),
    });
  }
}
