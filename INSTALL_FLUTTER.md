# Flutter SDK 安装指南

## 快速安装步骤

### 1. 下载Flutter SDK
- 访问: https://docs.flutter.dev/get-started/install/windows
- 下载最新稳定版 (推荐 3.24.0+)
- 解压到: `C:\flutter` (或您喜欢的位置)

### 2. 设置环境变量
1. 右键"此电脑" → 属性 → 高级系统设置
2. 点击"环境变量"
3. 在"系统变量"中找到"Path"，点击"编辑"
4. 添加: `C:\flutter\bin`
5. 确定并重启命令行

### 3. 验证安装
```cmd
flutter doctor
```

### 4. 安装Android工具链
```cmd
flutter doctor --android-licenses
```

## 如果您已经有Flutter

检查是否在PATH中：
```cmd
echo %PATH%
```

或者直接运行完整路径：
```cmd
C:\flutter\bin\flutter devices
C:\flutter\bin\flutter run
```

## 快速测试命令
```cmd
cd D:\code\metting\flutter_meeting_app
flutter pub get
flutter devices
flutter run
```