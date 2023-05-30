part of ntlm_dio;

class NtlmInterceptor extends Interceptor {
  final Credentials credentials;
  final AuthDioCreator authDioCreator;

  NtlmInterceptor(this.credentials, this.authDioCreator);

  @override
  Future onError(
    DioError e,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      if (e.response?.statusCode != HttpStatus.unauthorized) {
        return e;
      }

      final List<String>? wwwAuthHeaders =
          e.response?.headers[HttpHeaders.wwwAuthenticateHeader];

      if (e.response?.statusCode == HttpStatus.ok || wwwAuthHeaders == null)
        return e;

      if (!wwwAuthHeaders.contains('NTLM')) {
        log.warning('[part 1] no NTLM header');
        return e;
      } else {
        log.warning('[part 1] NTLM Header');
      }

      Dio authDio = authDioCreator();

      final msg1 = createType1Message(
        domain: credentials.domain,
        workstation: credentials.workstation,
      );

      // Header Setter
      Map<String, dynamic> newCookies = getHeadersCookie(e);

      var headers = e.requestOptions.headers;

      if (headers[HttpHeaders.cookieHeader] != null) {
        newCookies
          ..addAll(getHeadersCookieString(headers[HttpHeaders.cookieHeader]));
      }

      headers[HttpHeaders.cookieHeader] = newCookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');

      headers[HttpHeaders.authorizationHeader] = msg1;

      var req1 = copyRequest(e.requestOptions, e.requestOptions.data)
        ..headers = headers
        ..validateStatus = (status) =>
            status == HttpStatus.unauthorized || status == HttpStatus.ok;

      // debugReq(log, req1);

      final res1 = await authDio.fetch(req1).catchError(
        (error, stackTrace) {
          log.fine('[Req1] Error during message.', error, stackTrace);
          return Future<Response<dynamic>>.error(error, stackTrace);
        },
      );

      String? ntlmRes1 = getNtlmHeader(
        res1.headers[HttpHeaders.wwwAuthenticateHeader],
        credentials,
      );

      if (res1.statusCode == HttpStatus.ok || ntlmRes1 == null) {
        log.warning(
          '[Res1] NO AUTH HEADERS '
          '${e.response?.requestOptions.path}.',
          e,
        );
        return res1;
      }
      if (!ntlmRes1.startsWith("NTLM ")) {
        log.warning(
          '[Res1] NO NTLM HEADERS '
          '${res1.headers[HttpHeaders.wwwAuthenticateHeader]?.toList()}',
        );
        return res1;
      }

      final msg3 = getMsgType3(ntlmRes1, e, credentials);

      var req2 = copyRequest(req1, e.requestOptions.data)
        ..headers[HttpHeaders.authorizationHeader] = msg3;

      final res2 = await authDio.fetch(req2).catchError((error, stackTrace) {
        if (error is DioError) {
          log.fine(
            'Error during authentication request.\n ${error.response?.headers}\n\n',
            error,
            stackTrace,
          );
          if (error.type == DioErrorType.badResponse &&
              error.response?.statusCode == HttpStatus.unauthorized) {
            return Future<Response<dynamic>>.error(
              InvalidCredentialsException(
                e.response?.requestOptions ?? RequestOptions(),
                'invalid authentication.',
                error,
              ),
            );
          }
        }
        return Future<Response<dynamic>>.error(error, stackTrace);
      });

      return handler.resolve(res2);
    } catch (e, stackTrace) {
      String msg = 'error:${e.runtimeType}';
      if (e is DioError) {
        msg = 'code: ${e.response?.statusCode} /'
            '${debugHttpHeaders(e.response?.headers)}';
      }
      log.warning('Error while trying to authenticate.\n$msg', e, stackTrace);
      rethrow;
    } finally {
      // log.finer('Finished onError handler.');
    }
  }
}

void addNtlmInterceptor(Dio dio, Credentials credentials, CookieJar cookieJar) {
  dio.interceptors.add(InterceptorsWrapper());
}
