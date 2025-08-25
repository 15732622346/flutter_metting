# Flutter视频会议应用 - 构建和安装指南

## 📋 环境准备

### 1. 安装Flutter SDK
```bash
# 下载Flutter SDK (推荐版本 3.24.0+)
# https://docs.flutter.dev/get-started/install

# 验证安装
flutter doctor
```

### 2. 安装Android Studio
- 下载并安装Android Studio
- 安装Android SDK (API level 21+)
- 配置环境变量

### 3. 启用开发者选项
在Android手机上：
1. 设置 → 关于手机 → 连续点击"版本号"7次
2. 返回设置 → 开发者选项
3. 开启"USB调试"
4. 开启"安装未知应用"

## 🚀 构建步骤

### 步骤1: 进入项目目录
```bash
cd D:\code\metting\flutter_meeting_app
```

### 步骤2: 获取依赖
```bash
flutter pub get
```

### 步骤3: 检查连接的设备
```bash
flutter devices
```
应该显示您连接的Android手机

### 步骤4: 构建并安装到手机
```bash
# 构建并直接安装到连接的设备
flutter run

# 或者构建APK文件
flutter build apk --debug

# 构建发布版APK
flutter build apk --release
```

### 步骤5: 手动安装APK（如果需要）
```bash
# APK文件位置: build/app/outputs/flutter-apk/app-release.apk
# 可以通过adb安装
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 📱 测试功能

### 基本功能测试
1. **启动应用** - 检查启动画面和导航
2. **注册功能** - 测试新用户注册
3. **登录功能** - 输入用户名、密码和房间码
4. **权限请求** - 确认摄像头和麦克风权限
5. **会议功能** - 测试视频、音频、聊天等功能

### 权限测试
- 摄像头权限：应用首次启动时请求
- 麦克风权限：应用首次启动时请求
- 网络权限：自动获取

### 功能验证
- ✅ 用户注册和登录
- ✅ 房间加入（需要现有系统的房间ID和邀请码）
- ✅ 视频通话（需要LiveKit服务器运行）
- ✅ 音频控制
- ✅ 摄像头切换
- ✅ 参与者列表
- ✅ 聊天功能
- ✅ 设置管理

## 🔧 故障排除

### 常见问题

#### 1. Flutter环境问题
```bash
flutter doctor
# 根据提示解决环境问题
```

#### 2. 设备连接问题
```bash
# 检查ADB连接
adb devices

# 如果没有设备，尝试：
adb kill-server
adb start-server
```

#### 3. 权限问题
- 确保手机开启"开发者选项"和"USB调试"
- 在电脑上安装对应的USB驱动

#### 4. 构建失败
```bash
# 清理项目
flutter clean
flutter pub get

# 重新构建
flutter build apk --debug
```

### 网络配置
确保手机和电脑在同一网络下，且能访问：
- `https://meet.pgm18.com` - 后端API服务器
- LiveKit服务器地址（根据配置）

## 📊 性能监控

### 实时调试
```bash
# 启动调试模式
flutter run --debug

# 热重载（修改代码后）
r (在运行终端输入)

# 热重启
R (在运行终端输入)
```

### 性能分析
```bash
# 启动性能分析器
flutter run --profile
```

## 📋 API测试

### 测试后端连接
使用浏览器或Postman测试：
```
GET https://meet.pgm18.com/admin/room-info.php?room_id=test
POST https://meet.pgm18.com/admin/pc-register.php
```

### LiveKit连接测试
确保LiveKit服务器运行在：
- 端口7880-7882
- 配置正确的API Key和Secret

## 🎯 下一步优化

1. **性能优化** - 根据实际使用情况优化
2. **UI适配** - 适配不同尺寸的手机
3. **功能扩展** - 根据用户反馈增加功能
4. **发布准备** - 准备上架应用商店

---

**注意**: 这是一个完整的视频会议应用，需要确保后端服务和LiveKit服务正常运行才能完整体验所有功能。