import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_updater.dart';
import '../config/version_config.dart';

/// 热更新管理器
/// 负责管理应用的热更新功能，包括版本检查、下载和安装
class HotUpdateManager {
  static final HotUpdateManager _instance = HotUpdateManager._internal();
  static HotUpdateManager get instance => _instance;

  HotUpdateManager._internal();

  Timer? _autoCheckTimer;
  bool _isInitialized = false;
  bool _isChecking = false;

  // 配置参数
  static const int autoCheckInterval = 30; // 30分钟检查一次
  static const bool autoDownload = false; // 不自动下载，需要用户确认

  /// 初始化热更新管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 标记为已初始化
      _isInitialized = true;

      if (kDebugMode) {
        print('HotUpdateManager: 初始化完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('HotUpdateManager: 初始化失败 - $e');
      }
    }
  }
  
  /// 启动自动检查
  void startAutoCheck() {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('HotUpdateManager: 未初始化，无法启动自动检查');
      }
      return;
    }

    // 停止之前的定时器
    stopAutoCheck();

    // 设置定时器，每隔指定时间检查一次更新
    _autoCheckTimer = Timer.periodic(
      Duration(minutes: autoCheckInterval),
      (timer) => _performAutoCheck(),
    );

    // 立即执行一次检查
    _performAutoCheck();

    if (kDebugMode) {
      print('HotUpdateManager: 自动检查已启动，间隔 $autoCheckInterval 分钟');
    }
  }
  
  /// 停止自动检查
  void stopAutoCheck() {
    _autoCheckTimer?.cancel();
    _autoCheckTimer = null;
    
    if (kDebugMode) {
      print('HotUpdateManager: 自动检查已停止');
    }
  }
  
  /// 执行自动检查
  Future<void> _performAutoCheck() async {
    if (_isChecking) return;

    _isChecking = true;

    try {
      // 检查是否需要更新
      final updateInfo = await checkForUpdate();

      if (updateInfo['hasUpdate'] == true) {
        if (kDebugMode) {
          print('HotUpdateManager: 发现新版本');
        }

        // 根据配置决定是否自动下载
        if (autoDownload) {
          // 这里可以添加自动下载逻辑
          if (kDebugMode) {
            print('HotUpdateManager: 自动下载功能已禁用，需要用户手动确认');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('HotUpdateManager: 自动检查失败 - $e');
      }
    } finally {
      _isChecking = false;
    }
  }

  /// 检查更新
  Future<Map<String, dynamic>> checkForUpdate() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      return await AppUpdater.checkForUpdate();
    } catch (e) {
      if (kDebugMode) {
        print('HotUpdateManager: 检查更新失败 - $e');
      }
      return {
        'hasUpdate': false,
        'error': '检查更新失败: $e'
      };
    }
  }
  
  /// 下载更新（暂不支持，需要通过UI触发）
  Future<bool> downloadUpdate() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (kDebugMode) {
        print('HotUpdateManager: 下载更新需要通过UI界面触发');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('HotUpdateManager: 下载更新失败 - $e');
      }
      return false;
    }
  }

  /// 安装更新（暂不支持，需要通过UI触发）
  Future<bool> installUpdate() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (kDebugMode) {
        print('HotUpdateManager: 安装更新需要通过UI界面触发');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('HotUpdateManager: 安装更新失败 - $e');
      }
      return false;
    }
  }
  
  /// 获取当前版本信息
  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      if (kDebugMode) {
        print('HotUpdateManager: 获取版本信息失败 - $e');
      }
      return 'Unknown';
    }
  }
  
  /// 获取最新版本信息
  Future<String?> getLatestVersion() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final updateInfo = await AppUpdater.checkForUpdate();
      return updateInfo['latestVersion'];
    } catch (e) {
      if (kDebugMode) {
        print('HotUpdateManager: 获取最新版本失败 - $e');
      }
      return null;
    }
  }
  
  /// 清理资源
  void dispose() {
    stopAutoCheck();
    _isInitialized = false;
    
    if (kDebugMode) {
      print('HotUpdateManager: 资源已清理');
    }
  }
}
