import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_updater.dart';
import '../config/version_config.dart';

/// 简洁个人中心界面 - 与图片样式完全匹配的版本
/// 这是从 main.dart 中提取的 UserProfilePage 类
/// 特点：简洁的白色背景，无阴影，纯净的UI设计
class SimpleProfileScreen extends StatelessWidget {
  final String username;
  final VoidCallback onLogout;

  const SimpleProfileScreen({
    super.key,
    required this.username,
    required this.onLogout,
  });

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
      // 清除登录状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
      await prefs.remove('username');

      // 显示退出成功提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已退出登录')),
        );
      }

      // 通知父页面更新状态
      onLogout();

      // 返回主页面
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    username,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 6), // 减少用户名间距：8→6

                  // 灰色用户名重复显示（如图片中的样式）
                  Text(
                    username,
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
                  _buildMenuItem(
                    context,
                    icon: Icons.settings,
                    title: '会议设置',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('会议设置功能开发中...')),
                      );
                    },
                  ),
                  _buildDivider(),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.lock,
                    title: '修改密码',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('修改密码功能开发中...')),
                      );
                    },
                  ),
                  _buildDivider(),
                  
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
                      // 使用AppUpdater的热更新功能
                      await AppUpdater.checkAndUpdate(context);
                    },
                  ),
                  _buildDivider(),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.help,
                    title: '帮助教程',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('帮助教程功能开发中...')),
                      );
                    },
                  ),
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