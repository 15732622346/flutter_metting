import 'package:flutter/material.dart';

/// 版本配置
/// 用于区分旧版本和新版本，方便测试热更新功能
class VersionConfig {
  
  // ==================== 版本标识配置 ====================
  
  /// 当前版本类型
  /// true: 新版本 (上传到服务器)
  /// false: 旧版本 (安装到手机测试)
  static const bool IS_NEW_VERSION = false; // 修改这里来切换版本
  
  /// 版本显示文本
  static String get versionText => IS_NEW_VERSION ? '🟢 新版本' : '🔵 旧版本';
  
  /// 版本背景色
  static const Color newVersionColor = Color(0xFF4CAF50); // 绿色
  static const Color oldVersionColor = Color(0xFF2196F3); // 蓝色
  
  /// 获取版本背景色
  static Color get versionColor => IS_NEW_VERSION ? newVersionColor : oldVersionColor;
  
  /// 版本描述
  static String get versionDescription => IS_NEW_VERSION 
    ? '最新功能版本'
    : '基础功能版';
    
  /// 版本号（与pubspec.yaml保持一致）
  static String get versionNumber => IS_NEW_VERSION ? '2.0.0' : '1.0.0';
  
  // ==================== 功能开关 ====================
  
  /// 是否显示版本浮动框
  static const bool SHOW_VERSION_FLOAT = true;
  
  /// 是否显示新功能提示
  static bool get showNewFeatureTip => IS_NEW_VERSION;
}