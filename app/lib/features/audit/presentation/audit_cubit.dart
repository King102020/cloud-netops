import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/result.dart';
import '../../network/presentation/topology_cubit.dart' show LoadStatus;
import '../domain/audit.dart';

class AuditState extends Equatable {
  const AuditState({
    this.status = LoadStatus.loading,
    this.items = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.failure,
  });

  final LoadStatus status;
  final List<AuditEntry> items;
  final String? nextCursor;
  final bool loadingMore;
  final AppFailure? failure;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [status, items, nextCursor, loadingMore, failure];
}

/// Screen-scope: audit log with cursor pagination.
class AuditCubit extends Cubit<AuditState> {
  AuditCubit(this._repo) : super(const AuditState());

  final AuditRepository _repo;

  Future<void> load() async {
    final result = await _repo.page();
    if (isClosed) {
      return;
    }
    emit(switch (result) {
      Ok(:final value) => AuditState(
        status: LoadStatus.ready,
        items: value.items,
        nextCursor: value.nextCursor,
      ),
      Err(:final failure) => AuditState(
        status: LoadStatus.failure,
        failure: failure,
      ),
    });
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) {
      return;
    }
    emit(
      AuditState(
        status: state.status,
        items: state.items,
        nextCursor: state.nextCursor,
        loadingMore: true,
      ),
    );
    final result = await _repo.page(cursor: state.nextCursor);
    if (isClosed) {
      return;
    }
    emit(switch (result) {
      Ok(:final value) => AuditState(
        status: LoadStatus.ready,
        items: [...state.items, ...value.items],
        nextCursor: value.nextCursor,
      ),
      Err(:final failure) => AuditState(
        status: LoadStatus.ready,
        items: state.items,
        nextCursor: state.nextCursor,
        failure: failure,
      ),
    });
  }
}
