import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../models/login_response.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // 状态变量
  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _lastError;
  
  // Getters
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  
  // 权限检查
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isHost => _currentUser?.isHost ?? false;
  bool get isMember => _currentUser?.isMember ?? false;
  bool get isEnabled => _currentUser?.isEnabled ?? false;
  
  /// 初始化 - 检查本地存储的登录状态
  Future<void> initialize() async {
    try {
      _setLoading(true);
      
      // 尝试从安全存储中恢复用户信息
      final userJson = await _secureStorage.read(key: 'current_user');
      if (userJson != null) {
        final userData = Map<String, dynamic>.from(
          Map.from(userJson as Map)
        );
        _currentUser = User.fromJson(userData);
        _isLoggedIn = true;
        print('✅ 从本地存储恢复用户信息: ${_currentUser!.userName}');
      }
    } catch (e) {
      print('⚠️ 初始化用户状态失败: $e');
      await clearUserData();
    } finally {
      _setLoading(false);
    }
  }
  
  /// 登录到房间
  Future<LoginResponse> loginToRoom({
    required String username,
    required String password,
    required String roomId,
  }) async {
    try {
      _setLoading(true);
      _lastError = null;
      
      print('🚀 开始房间登录: $username -> $roomId');
      
      final response = await _apiService.loginToRoom(
        username: username,
        password: password,
        roomId: roomId,
      );
      
      if (response.isValidLogin) {
        // 创建用户对象
        _currentUser = User(
          id: response.validUserId!,
          userName: username,
          userRoles: response.userRoles!,
          userNickname: response.nickname,
          userStatus: 1, // 登录成功说明用户状态正常
          isOnline: 1,
          currentRoom: roomId,
        );
        
        _isLoggedIn = true;
        
        // 保存用户信息到安全存储
        await _saveUserData(_currentUser!);
        
        // 保存登录凭据（用于自动重连等）
        await _saveCredentials(username, password);
        
        print('✅ 房间登录成功: ${_currentUser!.userName}');
        notifyListeners();
        
        return response;
      } else {
        _lastError = response.displayError;
        print('❌ 房间登录失败: ${response.displayError}');
        return response;
      }
    } catch (e) {
      _lastError = e.toString();
      print('❌ 房间登录异常: $e');
      return LoginResponse(
        success: false,
        error: _lastError,
      );
    } finally {
      _setLoading(false);
    }
  }
  
  /// 注册新用户
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    try {
      _setLoading(true);
      _lastError = null;
      
      print('🚀 开始用户注册: $username');
      
      final result = await _apiService.register(
        username: username,
        password: password,
        nickname: nickname,
      );
      
      if (result['success']) {
        print('✅ 用户注册成功: $username');
      } else {
        _lastError = result['message'];
        print('❌ 用户注册失败: ${result['message']}');
      }
      
      return result;
    } catch (e) {
      _lastError = e.toString();
      print('❌ 用户注册异常: $e');
      return {
        'success': false,
        'message': _lastError,
      };
    } finally {
      _setLoading(false);
    }
  }
  
  /// 修改密码
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      _setLoading(true);
      _lastError = null;
      
      if (newPassword != confirmPassword) {
        _lastError = '两次输入的密码不一致';
        return false;
      }
      
      if (newPassword.length < 6) {
        _lastError = '新密码长度至少6位';
        return false;
      }
      
      final result = await _apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      
      if (result['success']) {
        print('✅ 密码修改成功');
        return true;
      } else {
        _lastError = result['message'];
        print('❌ 密码修改失败: ${result['message']}');
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      print('❌ 密码修改异常: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 更新用户信息
  Future<void> updateUser(User user) async {
    _currentUser = user;
    await _saveUserData(user);
    notifyListeners();
  }
  
  /// 登出
  Future<void> logout() async {
    try {
      _setLoading(true);
      
      // 清除所有存储的数据
      await clearUserData();
      
      _currentUser = null;
      _isLoggedIn = false;
      _lastError = null;
      
      print('✅ 用户已登出');
      notifyListeners();
    } catch (e) {
      print('⚠️ 登出时出错: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  /// 清除用户数据
  Future<void> clearUserData() async {
    try {
      await _secureStorage.delete(key: 'current_user');
      await _secureStorage.delete(key: 'user_credentials');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_username');
      await prefs.remove('remember_user');
      
      print('🗑️ 用户数据已清除');
    } catch (e) {
      print('⚠️ 清除用户数据失败: $e');
    }
  }
  
  /// 检查是否记住用户
  Future<String?> getRememberedUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberUser = prefs.getBool('remember_user') ?? false;
      if (rememberUser) {
        return prefs.getString('last_username');
      }
      return null;
    } catch (e) {
      print('⚠️ 获取记住的用户名失败: $e');
      return null;
    }
  }
  
  /// 设置记住用户
  Future<void> setRememberUser(String username, bool remember) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_user', remember);
      if (remember) {
        await prefs.setString('last_username', username);
      } else {
        await prefs.remove('last_username');
      }
    } catch (e) {
      print('⚠️ 设置记住用户失败: $e');
    }
  }
  
  /// 保存用户数据到安全存储
  Future<void> _saveUserData(User user) async {
    try {
      await _secureStorage.write(
        key: 'current_user',
        value: user.toJson().toString(),
      );
    } catch (e) {
      print('⚠️ 保存用户数据失败: $e');
    }
  }
  
  /// 保存登录凭据
  Future<void> _saveCredentials(String username, String password) async {
    try {
      await _secureStorage.write(
        key: 'user_credentials',
        value: '$username:$password', // 简单格式，实际应用中可能需要加密
      );
    } catch (e) {
      print('⚠️ 保存登录凭据失败: $e');
    }
  }
  
  /// 获取保存的凭据（用于自动重连等）
  Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final credentials = await _secureStorage.read(key: 'user_credentials');
      if (credentials != null) {
        final parts = credentials.split(':');
        if (parts.length == 2) {
          return {
            'username': parts[0],
            'password': parts[1],
          };
        }
      }
      return null;
    } catch (e) {
      print('⚠️ 获取保存的凭据失败: $e');
      return null;
    }
  }
  
  /// 设置加载状态
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }
  
  /// 清除错误信息
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }
}