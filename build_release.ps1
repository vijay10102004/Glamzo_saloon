# Glamzo Saloon - Optimised Release Build
# Run: .\build_release.ps1

Write-Host "Cleaning..." -ForegroundColor Yellow
flutter clean
flutter pub get

Write-Host "Building split-ABI release APKs..." -ForegroundColor Yellow
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/debug-info --tree-shake-icons --no-pub

Write-Host "Done! APK sizes:" -ForegroundColor Green
Get-ChildItem "build\app\outputs\flutter-apk\" -Filter "*.apk" | Select-Object Name, @{N="SizeMB";E={[math]::Round($_.Length/1MB,2)}} | Format-Table -AutoSize
