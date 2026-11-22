// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/job.dart';

part 'jobs_client.g.dart';

@RestApi()
abstract class JobsClient {
  factory JobsClient(Dio dio, {String? baseUrl}) = _JobsClient;

  /// Terraform job status
  @GET('/v1/jobs/{job_id}')
  Future<Job> getJob({
    @Path('job_id') required String jobId,
  });
}
