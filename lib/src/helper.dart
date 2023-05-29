import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:ntlm/ntlm.dart';

final log = new Logger("ntlm.dio_interceptor");

typedef Dio AuthDioCreator();

/// Tried to authenticate, but (probably) got invalid credentials (username or password).
class InvalidCredentialsException extends DioError {
  final RequestOptions requestOptions;
  final String message;
  final DioError source;

  InvalidCredentialsException(this.requestOptions, this.message, this.source)
      : super(
          requestOptions: requestOptions,
          response: source.response,
          error: source.message,
          type: source.type,
          stackTrace: source.stackTrace,
        );

  @override
  String toString() {
    return 'InvalidCredentialsException{message=$message,source=$source}';
  }
}

class Credentials {
  String domain;
  String workstation;
  String username;
  String password;

  /// The prefix for 'www-authenticate'/'authorization' headers (usually
  /// either [kHeaderPrefixNTLM] or [kHeaderPrefixNegotiate])
  String headerPrefix;

  Credentials({
    this.domain = '',
    this.workstation = '',
    required this.username,
    required this.password,
    this.headerPrefix = kHeaderPrefixNTLM,
  });
}

void debugReq(log, RequestOptions req) {
  log.fine(
    'data = ${req.data}\n'
    'path = ${req.path}\n'
    'extra = ${req.extra}\n'
    'contentType = ${req.contentType}\n'
    'followRedirects = ${req.followRedirects}\n'
    'headers = ${debugHttpHeaders2(req.headers)}\n'
    'method = ${req.method}\n'
    'queryParameters = ${req.queryParameters}\n'
    'validateStatus = ${req.validateStatus}\n',
  );
}

String debugHttpHeaders2(Map<String, dynamic>? headers) {
  String fullString = '';
  headers?.forEach((key, values) {
    fullString += '$key: $values\n\t';
  });
  return fullString;
}

String debugHttpHeaders(Headers? headers) {
  final ret = Map<String, List<String>>();
  headers?.forEach((key, values) {
    ret[key] = values;
  });
  return ret.toString();
}

RequestOptions copyRequest(RequestOptions request, dynamic body) =>
    request.copyWith(data: body);

Map<String, dynamic> getHeadersCookie(DioError e) {
  Map<String, dynamic> headersMap = {};

  List<String>? cookiesList = e.response?.headers[HttpHeaders.setCookieHeader];

  cookiesList?.forEach((String? cookies) {
    cookies?.split('; ').forEach((cookie) {
      // log.finer('cookie: ${cookie.toString()}');
      List<String> parts = cookie.split('=');
      if (parts.length == 2) {
        String name = parts[0].trim();
        String value = parts[1].trim();
        headersMap[name] = value;
      }
    });
  });
  return headersMap;
}
