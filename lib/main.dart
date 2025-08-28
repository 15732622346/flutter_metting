import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/video_conference_screen.dart';
import 'screens/simple_profile_screen.dart';
import 'screens/login_register_screen.dart';
import 'screens/meet_list_screen.dart';
import 'services/app_updater.dart';
import 'core/hot_update_manager.dart';
import 'widgets/version_float_widget.dart';
import 'config/version_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 禁用 Flutter Web 调试工具栏
  if (kIsWeb && kDebugMode) {
    // 隐藏 Flutter Web 的调试工具栏
    debugPrint('隐藏 Flutter Web 调试工具栏');
  }

  // 完全禁用热更新功能（避免 Web 端问题）
  if (kDebugMode) {
    print('热更新功能已禁用');
  }

  // 注释掉热更新相关代码
  // if (!kIsWeb) {
  //   await HotUpdateManager.instance.initialize();
  //   HotUpdateManager.instance.startAutoCheck();
  // }

  runApp(const VideoMeetingApp());
}

// 模拟用户数据库
class UserDatabase {
  static List<Map<String, String>> users = [
    {'username': 'admin', 'password': '123456'},
    {'username': 'user1', 'password': 'password'},
    {'username': 'test', 'password': 'test123'},
  ];

  // 检查用户是否存在
  static bool userExists(String username) {
    return users.any((user) => user['username'] == username);
  }

  // 验证登录
  static bool validateLogin(String username, String password) {
    return users.any((user) =>
        user['username'] == username && user['password'] == password);
  }

  // 注册新用户
  static bool registerUser(String username, String password) {
    if (userExists(username)) {
      return false; // 用户已存在
    }
    users.add({'username': username, 'password': password});
    return true;
  }
}

// 用户状态管理
class UserManager {
  static const String _loginStateKey = 'isLoggedIn';
  static const String _usernameKey = 'username';

  // 保存登录状态
  static Future<void> saveLoginState(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginStateKey, true);
    await prefs.setString(_usernameKey, username);
  }

  // 获取登录状态
  static Future<Map<String, dynamic>> getLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_loginStateKey) ?? false;
    final username = prefs.getString(_usernameKey) ?? '';
    return {'isLoggedIn': isLoggedIn, 'username': username};
  }

  // 清除登录状态
  static Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginStateKey);
    await prefs.remove(_usernameKey);
  }
}

class VideoMeetingApp extends StatelessWidget {
  const VideoMeetingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '视频会议',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // 设置应用栏主题
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.blue, // 状态栏背景色设为蓝色
            statusBarIconBrightness: Brightness.light, // 状态栏图标为白色
            statusBarBrightness: Brightness.dark, // iOS状态栏内容为白色
          ),
        ),
      ),
      home: const MeetListPage(),
      debugShowCheckedModeBanner: false, // 隐藏右上角 debug 标签
      // 在 Web 平台隐藏调试工具栏
      builder: (context, child) {
        if (kIsWeb && kDebugMode) {
          // 通过自定义 builder 来隐藏 Web 调试工具
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              // 移除顶部的调试工具栏空间
              padding: MediaQuery.of(context).padding.copyWith(top: 0),
            ),
            child: child!,
          );
        }
        return child!;
      },
    );
  }
}





