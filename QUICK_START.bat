@echo off
echo ================================
echo Flutter视频会议应用 - 快速启动脚本
echo ================================
echo.

echo 1. 检查Flutter环境...
flutter doctor
echo.

echo 2. 获取项目依赖...
flutter pub get
echo.

echo 3. 检查连接的设备...
flutter devices
echo.

echo 4. 选择操作:
echo    [1] 直接运行到设备 (flutter run)
echo    [2] 构建调试APK (flutter build apk --debug)
echo    [3] 构建发布APK (flutter build apk --release)
echo.

set /p choice="请输入选项 (1-3): "

if "%choice%"=="1" (
    echo 正在启动应用到连接的设备...
    flutter run
) else if "%choice%"=="2" (
    echo 正在构建调试版APK...
    flutter build apk --debug
    echo APK已生成: build\app\outputs\flutter-apk\app-debug.apk
) else if "%choice%"=="3" (
    echo 正在构建发布版APK...
    flutter build apk --release
    echo APK已生成: build\app\outputs\flutter-apk\app-release.apk
) else (
    echo 无效选项，正在退出...
)

echo.
echo 完成！
pause