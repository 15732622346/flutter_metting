@echo off
echo 🚀 启动 Flutter Web 代理服务器...
echo.

REM 检查 Node.js 是否安装
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ 错误: 未找到 Node.js
    echo 请先安装 Node.js: https://nodejs.org/
    pause
    exit /b 1
)

echo ✅ Node.js 已安装
echo.

REM 进入 web 目录
cd /d "%~dp0web"

REM 检查是否已安装依赖
if not exist "node_modules" (
    echo 📦 安装代理服务器依赖...
    npm install
    if %errorlevel% neq 0 (
        echo ❌ 依赖安装失败
        pause
        exit /b 1
    )
    echo ✅ 依赖安装完成
    echo.
)

echo 🌐 启动代理服务器...
echo 📡 代理地址: http://localhost:3001
echo 🎯 目标服务器: https://meet.pgm18.com
echo.
echo 💡 提示: 保持此窗口打开，然后在另一个终端运行 Flutter Web
echo.

REM 启动代理服务器
npm start
