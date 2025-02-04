import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ntlm_dio/src/helper.dart';
import 'dart:io' show Cookie, File, HttpStatus, Platform;
import 'package:path/path.dart' as p;
import "package:system_info/system_info.dart";
import 'package:ntlm_dio/ntlm_dio.dart';
import './_test_utils.dart';

class NtlmTestConfig {
  String url;
  String domain;
  String username;
  String password;
  Map<String, String>? headers;

  static const ENV_NAME = 'NTLM_TEST_CONFIG';
  static const EXAMPLE_JSON =
      '{"url": "", "domain": "", "username": "", "password": ""}';

  Credentials get credentials =>
      Credentials(username: username, password: password, domain: domain);

  factory NtlmTestConfig.fromEnvironment() {
    final jsonConfig = Platform.environment[ENV_NAME];
    if (jsonConfig == null) {
      throw StateError(
          'Expected environment variable $ENV_NAME - for example: $EXAMPLE_JSON');
    }
    return NtlmTestConfig.fromJsonString(jsonConfig);
  }

  factory NtlmTestConfig.fromFile() {
    final name = '.ntlm_dio.test.config.json';
    final paths = [name, p.join(SysInfo.userDirectory, name)];
    for (final path in paths) {
      final f = File(path);
      if (f.existsSync()) {
        return NtlmTestConfig.fromJsonString(f.readAsStringSync());
      }
    }
    throw StateError(
        'Expected to find config in one of the following paths: $paths');
  }

  factory NtlmTestConfig.fromJsonString(String jsonString) {
    final jsonValue = json.decode(jsonString) as Map;
    return NtlmTestConfig.fromJson(jsonValue.cast<String, dynamic>());
  }

  factory NtlmTestConfig.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headers;
    final headersMap = json['headers'];
    if (headersMap is Map) {
      headers = headersMap.cast<String, String>();
    }
    return NtlmTestConfig(
      url: json['url'],
      domain: json['domain'] ?? '',
      username: json['username'],
      password: json['password'],
      headers: headers,
    );
  }

  NtlmTestConfig({
    required this.url,
    required this.domain,
    required this.username,
    required this.password,
    required this.headers,
  });
}

void main() {
  final config = NtlmTestConfig.fromFile();
  initTestLogging();
  test('test ntlm auth', () async {
    final baseOptions = BaseOptions(headers: config.headers);

    Dio dio = Dio(baseOptions);

    var cookieJar = CookieJar();
    var cookieManager = CookieManager(cookieJar);

    dio.interceptors.add(cookieManager);
    // dio.interceptors.add(LogInterceptor());
    dio.interceptors.add(NtlmInterceptor(
      config.credentials,
      () => dio,
    ));

    final response = await dio.get(config.url);
    log.fine('response', response.data.toString());
    expect(response.statusCode, HttpStatus.ok);

    final response2 = await dio.get(config.url);
    log.fine('response2', response2.data.toString());
    expect(response2.statusCode, HttpStatus.ok);

    final response3 = await dio.post(
      'https://sp.krastsvetmet.ru/_vti_bin/lk/serviceLK.svc/SecondAuth',
      data: {"Type": 1, "Value": config.credentials.password},
    );

    log.fine('response3', response3.data.toString());
    expect(response3.statusCode, HttpStatus.ok);

    Cookie cookie = Cookie('TokenUser', response3.data['token']['Token']);
    cookieJar.saveFromResponse(
      Uri.parse('https://sp.krastsvetmet.ru'),
      [cookie],
    );

    final response4 = await dio.get(
        'https://sp.krastsvetmet.ru/_vti_bin/lk/serviceLK.svc/GetPaysheetStruct?date=2023-03-01');
    log.fine('response4', response4.data.toString());
    expect(response4.statusCode, HttpStatus.ok);
  });
}
