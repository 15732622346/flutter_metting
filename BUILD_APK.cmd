@echo off
echo ========================================
echo Flutter视频会议应用 - APK构建脚本
echo ========================================
echo.

REM 检查Flutter是否安装
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter未安装或未在PATH中
    echo 请先安装Flutter SDK: https://docs.flutter.dev/get-started/install/windows
    echo.
    echo 或者使用完整路径运行：
    echo C:\flutter\bin\flutter pub get
    echo C:\flutter\bin\flutter build apk --debug
    pause
    exit /b 1
)

echo ✅ Flutter已找到
flutter --version
echo.

echo 📦 获取依赖...
flutter pub get
if errorlevel 1 (
    echo ❌ 依赖获取失败
    pause
    exit /b 1
)

echo 📱 检查连接的设备...
flutter devices
echo.

echo 🔨 开始构建APK...
flutter build apk --debug
if errorlevel 1 (
    echo ❌ APK构建失败
    pause
    exit /b 1
)

echo.
echo ✅ APK构建成功！
echo 📁 文件位置: build\app\outputs\flutter-apk\app-debug.apk
echo.

echo 📲 现在可以：
echo 1. 手动安装APK到手机
echo 2. 或者运行: flutter install (直接安装到连接的设备)
echo.

set /p choice="是否直接安装到连接的设备? (y/n): "
if /i "%choice%"=="y" (
    echo 正在安装到设备...
    flutter install
)

pause