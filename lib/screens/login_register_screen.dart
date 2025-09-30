import 'dart:convert';
import 'package:flutter/material.dart';

import '../core/user_manager.dart';
import '../services/gateway_api_service.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GatewayApiService _gatewayService = GatewayApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _secureAuthKey = AuthProvider.secureAuthKey;

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
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final username = _accountController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isRegisterMode) {
        final nickname = _nicknameController.text.trim();
        final confirmPassword = _confirmPasswordController.text.trim();
        if (nickname.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('请输入昵称')),
          );
          return;
        }
        if (password != confirmPassword) {
          messenger.showSnackBar(
            const SnackBar(content: Text('两次输入的密码不一致，请重新确认')),
          );
          return;
        }
        if (password.length < 6) {
          messenger.showSnackBar(
            const SnackBar(content: Text('密码长度至少 6 位')),
          );
          return;
        }

        final registerResult = await _gatewayService.register(
          username: username,
          password: password,
          nickname: nickname,
        );

        if (!registerResult.success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(registerResult.error ??
                  registerResult.message ??
                  '注册失败，请稍后重试'),
            ),
          );
          return;
        }

        final autoLoginResult = await _gatewayService.login(
          username: username,
          password: password,
        );

        if (!autoLoginResult.success || !autoLoginResult.hasJwtToken) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                autoLoginResult.error ??
                    autoLoginResult.message ??
                    '注册成功，但自动登录失败，请手动登录',
              ),
            ),
          );
          setState(() {
            _isRegisterMode = false;
            _accountController.text = username;
            _nicknameController.clear();
            _passwordController.clear();
            _confirmPasswordController.clear();
          });
          return;
        }

        await _completeLoginFlow(
          loginResult: autoLoginResult,
          fallbackUsername: username,
          messenger: messenger,
          successMessage: registerResult.message ?? '注册成功',
        );
        return;
      }

      final loginResult = await _gatewayService.login(
        username: username,
        password: password,
      );

      if (!loginResult.success || !loginResult.hasJwtToken) {
        messenger.showSnackBar(
          SnackBar(
            content:
                Text(loginResult.error ?? loginResult.message ?? '登录失败，请稍后重试'),
          ),
        );
        return;
      }

      await _completeLoginFlow(
        loginResult: loginResult,
        fallbackUsername: username,
        messenger: messenger,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text("${_isRegisterMode ? '注册' : '登录'}失败: $error"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeLoginFlow({
    required GatewayAuthResult loginResult,
    required String fallbackUsername,
    required ScaffoldMessengerState messenger,
    bool showSuccessMessage = true,
    String? successMessage,
  }) async {
    final resolvedUsername = (loginResult.userName?.trim().isNotEmpty ?? false)
        ? loginResult.userName!.trim()
        : fallbackUsername;

    await UserManager.saveLoginState(
      username: resolvedUsername,
      extraData: loginResult.toPublicJson(),
    );

    try {
      await _secureStorage.write(
        key: _secureAuthKey,
        value: jsonEncode(loginResult.toSecureJson()),
      );
    } catch (error) {
      debugPrint('Failed to persist secure auth data: ' + error.toString());
    }

    if (showSuccessMessage) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage ?? loginResult.message ?? '登录成功'),
        ),
      );
    }

    widget.onLoginSuccess?.call(resolvedUsername);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _accountController.clear();
      _nicknameController.clear();
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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

          if (_isRegisterMode) ...[
            // 昵称输入框
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextFormField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  hintText: '请输入昵称',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintStyle: TextStyle(color: Colors.grey[500]),
                ),
                validator: (value) {
                  if (_isRegisterMode &&
                      (value == null || value.trim().isEmpty)) {
                    return '请输入昵称';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 10),
          ],

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
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                hintStyle: TextStyle(color: Colors.grey[500]),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                if (_isRegisterMode && value.length < 6) {
                  return '密码长度至少 6 位';
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
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
