import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 负责统一管理本地持久化的登录状态和关联用户信息。
class UserManager {
  static const String _loginStateKey = 'isLoggedIn';
  static const String _usernameKey = 'username';
  static const String _userDataKey = 'userData';

  /// 保存登录状态以及额外的用户数据（如令牌、过期时间等）。
  static Future<void> saveLoginState({
    required String username,
    Map<String, dynamic>? extraData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginStateKey, true);
    await prefs.setString(_usernameKey, username);

    if (extraData != null && extraData.isNotEmpty) {
      final sanitized = <String, dynamic>{};
      extraData.forEach((key, value) {
        if (value == null) {
          return;
        }
        if (value is DateTime) {
          sanitized[key] = value.toIso8601String();
        } else {
          sanitized[key] = value;
        }
      });

      if (sanitized.isNotEmpty) {
        await prefs.setString(_userDataKey, jsonEncode(sanitized));
      } else {
        await prefs.remove(_userDataKey);
      }
    } else {
      await prefs.remove(_userDataKey);
    }
  }

  /// 读取当前的登录状态、用户名以及附加数据。
  static Future<Map<String, dynamic>> getLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_loginStateKey) ?? false;
    final username = prefs.getString(_usernameKey) ?? '';

    Map<String, dynamic>? userData;
    final rawUserData = prefs.getString(_userDataKey);
    if (rawUserData != null) {
      try {
        final decoded = jsonDecode(rawUserData);
        if (decoded is Map<String, dynamic>) {
          userData = decoded;
        }
      } catch (_) {
        userData = null;
      }
    }

    return {
      'isLoggedIn': isLoggedIn,
      'username': username,
      'userData': userData,
    };
  }

  /// 单独获取存储的扩展用户数据（若不存在则返回 null）。
  static Future<Map<String, dynamic>?> getStoredUserData() async {
    final state = await getLoginState();
    return state['userData'] as Map<String, dynamic>?;
  }

  /// 清除本地保存的登录状态与所有附加用户数据。
  static Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_loginStateKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userDataKey);
  }
}
