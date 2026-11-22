// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Token _$TokenFromJson(Map<String, dynamic> json) => Token(
  accessToken: json['access_token'] as String,
  expiresIn: (json['expires_in'] as num).toInt(),
  role: Role.fromJson(json['role'] as String),
  tokenType: json['token_type'] as String? ?? 'bearer',
);

Map<String, dynamic> _$TokenToJson(Token instance) => <String, dynamic>{
  'access_token': instance.accessToken,
  'token_type': instance.tokenType,
  'expires_in': instance.expiresIn,
  'role': instance.role,
};
