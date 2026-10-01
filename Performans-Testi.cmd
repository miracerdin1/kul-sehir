@echo off
rem Sehir FPS olcumu: yaklasik 1 dakika surer, sonucu godot\qa-output\city_performance.txt dosyasina yazar.
set "GODOT=%~dp0.tools\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" (
  echo Godot bulunamadi. Once python tools/setup_assets.py komutunu calistirin.
  pause
  exit /b 1
)
"%GODOT%" --path "%~dp0godot" -- --city-performance
echo.
echo Sonuc dosyasi: godot\qa-output\city_performance.txt
pause
