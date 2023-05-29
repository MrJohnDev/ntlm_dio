part of ntlm_dio;

class NtlmInterceptor extends Interceptor {
  final Credentials credentials;
  final AuthDioCreator authDioCreator;

  final CookieManager? cookieManager;

  NtlmInterceptor(this.credentials, this.authDioCreator, [this.cookieManager]);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    log.finer(
        "We are sending request. ${options.headers} ${options.data} ${options.path}");
    super.onRequest(options, handler);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    log.fine('Intercepted onSuccess. ${response.statusCode}}');
    super.onResponse(response, handler);
  }

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
      }

      Dio authDio = authDioCreator();
      if (cookieManager != null) {
        authDio.interceptors.add(cookieManager!);
      }

      final msg1 = createType1Message(
        domain: credentials.domain,
        workstation: credentials.workstation,
      );

      // Header Setter
      Map<String, dynamic> newCookies = getHeadersCookie(e);

      var headers = e.requestOptions.headers;

      if (headers[HttpHeaders.cookieHeader] != null) {
        newCookies..addAll(headers[HttpHeaders.cookieHeader]);
      }

      headers[HttpHeaders.authorizationHeader] = msg1;
      headers[HttpHeaders.cookieHeader] = newCookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');

      // log.fine('[Res1] headers1 = ${headers.runtimeType}', headers);

      // End Header Setter

      var req1 = copyRequest(
        e.requestOptions,
        e.requestOptions.data,
      )
        ..headers = headers
        ..validateStatus = (status) =>
            status == HttpStatus.unauthorized || status == HttpStatus.ok;

      debugReq(log, req1);

      // 1. Send the initial request
      final res1 = await authDio.fetch(req1).catchError(
        (error, stackTrace) {
          log.fine('[Req1] Error during message.', error, stackTrace);
          return Future<Response<dynamic>>.error(error, stackTrace);
        },
      );

      log.fine('[Res1] headers = ', res1.headers);

      final List<String>? res1WwwAuthHeaders =
          res1.headers[HttpHeaders.wwwAuthenticateHeader];

      // log.fine('[Res1] res1WwwAuthHeaders = ', res1WwwAuthHeaders);

      // Servers may support multiple authentication methods so we need to find
      // the correct one
      String? ntlmRes1;
      if (res1WwwAuthHeaders != null) {
        for (var wwwAuthHeader in res1WwwAuthHeaders) {
          // log.fine('[Res1] wwwAuthHeader = ', wwwAuthHeader);
          var trimmedPart = wwwAuthHeader.trim();
          if (trimmedPart.startsWith('${credentials.headerPrefix} ')) {
            ntlmRes1 = trimmedPart;
            break;
          }
        }
      }

      // log.fine('[Res1] ntlmRes1 = ', ntlmRes1);

      // If the initial request was successful or this isn't an NTLM request,
      // return the initial response
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

      Type2Message msg2 = parseType2Message(
        ntlmRes1,
        headerPrefix: credentials.headerPrefix,
      );

      // 3. Send the authenticated request
      final msg3 = createType3Message(
        msg2,
        domain: credentials.domain,
        workstation: credentials.workstation,
        username: credentials.username,
        password: credentials.password,
        headerPrefix: credentials.headerPrefix,
      );

      // log.fine('[Type3] NTLM = ', msg3);

      var req2 = copyRequest(
        req1,
        e.requestOptions.data,
      )..headers[HttpHeaders.authorizationHeader] =
          msg3; // HttpHeaders.authorizationHeader

      debugReq(log, req2);

      final res2 = await authDio.fetch(req2).catchError((error, stackTrace) {
        if (error is DioError) {
          log.fine(
            'Error during authentication request.\n ${error.response?.headers}\n\n',
            error,
            stackTrace,
          );
          if (error.type == DioErrorType.badResponse &&
              error.response?.statusCode == HttpStatus.unauthorized) {
            return Future<Response<dynamic>>.error(InvalidCredentialsException(
              e.response?.requestOptions ?? RequestOptions(),
              'invalid authentication.',
              error,
            ));
          }
        }
        return Future<Response<dynamic>>.error(error, stackTrace);
      });
      log.finer(
          'Received type3 message response. ${res2.statusCode}.\n${res2.toString()}');

      return res2;
    } catch (e, stackTrace) {
      String msg = 'error:${e.runtimeType}';
      if (e is DioError) {
        msg = 'code: ${e.response?.statusCode} /'
            '${debugHttpHeaders(e.response?.headers)}';
      }
      log.warning('Error while trying to authenticate.\n$msg', e, stackTrace);
      rethrow;
    } finally {
      log.finer('Finished onError handler.');
    }
  }
}

void addNtlmInterceptor(Dio dio, Credentials credentials, CookieJar cookieJar) {
  dio.interceptors.add(InterceptorsWrapper());
}
