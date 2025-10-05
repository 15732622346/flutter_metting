import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';
import '../config/version_config.dart';

/// Flutter应用热更新管理器
/// 基于OTA_UPDATE实现APK文件的下载和安装
class AppUpdater {
  
  // ==================== 配置参数 ====================
  
  /// 版本检查API地址 - 根据平台选择不同的URL
  static String get VERSION_CHECK_URL {
    if (kIsWeb) {
      // Web 平台使用代理服务器
      return "http://localhost:3001/api/downloads/version-info.json";
    } else {
      // 移动端直接访问
      return "https://meet.pgm18.com/downloads/version-info.json";
    }
  }

  /// 备用API地址（容灾）
  static List<String> get BACKUP_VERSION_CHECK_URLS {
    if (kIsWeb) {
      return [
        "http://localhost:3001/api/downloads/version-info.json",
        "http://localhost:3001/api/api/version-check",
      ];
    } else {
      return [
        "https://meet.pgm18.com/downloads/version-info.json",
        "https://meet.pgm18.com/api/version-check",
      ];
    }
  }
  
  // ==================== 核心功能方法 ====================
  
  /// 获取当前应用版本号
  static Future<String> getCurrentVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      print('获取版本号失败: $e');
      // 如果获取失败，返回配置文件中的版本号
      return VersionConfig.versionNumber;
    }
  }
  
  /// 检查是否有更新（完全基于服务器API）
  static Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      print('当前应用版本: $currentVersion');
      
      // 尝试从服务器获取最新版本信息
      Map<String, dynamic>? serverInfo = await _fetchServerVersionInfo();
      
      if (serverInfo == null) {
        return {
          'hasUpdate': false,
          'error': '无法连接到更新服务器'
        };
      }
      
      final serverVersion = serverInfo['version'] ?? '1.0.0';
      final hasUpdate = _compareVersions(currentVersion, serverVersion);
      
      print('服务器版本: $serverVersion');
      print('版本比较结果: $currentVersion vs $serverVersion = ${hasUpdate ? "需要更新" : "无需更新"}');
      
      return {
        'hasUpdate': hasUpdate,
        'currentVersion': currentVersion,
        'latestVersion': serverVersion,
        'downloadUrl': serverInfo['download_url'] ?? '',
        'changelog': serverInfo['changelog'] ?? '版本更新',
        'fileSizeMB': serverInfo['file_size_mb']?.toString() ?? '40'
      };
      
    } catch (e) {
      print('检查更新失败: $e');
      return {
        'hasUpdate': false,
        'error': '检查更新失败: $e'
      };
    }
  }
  
  /// 从服务器获取版本信息（带容灾机制）
  static Future<Map<String, dynamic>?> _fetchServerVersionInfo() async {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 3);
    dio.options.receiveTimeout = const Duration(seconds: 3);

    // Web 平台特殊配置
    if (kIsWeb) {
      // 配置 Web 代理和 CORS 处理
      dio.options.headers.addAll({
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      });

      // 设置请求超时时间
      dio.options.connectTimeout = const Duration(seconds: 3);
      dio.options.receiveTimeout = const Duration(seconds: 3);
    }

    // 尝试主要URL
    try {
      print('尝试从主服务器获取版本信息: $VERSION_CHECK_URL');
      final response = await dio.get(VERSION_CHECK_URL);
      if (response.statusCode == 200 && response.data != null) {
        print('成功获取服务器版本信息');
        return response.data;
      }
    } catch (e) {
      print('主服务器请求失败: $e');
    }
    
    // 尝试备用URL
    for (String backupUrl in BACKUP_VERSION_CHECK_URLS) {
      try {
        print('尝试备用服务器: $backupUrl');
        final response = await dio.get(backupUrl);
        if (response.statusCode == 200 && response.data != null) {
          print('备用服务器请求成功');
          return response.data;
        }
      } catch (e) {
        print('备用服务器 $backupUrl 请求失败: $e');
        continue;
      }
    }
    
    print('所有服务器都无法访问');
    return null;
  }
  
  /// 执行应用更新下载和自动安装
  static Future<void> downloadAndAutoInstall(BuildContext context, String downloadUrl) async {
    try {
      if (downloadUrl.isEmpty) {
        _showToast('下载地址为空，无法更新');
        return;
      }
      
      print('开始下载APK: $downloadUrl');
      
      // 显示下载进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateProgressDialog(),
      );
      
      // 获取下载目录
      final directory = await getExternalStorageDirectory();
      final apkPath = '${directory!.path}/meeting_app_update.apk';
      
      // 使用Dio下载APK
      final dio = Dio();
      await dio.download(
        downloadUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          final progress = (received / total * 100).toInt();
          print('下载进度: $progress%');
          // TODO: 更新进度条UI
        },
      );
      
      print('APK下载完成: $apkPath');
      Navigator.of(context).pop(); // 关闭进度对话框
      
      // 自动打开安装界面
      await _openInstallInterface(context, apkPath);
      
    } catch (e) {
      print('更新失败: $e');
      Navigator.of(context).pop();
      _showToast('下载失败: $e');
    }
  }
  
  /// 自动打开安装界面
  static Future<void> _openInstallInterface(BuildContext context, String apkPath) async {
    try {
      print('正在打开安装界面: $apkPath');
      
      // 检查APK文件是否存在
      final file = File(apkPath);
      if (!await file.exists()) {
        _showToast('APK文件不存在');
        return;
      }
      
      // 检查并请求安装权限
      print('检查安装权限...');
      PermissionStatus status = await Permission.requestInstallPackages.status;
      
      if (status.isDenied) {
        print('请求安装权限...');
        status = await Permission.requestInstallPackages.request();
      }
      
      if (status.isDenied || status.isPermanentlyDenied) {
        _showToast('需要授予安装权限才能更新应用');
        return;
      }
      
      print('安装权限已获得');
      
      // 显示即将打开安装界面的提示
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.install_mobile, color: Colors.green),
              SizedBox(width: 8),
              Text('准备安装'),
            ],
          ),
          content: Text('下载完成！\n\n即将打开安装界面，请点击"安装"按钮完成更新。\n\n安装后您将获得最新功能！'),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // 使用OpenFile自动打开安装界面
                final result = await OpenFile.open(apkPath);
                
                if (result.type == ResultType.done) {
                  _showToast('安装界面已打开，请确认安装');
                } else {
                  _showToast('无法打开安装界面: ${result.message}');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('立即安装'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      print('打开安装界面失败: $e');
      _showToast('无法打开安装界面: $e');
    }
  }

  /// 执行应用更新下载和安装 (使用OTA_UPDATE)
  static Future<void> downloadAndInstall(BuildContext context, String downloadUrl) async {
    try {
      if (downloadUrl.isEmpty) {
        _showToast('下载地址为空，无法更新');
        return;
      }
      
      print('开始下载APK: $downloadUrl');
      
      // 显示下载进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => UpdateProgressDialog(),
      );
      
      // 使用OTA_UPDATE执行下载安装
      OtaUpdate().execute(
        downloadUrl,
        destinationFilename: 'meeting_app_update.apk',
      ).listen(
        (OtaEvent event) {
          print('下载进度: ${event.value}%');
          // TODO: 可以在这里更新进度条UI
        },
        onDone: () {
          print('APK下载完成');
          Navigator.of(context).pop(); // 关闭进度对话框
          
          // 显示安装完成提示
          _showInstallCompleteDialog(context);
        },
        onError: (error) {
          print('下载失败: $error');
          Navigator.of(context).pop(); // 关闭进度对话框
          
          _showToast('下载失败: $error');
        },
      );
      
    } catch (e) {
      print('更新失败: $e');
      Navigator.of(context).pop();
      _showToast('更新失败: $e');
    }
  }
  
  /// 一键检查并更新（推荐使用）
  static Future<void> checkAndUpdate(BuildContext context) async {
    try {
      // 显示检查中对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('检查更新中...'),
            ],
          ),
        ),
      );
      
      // 检查更新
      final updateInfo = await checkForUpdate();
      Navigator.of(context).pop(); // 关闭检查对话框
      
      if (updateInfo['hasUpdate'] == true) {
        // 显示更新确认对话框
        final shouldUpdate = await _showUpdateConfirmDialog(context, updateInfo);
        
        if (shouldUpdate == true) {
          final downloadUrl = updateInfo['downloadUrl'] ?? '';
          // 执行自动安装更新
          await downloadAndAutoInstall(context, downloadUrl);
        }
      } else {
        _showToast(updateInfo['error'] ?? '当前已是最新版本');
      }
      
    } catch (e) {
      Navigator.of(context).pop();
      _showToast('检查更新失败: $e');
    }
  }
  
  // ==================== 版本比较方法 ====================
  
  /// 比较版本号，返回是否需要更新
  /// 如果currentVersion < serverVersion，返回true
  static bool _compareVersions(String currentVersion, String serverVersion) {
    try {
      // 移除版本号中的非数字字符，只保留数字和点
      final currentClean = currentVersion.replaceAll(RegExp(r'[^\d\.]'), '');
      final serverClean = serverVersion.replaceAll(RegExp(r'[^\d\.]'), '');
      
      print('清理后的版本号: $currentClean vs $serverClean');
      
      // 分割版本号
      final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final serverParts = serverClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      // 补齐位数
      while (currentParts.length < 3) currentParts.add(0);
      while (serverParts.length < 3) serverParts.add(0);
      
      print('版本号数组: $currentParts vs $serverParts');
      
      // 逐位比较
      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < serverParts[i]) {
          return true; // 需要更新
        } else if (currentParts[i] > serverParts[i]) {
          return false; // 当前版本更高
        }
      }
      
      return false; // 版本相同
    } catch (e) {
      print('版本比较失败: $e');
      return true; // 发生错误时默认显示更新
    }
  }

  // ==================== 私有辅助方法 ====================
  
  /// 显示更新确认对话框
  static Future<bool?> _showUpdateConfirmDialog(BuildContext context, Map<String, dynamic> updateInfo) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue),
            SizedBox(width: 8),
            Text('发现新版本'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本: ${updateInfo['currentVersion']}'),
            Text('最新版本: ${updateInfo['latestVersion']}'),
            SizedBox(height: 8),
            Text('文件大小: ${updateInfo['fileSizeMB']}MB'),
            SizedBox(height: 12),
            Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              updateInfo['changelog'] ?? '功能优化和Bug修复',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('稍后更新'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('立即更新'),
          ),
        ],
      ),
    );
  }
  
  /// 显示安装完成对话框
  static void _showInstallCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('更新完成'),
          ],
        ),
        content: Text('新版本下载完成！\\n\\n系统将弹出安装提示，请点击"安装"以完成更新。\\n\\n更新后您将获得最新功能！'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('好的'),
          ),
        ],
      ),
    );
  }
  
  /// 显示Toast提示
  static void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey[800],
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}

/// 更新进度对话框组件
class UpdateProgressDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          SizedBox(height: 20),
          Text(
            '正在下载更新...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text(
            '包含最新功能优化',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          SizedBox(height: 12),
          Text(
            '请保持网络连接，稍等片刻',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}