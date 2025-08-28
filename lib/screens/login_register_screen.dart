import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// 登录注册页面
class LoginRegisterPage extends StatefulWidget {
  final bool isRegister;
  final Function(String)? onLoginSuccess;

  const LoginRegisterPage({
    super.key,
    required this.isRegister,
    this.onLoginSuccess,
  });

  @override
  State<LoginRegisterPage> createState() => _LoginRegisterPageState();
}

class _LoginRegisterPageState extends State<LoginRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isCameraEnabled = false;
  bool _isMicrophoneEnabled = true;
  late bool _isRegisterMode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isRegisterMode = widget.isRegister;
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String account = _accountController.text.trim();
      String password = _passwordController.text.trim();

      if (_isRegisterMode) {
        // 注册逻辑
        String confirmPassword = _confirmPasswordController.text.trim();

        if (password != confirmPassword) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('两次密码输入不一致')),
          );
          return;
        }

        // 模拟注册请求
        await Future.delayed(Duration(seconds: 1));

        // 显示注册成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注册成功，请登录')),
        );

        // 切换到登录模式
        setState(() {
          _isRegisterMode = false;
          _accountController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      } else {
        // 登录逻辑
        // 模拟登录请求
        await Future.delayed(Duration(seconds: 1));

        // 保存登录状态
        await UserManager.saveLoginState(account);

        // 通知父页面登录成功
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!(account);
        }

        // 显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录成功')),
        );

        // 返回主页面
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_isRegisterMode ? "注册" : "登录"}失败：${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _accountController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5), // 浅灰色背景，让卡片更突出
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isRegisterMode ? '用户注册' : '个人中心',
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
        padding: EdgeInsets.zero, // 左右不留间隙
        child: Column(
          children: [
            SizedBox(height: 8), // 顶部留8px间隙

            // 主内容卡片容器
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              padding: EdgeInsets.all(10), // 内边距改为10px
              child: Column(
                children: [
                  // 登录表单内容
                  _buildLoginForm(),
                  SizedBox(height: 10), // 登录表单与设置区域之间的间隙

                  // 设置开关区域
                  _buildSettingsSection(),
                ],
              ),
            ),

            SizedBox(height: 20), // 底部间距
          ],
        ),
      ),
    );
  }

  // 构建登录表单
  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // 用户名输入框
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextFormField(
              controller: _accountController,
              decoration: InputDecoration(
                hintText: _isRegisterMode ? '请输入注册账号' : '请输入登录账号',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
          ),

          SizedBox(height: 10), // 两个输入框之间的间隙改为10px

          // 密码输入框
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: _isRegisterMode ? '请输入注册密码' : '请输入登录密码',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
            ),
          ),

          // 确认密码输入框（仅注册模式显示）
          if (_isRegisterMode) ...[
            SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: '请确认注册密码',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintStyle: TextStyle(color: Colors.grey[500]),
                ),
                validator: (value) {
                  if (_isRegisterMode && (value == null || value.isEmpty)) {
                    return '请确认密码';
                  }
                  if (_isRegisterMode && value != _passwordController.text) {
                    return '两次密码输入不一致';
                  }
                  return null;
                },
              ),
            ),
          ],

        SizedBox(height: 10), // 与登录按钮之间的间隙

        // 登录/注册按钮
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF007AFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  _isRegisterMode ? '注册' : '登录',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
          ),
        ),

        SizedBox(height: 10), // 登录按钮与注册链接之间的间隙改为10px

        // 注册链接（带边框）
        Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _isRegisterMode ? '已有账号？' : '没有账号？',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
              GestureDetector(
                onTap: _toggleMode,
                child: Text(
                  _isRegisterMode ? '点我登录' : '点我注册',
                  style: TextStyle(
                    color: Color(0xFF007AFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  // 构建设置开关区域
  Widget _buildSettingsSection() {
    return Column(
      children: [
        // 开启摄像头
        _buildSettingItem(
          title: '开启摄像头',
          value: _isCameraEnabled,
          onChanged: (value) {
            setState(() {
              _isCameraEnabled = value;
            });
          },
        ),

        SizedBox(height: 5), // 开启摄像头与分割线之间的间隙

        // 分割线
        Divider(
          height: 1,
          color: Colors.grey[300],
          thickness: 1,
        ),

        SizedBox(height: 5), // 分割线与开启麦克风之间的间隙

        // 开启麦克风
        _buildSettingItem(
          title: '开启麦克风',
          value: _isMicrophoneEnabled,
          onChanged: (value) {
            setState(() {
              _isMicrophoneEnabled = value;
            });
          },
        ),
      ],
    );
  }

  // 构建单个设置项
  Widget _buildSettingItem({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.green,
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[300],
        ),
      ],
    );
  }

}