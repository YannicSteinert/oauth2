# oauth2

Implements a simple OAuth2 PKCE flow in Flutter - Web.

## Getting Started

In the `main()` method set url strategy to path and in the root widget put `oauth2.LoginCallback(settings);` in `onGenerateRoute`.

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
OAuth2 oauth2 = OAuth2(
  /// Optional `$baseURL$endpoint` defaults to ''
    baseURL: 'https://www.example.org/oauth',
    authorizationEndpoint: '/login',
    tokenEndpoint: '/token',
    clientID: 'flutter-client',
    clientSecret: 'p@ssw0rd',
    redirectURL: 'http://localhost:8080/callback',
    navigatorKey: navigatorKey,
    /// optional
    scope: 'profile.readOnly');

void main() {
  /// set url strategy
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      navigatorKey: navigatorKey,
      onGenerateRoute: (settings) {
        /// login callback inside on generate route 
        oauth2.LoginCallback(settings);
        return MaterialPageRoute(
            builder: (context) => MyHomePage(), settings: settings);
      },
      initialRoute: '/',
    );
  }
}
```
