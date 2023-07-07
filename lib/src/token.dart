import 'package:flutter/material.dart';

import 'dart:html' as html;
import 'dart:convert';

class Token {
  String? token, refresh, scope;
  DateTime? expire;

  Token.empty() {
    token = null;
    refresh = null;
    scope = null;
    expire = null;
  }

  void Print() {
    print('token: [${token ?? ''}]');
    print('refresh: [${refresh ?? ''}]');
    print('scope: [${scope ?? ''}]');
    print('expire: [${expire ?? ''}]');
  }

  Token.fromSession() {
    if (html.window.sessionStorage.containsKey('FLUTTER_APP_TOKEN'))
      token = utf8.decode(base64.decode(html.window.sessionStorage['FLUTTER_APP_TOKEN']!));
    if (html.window.sessionStorage.containsKey('FLUTTER_APP_REFRESH'))
      refresh = utf8.decode(base64.decode(html.window.sessionStorage['FLUTTER_APP_REFRESH']!));
    if (html.window.sessionStorage.containsKey('FLUTTER_APP_SCOPE'))
      scope = utf8.decode(base64.decode(html.window.sessionStorage['FLUTTER_APP_SCOPE']!));
    if (html.window.sessionStorage.containsKey('FLUTTER_APP_EXPIRE'))
      expire = DateTime.parse(utf8.decode(base64.decode(html.window.sessionStorage['FLUTTER_APP_EXPIRE']!)));
  }

  Token.fromStorage() {
    if (html.window.localStorage.containsKey('FLUTTER_APP_TOKEN'))
      token = utf8.decode(
          base64.decode(html.window.localStorage['FLUTTER_APP_TOKEN']!));
    if (html.window.localStorage.containsKey('FLUTTER_APP_REFRESH'))
      refresh = utf8.decode(
          base64.decode(html.window.localStorage['FLUTTER_APP_REFRESH']!));
    if (html.window.localStorage.containsKey('FLUTTER_APP_SCOPE'))
      scope = utf8.decode(
          base64.decode(html.window.localStorage['FLUTTER_APP_SCOPE']!));
    if (html.window.localStorage.containsKey('FLUTTER_APP_EXPIRE'))
      expire = DateTime.parse(utf8.decode(
          base64.decode(html.window.localStorage['FLUTTER_APP_EXPIRE']!)));
  }

  Token.fromJson(Map<String, dynamic> _json) {
    if (_json.containsKey('access_token')) token = _json['access_token'];
    if (_json.containsKey('refresh_token')) refresh = _json['refresh_token'];
    if (_json.containsKey('scope')) scope = _json['scope'];

    /// calc expire date and remove 5 minutes for safety
    if (_json.containsKey('expires_in')) expire =
        DateTime.now().add(Duration(seconds: (_json['expires_in'] - 300)));
  }

  void StoreInStorage() {
    /// Store in local storage
    if (token != null)
      html.window.localStorage['FLUTTER_APP_TOKEN'] =
          base64.encode(token!.codeUnits);
    if (refresh != null)
      html.window.localStorage['FLUTTER_APP_REFRESH'] =
          base64.encode(refresh!.codeUnits);
    if (expire != null)
      html.window.localStorage['FLUTTER_APP_EXPIRE'] =
          base64.encode(expire!.toString().codeUnits);
    if (scope != null)
      html.window.localStorage['FLUTTER_APP_SCOPE'] =
          base64.encode(scope!.codeUnits);
  }

  void StoreInSession() {
    /// Store in local storage
    if (token != null)
      html.window.sessionStorage['FLUTTER_APP_TOKEN'] =
          base64.encode(token!.codeUnits);
    if (refresh != null)
      html.window.sessionStorage['FLUTTER_APP_REFRESH'] = base64.encode(refresh!.codeUnits);
    if (expire != null)
      html.window.sessionStorage['FLUTTER_APP_EXPIRE'] =
          base64.encode(expire!.toString().codeUnits);
    if (scope != null)
      html.window.sessionStorage['FLUTTER_APP_SCOPE'] =
          base64.encode(scope!.codeUnits);
  }

  bool isNull() {
    if(token == null && refresh == null)
      return true;
    return false;
  }

  bool isValid() {
    /// no token oder expire date
    if (token == null || expire == null) {
      return false;
    }

    /// token is expired or expires within 5 seconds
    if (expire!.isBefore(DateTime.now().add(Duration(seconds: 5)))) {
      return false;
    }
    return true;
  }

  bool hasRefresh() {
    /// no token oder expire date
    if (refresh == null) {
      return false;
    }
    return true;
  }

  bool isExpired() {
    if(expire == null) {
      return true;
    }
    if (expire!.isBefore(DateTime.now().add(Duration(seconds: 5)))) {
      return true;
    }
    return false;
  }

  Map<String, String> generateHeader() {
      if (token == null) {
        throw ErrorDescription('Tried to generate auth headers without token');
      }
      return {'Authorization': 'Bearer $token'};
    }
}
