flutter clean
flutter pub get
flutter build web --release --web-renderer html
dhttpd -p 8080 --path=./build/web --host=127.0.0.1
