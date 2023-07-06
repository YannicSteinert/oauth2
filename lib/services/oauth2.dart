import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:html' as html;
import 'dart:convert';

import 'package:oauth2/data/models/token.dart';
import 'package:oauth2/main.dart';

class OAuth2 {
  Token? token;

  String clientID, clientSecret, redirectURL;
  String authorization, tokenEndpoint;
  String codeVerifier = '', scope = '', state = '';

  OAuth2(
      {required this.authorization,
      required this.tokenEndpoint,
      required this.clientID,
      required this.clientSecret,
      required this.redirectURL,
      this.scope = ''});


  String _generateLoginUrl() {
    return authorization;
  }

  String _generateTokenUrl() {
    return tokenEndpoint;
  }

  String _generateCodeVerifier({int length = 64}) {
    var rng = Random();
    const String charset =
        '2Pb3fHSdoziWjtFVkn9JUhlpIEgTxMKAv51qDrXR4LOe7CBYy0auZQmw8sGc6N';

    String challenge = '';
    for (int i = 0; i < length; i++) {
      challenge += charset[rng.nextInt(charset.length)];
    }
    return challenge;
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

  String _generateRedirectURL() {
    String challenge = _generateCodeChallenge(codeVerifier);

    return '${_generateLoginUrl()}?'
        'response_type=code'
        '&prompt=consent&access_type=offline' // @todo: to force refresh token
        '&code_challenge_method=S256'
        '&code_challenge=$challenge'
        '&client_id=$clientID'
        '&redirect_uri=$redirectURL'
        '&state=$state';
  }

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

  String LoginRedirectUrl({String? scope_ = null}) {
    state = _encodeState();

    codeVerifier = _generateCodeVerifier();
    html.window.sessionStorage['FLUTTER_APP_$state'] = codeVerifier;

    _generateScope(scope_);
    String url = _generateRedirectURL();

    if (scope.isNotEmpty) {
      url += '&scope=$scope';
    }
    return url;
  }

  Map<String, String> _generateTokenRequestBody(String code) {
    return {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': '$redirectURL',
      'code_verifier': '$codeVerifier',
      'client_id': '$clientID',
      'client_secret': '$clientSecret'
    };
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

    String url = _generateTokenUrl();
    var body = _generateTokenRequestBody(queryParameters['code']);
    Uri uri = Uri.parse(url);
    http.Response response = await http.post(uri,
        body: jsonEncode(body),
        headers: {
          'Content-type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });

    Map<String, dynamic> resBody = jsonDecode(response.body);
    _handleTokenResponseCode(response.statusCode, resBody);

    html.window.history.pushState({}, '', '/callback');

    /// Clean up flutter bug workaround
    html.window.sessionStorage.remove('__FLUTTER_GENERATE_ROUTE__');
  }


  void LoadFromStorage() {
    token = Token.fromSession();
    if(token!.hasRefresh() && token!.isValid()) return;
    token = Token.fromStorage();
  }

  void SilentLogin() {
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

  bool IsAuthed() {
    LoadFromStorage();
    if (token!.isValid()) {
      return true;
    }
    return false;
  }

  bool _handleTokenRefreshCode(int status, Map<String, dynamic> responseBody) {
    switch (status) {
      case 200: // OK
        if (!responseBody.containsKey('access_token') ||
            !responseBody.containsKey('expires_in')) {
          /// token or expiration date missing
          throw ErrorDescription(
              'missing params - "token" and/or "expires" missing');
          return false;
        }

        /// parse and store tokens
        token = Token.fromJson(responseBody);
        token!.StoreInSession();
        token!.StoreInStorage();
        return true;

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
        return false;
    }
    return false;
  }

  Map<String, String> _generateRefreshRequestBody() {
    return {
      'grant_type': 'refresh_token',
      'refresh_token': '${token!.refresh}',
      'client_id': '$clientID',
      'client_secret': '$clientSecret'
    };
  }

  Future<bool> RefreshToken() async {
    var body = _generateRefreshRequestBody();
    Uri uri = Uri.parse(_generateTokenUrl());
    http.Response response = await http.post(uri,
        body: jsonEncode(body),
        headers: {
          'Content-type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        });

    Map<String, dynamic> resBody = jsonDecode(response.body);
    return _handleTokenRefreshCode(response.statusCode, resBody);
  }
}
