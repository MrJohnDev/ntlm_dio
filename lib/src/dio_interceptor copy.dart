// part of ntlm_dio;

// final log = new Logger("ntlm.dio_interceptor");

// /// Tried to authenticate, but (probably) got invalid credentials (username or password).
// class InvalidCredentialsException extends DioError {
//   final RequestOptions requestOptions;
//   final String message;
//   final DioError source;

//   InvalidCredentialsException(this.requestOptions, this.message, this.source)
//       : super(
//           requestOptions: requestOptions,
//           response: source.response,
//           error: source.message,
//           type: source.type,
//           stackTrace: source.stackTrace,
//         );

//   @override
//   String toString() {
//     return 'InvalidCredentialsException{message=$message,source=$source}';
//   }
// }

// class Credentials {
//   String domain;
//   String workstation;
//   String username;
//   String password;

//   Credentials({
//     this.domain = '',
//     this.workstation = '',
//     required this.username,
//     required this.password,
//   });
// }

// typedef Dio AuthDioCreator();

// class NtlmInterceptor extends Interceptor {
//   final Credentials credentials;
//   final AuthDioCreator? authDioCreator;
// //  final CookieJar cookieJar;

//   NtlmInterceptor(this.credentials, [this.authDioCreator]);

//   @override
//   Future<void> onRequest(
//     RequestOptions options,
//     RequestInterceptorHandler handler,
//   ) async {
//     log.finer(
//         "We are sending request. ${options.headers} ${options.data} ${options.path}");
//     super.onRequest(options, handler);
//   }

//   @override
//   Future<void> onResponse(
//     Response response,
//     ResponseInterceptorHandler handler,
//   ) async {
//     log.fine('Intercepted onSuccess. ${response.statusCode}}');
//     super.onResponse(response, handler);
//   }

//   @override
//   Future onError(
//     DioError e,
//     ErrorInterceptorHandler handler,
//   ) async {
//     try {
//       log.finer(
//           'Intercepted onError. ${e.response?.statusCode} for request ${e.response?.requestOptions.path}');
//       if (e.response?.statusCode != HttpStatus.unauthorized) {
//         return e;
//       }
//       log.finer('headers: ${_debugHttpHeaders(e.response?.headers)}');
//       final authHeader = e.response?.headers[HttpHeaders.wwwAuthenticateHeader];
//       log.finer('authHeader: ${authHeader.toString()}');
//       if (authHeader == null || !authHeader.contains('NTLM')) {
//         log.warning(
//             'Got a HTTP unauthorized response code, but no NTLM authentication header was set.');
//         return e;
//       }

//       // FIXME: remove username from log.
//       log.fine(
//           'Trying to authenticate request (${credentials.domain}/${credentials.username}).');

//       Dio authDio = authDioCreator == null ? Dio() : authDioCreator!();
// //      authDio.interceptors.add(CookieManager(cookieJar));
// //        authDio.cookieJar = dio.cookieJar;

//       String msg1 = createType1Message(
//         domain: credentials.domain,
//         workstation: credentials.workstation,
//       );

//       final res1 = await (authDio
//           .fetch(
//         (e.response?.requestOptions ?? RequestOptions()).copyWith(
//           validateStatus: (status) =>
//               status == HttpStatus.unauthorized || status == HttpStatus.ok,
//           headers: {HttpHeaders.authorizationHeader: msg1}..addAll(
//               e.response?.requestOptions.headers ?? {},
//             ),
//         ),
//       )
//           .catchError((error, stackTrace) {
//         log.fine('Error during type1 message.', error, stackTrace);
//         return Future.error(error, stackTrace);
//       }));
//       String? res2Authenticate =
//           res1.headers[HttpHeaders.wwwAuthenticateHeader]?.first;
//       log.finer('Received type1 message response $res2Authenticate');
//       if (res2Authenticate == null) {
//         log.warning(
//             'No Authenticate header found for response from ${e.response?.requestOptions.path}.',
//             e);
//         return e;
//       }
//       if (!res2Authenticate.startsWith("NTLM ")) {
//         log.warning(
//             'Type1 message response does not return NTLM auth header. ${res1.headers[HttpHeaders.wwwAuthenticateHeader]?.toList()}');
//         return e;
//       }
//       Type2Message msg2 = parseType2Message(res2Authenticate);

//       String msg3 = createType3Message(msg2,
//           domain: credentials.domain,
//           workstation: credentials.workstation,
//           username: credentials.username,
//           password: credentials.password);

//       final res2 = await (authDio
//           .fetch(
//         e.response!.requestOptions.copyWith(
//           headers: {HttpHeaders.authorizationHeader: msg3}..addAll(
//               e.response?.requestOptions.headers ?? {},
//             ),
//         ),
//       )
//           .catchError((error, stackTrace) {
//         if (error is DioError) {
//           log.fine(
//               'Error during authentication request. ${error.response?.headers}',
//               error,
//               stackTrace);
//           if (error.type == DioErrorType.badResponse &&
//               error.response?.statusCode == HttpStatus.unauthorized) {
//             return Future<Response<dynamic>>.error(InvalidCredentialsException(
//               e.response?.requestOptions ?? RequestOptions(),
//               'invalid authentication.',
//               error,
//             ));
//           }
//         }
//         return Future<Response<dynamic>>.error(error, stackTrace);
//       }));
//       log.finer('Received type3 message response. ${res2.statusCode}.');

//       return res2;
//     } catch (e, stackTrace) {
//       String msg = 'error:${e.runtimeType}';
//       if (e is DioError) {
//         msg =
//             'code: ${e.response?.statusCode} / ${_debugHttpHeaders(e.response?.headers)}';
//       }
//       log.warning('Error while trying to authenticate. $msg', e, stackTrace);
//       rethrow;
//     } finally {
//       log.finer('Finished onError handler.');
//     }
//   }
// }

// void addNtlmInterceptor(Dio dio, Credentials credentials, CookieJar cookieJar) {
//   dio.interceptors.add(InterceptorsWrapper());
// }

// String _debugHttpHeaders(Headers? headers) {
//   final ret = Map<String, List<String>>();
//   headers?.forEach((key, values) {
//     ret[key] = values;
//   });
//   return ret.toString();
// }
