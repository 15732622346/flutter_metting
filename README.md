# Flutter视频会议应用

这是一个基于Flutter和LiveKit开发的移动视频会议应用，与现有的PHP后端系统完全集成。

## 🚀 功能特性

### 核心功能
- **实时视频通话** - 基于LiveKit WebRTC技术
- **音频通话** - 高质量音频传输
- **聊天功能** - 会议期间实时文字聊天
- **屏幕共享** - 支持屏幕内容分享
- **参与者管理** - 查看和管理会议参与者

### 用户管理
- **用户注册/登录** - 安全的用户认证系统
- **权限管理** - 普通用户、主持人、管理员三级权限
- **密码修改** - 用户可自主修改密码
- **个人设置** - 个性化会议设置

### 会议控制
- **摄像头控制** - 开启/关闭摄像头，前后摄像头切换
- **麦克风控制** - 开启/关闭麦克风，音量调节
- **申请上麦** - 普通用户可申请发言权限
- **会议设置** - 音频/视频质量设置

## 🏗️ 技术架构

### Flutter端
- **框架**: Flutter 3.24+
- **状态管理**: Provider
- **网络请求**: Dio
- **实时通信**: LiveKit Flutter SDK
- **本地存储**: SharedPreferences + FlutterSecureStorage

### 后端集成
- **API后端**: 复用现有PHP后端 (`https://meet.pgm18.com/admin/`)
- **数据库**: SQLite (用户、房间、参与者管理)
- **权限系统**: 与现有三级权限系统完全兼容
- **LiveKit服务器**: 共享现有LiveKit实例

### 权限系统
```
用户角色说明:
- 1 = 普通会员 (ROLE_MEMBER)
- 2 = 主持人 (ROLE_HOST) 
- 3 = 管理员 (ROLE_ADMIN)

房间权限:
- 管理员: 所有房间都有管理权限
- 主持人: 只在被指定的房间有主持人权限
- 普通用户: 需要申请上麦才能发言
```

## 📱 界面设计

应用界面完全基于提供的原型图设计：

1. **登录界面** - 用户登录和房间码输入
2. **会议列表** - 显示可用的会议房间  
3. **视频会议界面** - 主要的会议画面和控制
4. **个人中心** - 用户信息和设置管理
5. **会议设置** - 音视频参数配置
6. **修改密码** - 安全密码修改功能

## 🔧 开发环境设置

### 前置要求
- Flutter SDK 3.24.0+
- Dart SDK 3.5.0+
- Android Studio / VS Code
- iOS开发需要Xcode (macOS)

### 安装依赖
```bash
cd flutter_meeting_app
flutter pub get
```

### 平台配置

#### Android权限 (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

#### iOS权限 (ios/Runner/Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>视频会议需要使用摄像头</string>
<key>NSMicrophoneUsageDescription</key>
<string>视频会议需要使用麦克风</string>
```

### 运行应用
```bash
# Android
flutter run

# iOS (需要macOS)
flutter run -d ios

# 指定设备
flutter devices
flutter run -d <device-id>
```

## 🌐 API集成

### 核心接口
- `POST /admin/room-login.php` - 房间登录获取LiveKit Token
- `GET /admin/room-info.php` - 获取房间信息
- `POST /admin/pc-register.php` - 用户注册
- `GET /admin/list-room.php` - 房间列表 (需认证)

### 数据流
```
Flutter App -> PHP API -> LiveKit Server -> WebRTC
     ↓           ↓            ↓
  用户界面    权限验证    实时通信
     ↓           ↓            ↓
  状态管理    数据库存储   媒体传输
```

## 📊 项目结构

```
lib/
├── main.dart                 # 应用入口
├── models/                   # 数据模型
│   ├── user_model.dart
│   ├── room_model.dart
│   ├── login_response.dart
│   └── participant_model.dart
├── services/                 # 服务层
│   ├── api_service.dart     # API通信
│   └── livekit_service.dart # LiveKit集成
├── providers/               # 状态管理
│   ├── auth_provider.dart
│   └── meeting_provider.dart
├── screens/                 # 界面
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── meeting_list_screen.dart
│   ├── video_conference_screen.dart
│   ├── profile_screen.dart
│   ├── settings_screen.dart
│   └── change_password_screen.dart
└── widgets/                 # UI组件
    ├── video_track_widget.dart
    ├── participant_grid.dart
    ├── control_bar.dart
    └── chat_panel.dart
```

## 🔒 安全特性

- **Token认证**: 使用LiveKit JWT Token进行会议认证
- **权限控制**: 细粒度的用户权限管理
- **安全存储**: 敏感数据使用FlutterSecureStorage加密存储
- **网络安全**: HTTPS通信，防止中间人攻击

## 🚦 部署流程

### 开发环境测试
```bash
# 连接测试设备
flutter devices

# 运行调试版本
flutter run --debug

# 热重载测试
r (在运行时按r键)
```

### 生产环境构建
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (需要macOS)
flutter build ios --release
```

### 发布准备
1. **Android**: 生成签名密钥，配置`android/app/build.gradle`
2. **iOS**: 配置Apple Developer账号，设置Bundle ID
3. **测试**: 在真实设备上进行充分测试
4. **发布**: 提交到Google Play Store / Apple App Store

## 🤝 与现有系统集成

本Flutter应用完美集成现有的视频会议系统：

### Web版本互通
- **同一LiveKit服务器**: 使用相同的LiveKit实例
- **共享房间**: Web用户和移动用户可在同一房间
- **统一权限**: 使用相同的用户权限系统
- **实时同步**: 用户状态和消息实时同步

### 后端复用
- **无需修改**: 现有PHP后端无需任何修改
- **数据库共享**: 使用相同的SQLite数据库
- **API兼容**: 完全兼容现有API接口

## 📞 技术支持

如有技术问题或需要支持，请联系开发团队。

## 📄 许可证

本项目仅供内部使用，所有权利保留。