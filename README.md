# oauth2

Implements a simple OAuth2 PKCE flow in Flutter - Web.

## Getting Started

In the `main()` method set url strategy to path.
```dart
void main() {
  usePathUrlStrategy();
  runApp(MyApp());
}```

In your root widget put `oauth2.LoginCallback(settings);` in `onGenerateRoute`