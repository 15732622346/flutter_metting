import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/user_manager.dart';
import '../services/app_updater.dart';
import '../services/gateway_api_service.dart';
import '../config/version_config.dart';

/// 简洁个人中心界面 - 与图片样式完全匹配的版本
/// 这是从 main.dart 中提取的 UserProfilePage 类
/// 特点：简洁的白色背景，无阴影，纯净的UI设计
class SimpleProfileScreen extends StatefulWidget {
  final String username;
  final VoidCallback onLogout;

  const SimpleProfileScreen({
    super.key,
    required this.username,
    required this.onLogout,
  });

  @override
  State<SimpleProfileScreen> createState() => _SimpleProfileScreenState();
}

class _SimpleProfileScreenState extends State<SimpleProfileScreen> {
  static const String _secureAuthStorageKey = 'gateway_auth';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final GatewayApiService _gatewayService = GatewayApiService();
  // 防抖标志，防止快速重复点击
  bool _isButtonClickable = true;
  // 提示显示状态标志
  bool _isToastVisible = false;
  String? _nickname;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final storedData = await UserManager.getStoredUserData();
    if (!mounted) {
      return;
    }

    final dynamic nicknameValue = storedData?['userNickname'] ??
        storedData?['user_nickname'] ??
        storedData?['nickname'];
    final nickname = nicknameValue is String ? nicknameValue.trim() : null;

    setState(() {
      _nickname = nickname?.isEmpty == true ? null : nickname;
    });
  }

  /// Resolve stored JWT before logout so the request carries credentials.
  Future<String?> _resolveJwtToken() async {
    try {
      final storedData = await UserManager.getStoredUserData();
      final directToken = _pickTokenFromMap(storedData);
      if (directToken != null) {
        return directToken;
      }

      final rawAuth = await _secureStorage.read(key: _secureAuthStorageKey);
      if (rawAuth == null || rawAuth.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(rawAuth);
      final decodedMap = _normalizeDynamicMap(decoded);
      final decodedToken = _pickTokenFromMap(decodedMap);
      if (decodedToken != null) {
        return decodedToken;
      }

      final tokensMap = _normalizeDynamicMap(decodedMap?['tokens']);
      final tokenFromTokens = _pickTokenFromMap(tokensMap);
      if (tokenFromTokens != null) {
        return tokenFromTokens;
      }

      final payloadMap = _normalizeDynamicMap(decodedMap?['payload']);
      return _pickTokenFromMap(payloadMap);
    } catch (error) {
      debugPrint('Failed to resolve logout token: ${error.toString()}');
      return null;
    }
  }

  Map<String, dynamic>? _normalizeDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  String? _pickTokenFromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return null;
    }

    const keys = [
      'jwtToken',
      'jwt_token',
      'accessToken',
      'access_token',
      'token',
    ];

    for (final key in keys) {
      final candidate = _asNonEmptyString(data[key]);
      if (candidate != null) {
        return candidate;
      }
    }

    return null;
  }

  String? _asNonEmptyString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      final asString = value.toString();
      return asString.isEmpty ? null : asString;
    }
    return null;
  }

  /// Debounce helper to prevent repeated taps and toasts.
  /// 防抖函数 - 防止用户快速重复点击和重复显示提示
  void _debounceButtonClick(VoidCallback action) {
    if (!_isButtonClickable || _isToastVisible) return;

    setState(() {
      _isButtonClickable = false;
      _isToastVisible = true;
    });

    // 执行操作
    action();

    // 1秒后重置点击状态
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isButtonClickable = true;
        });
      }
    });

    // 2秒后重置提示状态（与SnackBar显示时间同步）
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isToastVisible = false;
        });
      }
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    // 显示确认对话框
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认退出'),
        content: Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              '退出',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        final jwtToken = await _resolveJwtToken();
        await _gatewayService.logout(jwtToken: jwtToken);
      } catch (error) {
        // 忽略退出过程中的网络异常
      }

      // 清除登录状态
      await UserManager.clearLoginState();

      // 显示退出成功提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已退出登录')),
        );
      }

      // 通知父页面更新状态
      widget.onLogout();

      // 返回主页
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayNickname =
        (_nickname?.isNotEmpty ?? false) ? _nickname! : widget.username;
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5), // 浅灰色背景
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '个人中心',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 15), // 减少顶部间距：30→15

            // 用户信息区域 - 白色背景，无阴影
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 20), // 减少容器内间距：30→20
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  // 用户头像 - 蓝色圆形
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 12), // 减少头像到用户名间距：16→12

                  // 用户名显示
                  Text(
                    widget.username,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6), // 减少用户名间距：8→6

                  // 灰色用户名重复显示（如图片中的样式）
                  Text(
                    displayNickname,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 15), // 减少到菜单间距：20→15

            // 功能菜单 - 白色背景，简洁设计
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  // _buildMenuItem(
                  //   context,
                  //   icon: Icons.settings,
                  //   title: '会议设置',
                  //   onTap: () {
                  //     _debounceButtonClick(() {
                  //       ScaffoldMessenger.of(context).showSnackBar(
                  //         SnackBar(content: Text('会议设置功能开发中...')),
                  //       );
                  //     });
                  //   },
                  // ),
                  // _buildDivider(),
                  // _buildMenuItem(
                  //   context,
                  //   icon: Icons.lock,
                  //   title: '修改密码',
                  //   onTap: () {
                  //     _debounceButtonClick(() {
                  //       ScaffoldMessenger.of(context).showSnackBar(
                  //         SnackBar(content: Text('修改密码功能开发中...')),
                  //       );
                  //     });
                  //   },
                  // ),
                  // _buildDivider(),
                  _buildMenuItem(
                    context,
                    icon: Icons.system_update,
                    title: '系统更新',
                    trailing: Text(
                      'v${VersionConfig.versionNumber}',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () async {
                      _debounceButtonClick(() async {
                        // 使用AppUpdater的热更新功能
                        await AppUpdater.checkAndUpdate(context);
                      });
                    },
                  ),
                  _buildDivider(),
                  // _buildMenuItem(
                  //   context,
                  //   icon: Icons.help,
                  //   title: '帮助教程',
                  //   onTap: () {
                  //     _debounceButtonClick(() {
                  //       ScaffoldMessenger.of(context).showSnackBar(
                  //         SnackBar(content: Text('帮助教程功能开发中...')),
                  //       );
                  //     });
                  //   },
                  // ),
                ],
              ),
            ),

            SizedBox(height: 40),

            // 退出登录按钮 - 绿色背景
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _handleLogout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '退出登录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// 构建菜单项 - 简洁风格，右侧箭头
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Colors.grey[600],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }

  /// 构建分割线
  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.only(left: 60),
      child: Divider(
        height: 1,
        color: Colors.grey[200],
      ),
    );
  }
}
