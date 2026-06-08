echo "[+] Running Flutter commands..."
echo "[+] Cleaning the project..."
flutter clean > logs/clean.log 2>&1

echo "[+] Getting dependencies..."
flutter pub get > logs/pub_get.log 2>&1

echo "[+] Analyzing the code..."
flutter analyze > logs/analyze.log 2>&1

echo "[+] Running tests..."
flutter test > logs/test.log 2>&1

echo "[+] Running the app on the device..."
flutter run -d RF8R1109CLR > logs/run.log 2>&1