import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:html' as html;
import 'dart:convert';

import './token.dart';


class OAuth2 {
  Token? token;
  final GlobalKey<NavigatorState> navigatorKey;
  String clientID, clientSecret, redirectURL, baseURL;
  String authorizationEndpoint, tokenEndpoint;
  String codeVerifier = '', scope = '', state = '';
  bool urlEncoded;

  OAuth2({
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    required this.clientID,
    required this.clientSecret,
    required this.redirectURL,
    required this.navigatorKey,
    this.scope = '',
    this.baseURL = '',
    this.urlEncoded = true,
  });

  /// Getters
  bool get isAuthed {
    loadFromStorage();
    if (token!.isValid()) {
      return true;
    }
    return false;
  }

  Map<String, String> get authHeaders {
    loadFromStorage();
    return <String, String>{
      'Authorization': 'Bearer $token',
    };
  }

  String get authorizationURL {
    return '$baseURL$authorizationEndpoint';
  }

  String get tokenURL {
    return '$baseURL$tokenEndpoint';
  }

  /// Methods
  String LoginRedirectUrl({String? scope_ = null}) {
    state = _encodeState();

    codeVerifier = _generateCodeVerifier();
    html.window.sessionStorage['FLUTTER_APP_$state'] = codeVerifier;

    String challenge = _generateCodeChallenge(codeVerifier);
    String url = '$authorizationURL?'
        'response_type=code'
        '&prompt=consent&access_type=offline' // @todo: to force refresh token
        '&code_challenge_method=S256'
        '&code_challenge=$challenge'
        '&client_id=$clientID'
        '&redirect_uri=$redirectURL'
        '&state=$state';

    _generateScope(scope_);
    if (scope.isNotEmpty) {
      url += '&scope=$scope';
    }
    return url;
  }

  Future<void> LoginCallback(RouteSettings settings) async {
    if (settings.name == null) return;

    Map queryParameters;
    var uriData = Uri.parse(settings.name!);
    queryParameters = uriData.queryParameters;

    if (!queryParameters.containsKey('code')) return;
    if (queryParameters.containsKey('state')) state = queryParameters['state'];

    /// flutter bug workaround
    /// https://github.com/flutter/flutter/issues/71786
    if (queryParameters['code'].length < 2) return;
    if (html.window.sessionStorage.containsKey('__FLUTTER_GENERATE_ROUTE__'))
      return;
    html.window.sessionStorage['__FLUTTER_GENERATE_ROUTE__'] = '#';

    _handleTokenResponseState();

    String url = tokenURL;
    var body = urlEncoded
        ? _generateTokenRequestBodyUrlEncoded(queryParameters['code'])
        : _generateTokenRequestBodyJson(queryParameters['code']);
    Uri uri = Uri.parse(url);
    http.Response response = await http
        .post(uri, body: urlEncoded ? body : jsonEncode(body), headers: {
      'Content-type':
          urlEncoded ? 'application/x-www-form-urlencoded' : 'application/json',
    });

    Map<String, dynamic> resBody = jsonDecode(response.body);
    _handleTokenResponseCode(response.statusCode, resBody);

    html.window.history.pushState({}, '', '/callback');

    /// Clean up flutter bug workaround
    html.window.sessionStorage.remove('__FLUTTER_GENERATE_ROUTE__');
  }

  void loadFromStorage() {
    token = Token.fromSession();
    if (token!.hasRefresh() && token!.isValid()) return;
    token = Token.fromStorage();
  }

  void silentLogin() {
    token = Token.fromSession();
    if (token!.isValid()) return;
    if (token!.hasRefresh()) {
      RefreshToken();
    }

    token = Token.fromStorage();
    if (token == null) return;
    if (token!.isValid()) return;

    if (token!.hasRefresh()) {
      RefreshToken();
    }
  }

  void RefreshToken() async {
    var body = urlEncoded
        ? _generateRefreshRequestBodyUrlEncoded
        : _generateRefreshRequestBodyJson();
    Uri uri = Uri.parse(tokenURL);
    http.Response response = await http
        .post(uri, body: urlEncoded ? body : jsonEncode(body), headers: {
      'Content-type':
          urlEncoded ? 'application/x-www-form-urlencoded' : 'application/json',
    });

    Map<String, dynamic> resBody = jsonDecode(response.body);
    _handleTokenRefreshCode(response.statusCode, resBody);
  }

  /// Private Methods
  String _generateCodeVerifier({int length = 64}) {
    var rng = Random();
    const String charset =
        '2Pb3fHSdoziWjtFVkn9JUhlpIEgTxMKAv51qDrXR4LOe7CBYy0auZQmw8sGc6N';

    String verifier = '';
    for (int i = 0; i < length; i++) {
      verifier += charset[rng.nextInt(charset.length)];
    }
    return verifier;
  }

  String _generateCodeChallenge(String verifier) {
    var hash = sha256.convert(ascii.encode(verifier));
    String code_challenge = base64Url
        .encode(hash.bytes)
        .replaceAll("=", "")
        .replaceAll("+", "-")
        .replaceAll("/", "_");
    return code_challenge;
  }

  void _decodeState(String _state) {}

  void _generateScope(String? _scope) {
    if (html.window.localStorage.containsKey('FLUTTER_APP_SCOPE')) {
      scope = utf8.decode(
          base64.decode(html.window.localStorage['FLUTTER_APP_SCOPE']!));
    }

    if (_scope != null) {
      scope = _scope;
    }
  }

  String _encodeState({String? data}) {
    String _state = '';

    _state += 'return_address=${Uri.base.toString()}';

    if (data != null) _state += '&user_data=$data';

    return base64Encode(_state.codeUnits);
  }

  Map<String, String> _generateTokenRequestBodyJson(String code) {
    return {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': '$redirectURL',
      'code_verifier': '$codeVerifier',
      'client_id': '$clientID',
      'client_secret': '$clientSecret'
    };
  }

  String _generateTokenRequestBodyUrlEncoded(String code) {
    return 'grant_type=authorization_code'
        '&code=$code'
        '&redirect_uri=$redirectURL'
        '&code_verifier=$codeVerifier'
        '&client_id=$clientID'
        '&client_secret=$clientSecret';
  }

  void _handleTokenResponseCode(int status, Map<String, dynamic> responseBody) {
    switch (status) {
      case 200: // OK
        if (!responseBody.containsKey('access_token') ||
            !responseBody.containsKey('expires_in')) {
          /// token or expiration date missing
          throw ErrorDescription(
              'missing params - "token" and/or "expires" missing');
        }

        /// parse and store tokens
        token = Token.fromJson(responseBody);
        token!.StoreInSession();
        token!.StoreInStorage();
        break;

      /// @todo: Error Handling
      case 400: // Bad Request
      case 401: // Unauthorized
      case 403: // Forbidden
      case 404: // Not Found
      case 500: // internal Server Error
      case 503: // unavailable
      default: // other
        if (responseBody.containsKey('error')) {
          navigatorKey.currentState!.pushNamed('/');
          throw ErrorDescription(
              '${responseBody['error']} - ${responseBody['error_description']}');
        }
        break;
    }
  }

  void _handleTokenResponseState() {
    if (html.window.sessionStorage.containsKey('FLUTTER_APP_$state')) {
      codeVerifier = html.window.sessionStorage['FLUTTER_APP_$state']!;
      html.window.sessionStorage.remove('FLUTTER_APP_$state');
    }
  }

  void _handleTokenRefreshCode(int status, Map<String, dynamic> responseBody) {
    switch (status) {
      case 200: // OK
        if (!responseBody.containsKey('access_token') ||
            !responseBody.containsKey('expires_in')) {
          /// token or expiration date missing
          throw ErrorDescription(
              'missing params - "token" and/or "expires" missing');
          break;
        }

        /// parse and store tokens
        token = Token.fromJson(responseBody);
        token!.StoreInSession();
        token!.StoreInStorage();
        break;

      /// @todo: Error Handling
      case 400: // Bad Request
      case 401: // Unauthorized
      case 403: // Forbidden
      case 404: // Not Found
      case 500: // internal Server Error
      case 503: // unavailable
      default: // other
        if (responseBody.containsKey('error')) {
          navigatorKey.currentState!.pushNamed('/');
          throw ErrorDescription(
              '${responseBody['error']} - ${responseBody['error_description']}');
        }
        break;
    }
  }

  Map<String, String> _generateRefreshRequestBodyJson() {
    return {
      'grant_type': 'refresh_token',
      'refresh_token': '${token!.refresh}',
      'client_id': '$clientID',
      'client_secret': '$clientSecret'
    };
  }

  String _generateRefreshRequestBodyUrlEncoded() {
    return 'grant_type=refresh_token'
        '&refresh_token=${token!.refresh}'
        '&client_id=$clientID'
        '&client_secret=$clientSecret';
  }
}
