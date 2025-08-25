import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../providers/auth_provider.dart';
import '../providers/meeting_provider.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';
import 'video_conference_screen.dart';
import 'register_screen.dart';

/// 登录界面 - 基于原型图66666666666.png
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _cameraEnabled = true;
  bool _micEnabled = true;
  bool _rememberUser = false;
  int _currentPageIndex = 2; // 默认在"我的"页面
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: _currentPageIndex);
    _loadRememberedUser();
  }
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  /// 加载记住的用户
  Future<void> _loadRememberedUser() async {
    final authProvider = context.read<AuthProvider>();
    final username = await authProvider.getRememberedUsername();
    if (username != null) {
      _usernameController.text = username;
      _rememberUser = true;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _buildPersonalCenter(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
  
  /// 构建个人中心页面（匹配原型图）
  Widget _buildPersonalCenter() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 页面标题
                  const SizedBox(height: 20),
                  const Text(
                    '个人中心',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // 用户头像
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // 用户名显示
                  Text(
                    _usernameController.text.isNotEmpty 
                        ? _usernameController.text 
                        : '请登录',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // 登录表单
                  _buildLoginForm(authProvider),
                  
                  const SizedBox(height: 30),
                  
                  // 权限设置
                  _buildPermissionSettings(),
                  
                  if (authProvider.lastError != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        authProvider.lastError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// 构建登录表单
  Widget _buildLoginForm(AuthProvider authProvider) {
    return Column(
      children: [
        // 用户名输入框
        TextFormField(
          controller: _usernameController,
          decoration: InputDecoration(
            hintText: '请输入登录账号',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return '请输入用户名';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // 密码输入框
        TextFormField(
          controller: _passwordController,
          decoration: InputDecoration(
            hintText: '请输入登录密码',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
          obscureText: true,
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return '请输入密码';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 12),
        
        // 记住用户选项
        Row(
          children: [
            Checkbox(
              value: _rememberUser,
              onChanged: (value) {
                setState(() {
                  _rememberUser = value ?? false;
                });
              },
            ),
            const Text('记住用户'),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // 登录按钮
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: authProvider.isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: authProvider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '登录',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // 注册链接
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('没有账号？'),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
                  ),
                );
              },
              child: const Text('点击注册'),
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建权限设置
  Widget _buildPermissionSettings() {
    return Column(
      children: [
        // 开启摄像头
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SwitchListTile(
            title: const Text('开启摄像头'),
            value: _cameraEnabled,
            onChanged: (value) {
              setState(() {
                _cameraEnabled = value;
              });
            },
            activeColor: Colors.green,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 开启麦克风
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SwitchListTile(
            title: const Text('开启麦克风'),
            value: _micEnabled,
            onChanged: (value) {
              setState(() {
                _micEnabled = value;
              });
            },
            activeColor: Colors.green,
          ),
        ),
      ],
    );
  }
  
  /// 构建底部导航栏
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentPageIndex,
      onTap: (index) {
        setState(() {
          _currentPageIndex = index;
        });
        
        if (index == 1) {
          // 加入会议
          _showJoinMeetingDialog();
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: '首页',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          label: '加入会议',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: '我的',
        ),
      ],
    );
  }
  
  /// 处理登录
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // 显示房间码输入对话框
    final roomCode = await _showJoinMeetingDialog();
    if (roomCode == null) return;
    
    final authProvider = context.read<AuthProvider>();
    final meetingProvider = context.read<MeetingProvider>();
    
    try {
      // 保存记住用户设置
      await authProvider.setRememberUser(_usernameController.text, _rememberUser);
      
      // 执行登录
      final response = await authProvider.loginToRoom(
        username: _usernameController.text,
        password: _passwordController.text,
        roomId: roomCode,
      );
      
      if (response.isValidLogin && response.token != null) {
        // 登录成功，创建房间和用户对象
        final room = Room(
          roomId: roomCode,
          roomName: response.roomName ?? roomCode,
          userId: response.validUserId!,
          roomState: 1,
          audioState: 1,
          cameraState: 1,
          chatState: 1,
          inviteCode: '1315', // 默认邀请码
          maxMicSlots: 8,
          createTime: DateTime.now(),
        );
        
        final user = User(
          id: response.validUserId!,
          userName: _usernameController.text,
          userRoles: response.userRoles!,
          userNickname: response.nickname,
          userStatus: 1,
          isOnline: 1,
          currentRoom: roomCode,
        );
        
        // 导航到视频会议页面
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => VideoConferenceScreen(
              token: response.token!,
              wsUrl: response.wsUrl!,
              room: room,
              user: user,
            ),
          ),
        );
        
        Fluttertoast.showToast(
          msg: response.displayMessage,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: response.displayError,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '登录失败: $e',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
  
  /// 显示加入会议对话框（匹配原型图8888888888888888888.png）
  Future<String?> _showJoinMeetingDialog() async {
    final controller = TextEditingController();
    bool cameraEnabled = _cameraEnabled;
    bool micEnabled = _micEnabled;
    
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('加入会议'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 会议码输入
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '输入会议码',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              
              const SizedBox(height: 16),
              
              // 已有账号？登录
              Row(
                children: [
                  const Text('已有账号？'),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // 这里应该跳转到登录页面，但当前已在登录页面
                    },
                    child: const Text('登录'),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // 注册账号链接
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('注册账号'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 开启摄像头
              SwitchListTile(
                title: const Text('开启摄像头'),
                value: cameraEnabled,
                onChanged: (value) {
                  setDialogState(() {
                    cameraEnabled = value;
                  });
                  setState(() {
                    _cameraEnabled = value;
                  });
                },
                dense: true,
              ),
              
              // 开启麦克风
              SwitchListTile(
                title: const Text('开启麦克风'),
                value: micEnabled,
                onChanged: (value) {
                  setDialogState(() {
                    micEnabled = value;
                  });
                  setState(() {
                    _micEnabled = value;
                  });
                },
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isEmpty) {
                  // 显示错误提示（匹配原型图9999999999999999999.png）
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('需要有邀请码!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, controller.text);
              },
              child: const Text('验证'),
            ),
          ],
        ),
      ),
    );
  }
}