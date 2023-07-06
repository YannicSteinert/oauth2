import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:oauth2/data/models/token.dart';
import 'package:oauth2/services/oauth2.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

OAuth2 oauth2 = OAuth2(
    authorization: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenEndpoint: 'https://www.googleapis.com/oauth2/v4/token',
    clientID: '435227925555-fgipc00h8bkals5qil7fmugno9pee8up.apps.googleusercontent.com',
    clientSecret: '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',
    redirectURL: 'http://localhost:54822/callback',
    scope: 'https://www.googleapis.com/auth/gmail.readonly');

void main() {
  usePathUrlStrategy();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    oauth2.SilentLogin();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OAuth2 - Flutter Demo',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
        onGenerateRoute: (settings) {
        oauth2.LoginCallback(settings);
        return MaterialPageRoute(
            builder: (context) => MyHomePage(), settings: settings);
      },
      initialRoute: '/',
    );
  }
}


class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OAuth2 - Flutter Demo'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Center(
            child: TextButton(
              onPressed: () => html.window.open(oauth2.LoginRedirectUrl(), '_self'),
              child: Text('Login'),
            ),
          ),
          TextButton(
            onPressed: () {
              oauth2.LoadFromStorage();
              oauth2.RefreshToken();},
            child: Text('Refresh'),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(oauth2.IsAuthed() ? 'Logged In' : 'Logged Out'))),
            child: Text('Status?'),
          ),
          TextButton(
            onPressed: () => html.window.sessionStorage.clear(),
            child: Text('Kill Session'),
          ),
          TextButton(
            onPressed: () => html.window.localStorage.clear(),
            child: Text('Kill Storage'),
          ),
          TextButton(
            onPressed: () => html.window.sessionStorage['FLUTTER_APP_EXPIRE'] = 'MjAwNS0wNi0wNCAxOTo0ODoxMi40NjI=',
            child: Text('Expire Token'),
          ),

        ],
      ),
    );
  }
}