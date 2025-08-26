import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/video_conference_screen.dart';
import 'services/app_updater.dart';
import 'core/hot_update_manager.dart';
import 'widgets/version_float_widget.dart';
import 'config/version_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化热更新管理器
  await HotUpdateManager.instance.initialize();
  
  
  // 启动自动检查热更新
  HotUpdateManager.instance.startAutoCheck();
  
  runApp(const VideoMeetingApp());
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

class VideoMeetingApp extends StatelessWidget {
  const VideoMeetingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '视频会议',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 首页 - 会议列表
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  bool _isUserMenuVisible = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  // 邀请码验证面板相关
  bool _isInviteCodePanelVisible = false;
  late AnimationController _inviteCodeAnimationController;
  late Animation<double> _inviteCodeSlideAnimation;
  final TextEditingController _inviteCodeController = TextEditingController();
  String _selectedMeetingTitle = '';

  // 用户登录状态
  bool _isLoggedIn = false;
  String _currentUsername = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // 邀请码面板动画控制器
    _inviteCodeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _inviteCodeSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _inviteCodeAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // 检查登录状态
    _checkLoginState();
  }

  Future<void> _checkLoginState() async {
    final loginState = await UserManager.getLoginState();
    setState(() {
      _isLoggedIn = loginState['isLoggedIn'];
      _currentUsername = loginState['username'];
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _inviteCodeAnimationController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _handleUserIconTap() {
    if (_isLoggedIn) {
      // 已登录 - 跳转到个人中心页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfilePage(
            username: _currentUsername,
            onLogout: _onLogout,
          ),
        ),
      );
    } else {
      // 未登录 - 显示登录注册抽屉
      _toggleUserMenu();
    }
  }

  void _toggleUserMenu() {
    setState(() {
      _isUserMenuVisible = !_isUserMenuVisible;
    });
    if (_isUserMenuVisible) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _onLogout() {
    setState(() {
      _isLoggedIn = false;
      _currentUsername = '';
    });
  }

  void _showInviteCodePanel(String meetingTitle) {
    setState(() {
      _isInviteCodePanelVisible = true;
      _selectedMeetingTitle = meetingTitle;
    });
    _inviteCodeAnimationController.forward();
  }

  void _hideInviteCodePanel() {
    _inviteCodeAnimationController.reverse().then((_) {
      setState(() {
        _isInviteCodePanelVisible = false;
        _inviteCodeController.clear();
      });
    });
  }

  void _verifyInviteCode() async {
    String code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      // 显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入邀请码')),
      );
      return;
    }

    // 这里可以添加实际的验证逻辑
    print('验证邀请码: $code，会议: $_selectedMeetingTitle');

    // 验证成功后关闭面板
    _hideInviteCodePanel();

    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('验证成功，正在进入直播间...')),
    );

    // 跳转到直播间界面
    await Future.delayed(Duration(milliseconds: 500)); // 短暂延迟显示提示
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoConferenceScreen(
          roomName: _selectedMeetingTitle ?? '未知房间',
          roomId: 'room_${DateTime.now().millisecondsSinceEpoch}',
          inviteCode: code,
        ),
      ),
    );
  }

  Future<void> _navigateToPersonalCenter(bool isRegister) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalCenterPage(
          isRegister: isRegister,
          onLoginSuccess: _onLoginSuccess,
        ),
      ),
    );
  }

  void _onLoginSuccess(String username) {
    setState(() {
      _isLoggedIn = true;
      _currentUsername = username;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Container(
          margin: EdgeInsets.only(left: 16),
          child: Image.asset(
            'assets/images/logo.png',
            height: 22.4,
            fit: BoxFit.contain,
          ),
        ),
        leadingWidth: 105,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _handleUserIconTap,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: _isLoggedIn ? Colors.blue : Colors.grey[300],
                child: Icon(
                  Icons.person,
                  color: _isLoggedIn ? Colors.white : Colors.grey[600],
                  size: 20,
                ),
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Color(0xFFF5F5F5),
      body: Stack(
        children: [
          ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        itemCount: 4,
        separatorBuilder: (context, index) => Container(
          height: 1,
          color: Color(0xFFE5E5E5),
        ),
        itemBuilder: (context, index) {
          return _buildMeetingCard(
            title: '# Tiktok流量与变现系统课 把握新机遇',
            roomId: 'r-8346bafa',
            host: 'wangwu',
            status: index == 3 ? '已结束' : '进行中',
            isActive: index != 3,
          );
        },
      ),
          
          // 版本标识浮动框 - 显示在页面中间
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0,
            right: 0,
            child: Center(
              child: VersionFloatWidget(),
            ),
          ),
          // 用户菜单下拉面板
          if (_isUserMenuVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -60 * (1 - _slideAnimation.value)),
                    child: Opacity(
                      opacity: _slideAnimation.value,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Color(0xFF2C2C2C),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 16),
                            if (_isLoggedIn) ...[
                              // 已登录状态 - 显示用户信息
                              Expanded(
                                child: Text(
                                  '欢迎，$_currentUsername',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ] else ...[
                              // 未登录状态 - 显示登录注册按钮
                              ElevatedButton(
                                onPressed: () {
                                  _toggleUserMenu();
                                  _navigateToPersonalCenter(true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: Text('注册', style: TextStyle(fontSize: 14)),
                              ),
                              SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  _toggleUserMenu();
                                  _navigateToPersonalCenter(false);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF4A4A4A),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child: Text('登录', style: TextStyle(fontSize: 14)),
                              ),
                            ],
                            Spacer(),
                            // 关闭按钮
                            GestureDetector(
                              onTap: _toggleUserMenu,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Text(
                                  '关闭',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          // 邀请码验证面板
          if (_isInviteCodePanelVisible)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _inviteCodeSlideAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // 半透明背景
                      Opacity(
                        opacity: _inviteCodeSlideAnimation.value * 0.5,
                        child: Container(
                          color: Colors.black,
                        ),
                      ),
                      // 底部面板
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -300 * (1 - _inviteCodeSlideAnimation.value),
                        child: Container(
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 顶部标题栏
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '邀请码验证',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _hideInviteCodePanel,
                                      child: Icon(
                                        Icons.close,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: Colors.grey[300]),
                              // 内容区域
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: 20),
                                      Text(
                                        '邀请码',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      TextField(
                                        controller: _inviteCodeController,
                                        decoration: InputDecoration(
                                          hintText: '请输入会议邀请码',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.grey[300]!),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(color: Colors.blue),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 30),
                                      // 验证按钮
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton(
                                          onPressed: _verifyInviteCode,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text(
                                            '点击验证',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeetingCard({
    required String title,
    required String roomId,
    required String host,
    required String status,
    required bool isActive,
  }) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          // 左侧图标和标签
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '云会议',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(width: 12),
          // 中间内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '房间ID：$roomId',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '主持人：$host',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 右侧状态和按钮
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.blue : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showInviteCodePanel(title),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '进入',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 个人中心页面
class PersonalCenterPage extends StatefulWidget {
  final bool isRegister;
  final Function(String)? onLoginSuccess;

  const PersonalCenterPage({
    super.key,
    required this.isRegister,
    this.onLoginSuccess,
  });

  @override
  State<PersonalCenterPage> createState() => _PersonalCenterPageState();
}

class _PersonalCenterPageState extends State<PersonalCenterPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isCameraEnabled = false;
  bool _isMicrophoneEnabled = true;
  late bool _isRegisterMode;

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
    String account = _accountController.text.trim();
    String password = _passwordController.text.trim();

    if (account.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isRegisterMode ? '请输入注册信息' : '请输入账号和密码')),
      );
      return;
    }

    if (_isRegisterMode) {
      // 注册逻辑
      String confirmPassword = _confirmPasswordController.text.trim();
      if (confirmPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请确认密码')),
        );
        return;
      }
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('两次输入的密码不一致')),
        );
        return;
      }

      // 检查密码强度
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('密码长度至少6位')),
        );
        return;
      }

      // 尝试注册
      bool success = UserDatabase.registerUser(account, password);
      if (success) {
        // 注册成功，自动登录
        await UserManager.saveLoginState(account);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('注册成功！')),
        );

        // 通知父页面登录成功
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!(account);
        }

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户名已存在，请选择其他用户名')),
        );
      }
    } else {
      // 登录逻辑
      bool success = UserDatabase.validateLogin(account, password);
      if (success) {
        // 登录成功
        await UserManager.saveLoginState(account);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录成功！')),
        );

        // 通知父页面登录成功
        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!(account);
        }

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('用户名或密码错误')),
        );
      }
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
      backgroundColor: Color(0xFFF5F5F5),
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
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(height: 20),
            // 登录表单
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 账号输入框
                  TextField(
                    controller: _accountController,
                    decoration: InputDecoration(
                      hintText: _isRegisterMode ? '请输入注册账号' : '请输入登录账号',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Color(0xFFF8F8F8),
                    ),
                  ),
                  SizedBox(height: 16),
                  // 密码输入框
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: _isRegisterMode ? '请输入注册密码' : '请输入登录密码',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Color(0xFFF8F8F8),
                    ),
                  ),
                  // 确认密码输入框（仅注册模式显示）
                  if (_isRegisterMode) ...[
                    SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '请确认注册密码',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Color(0xFFF8F8F8),
                      ),
                    ),
                  ],
                  SizedBox(height: 24),
                  // 提交按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isRegisterMode ? '注册' : '登录',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  // 模式切换链接
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRegisterMode ? '已有账号？' : '没有账号？',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleMode,
                        child: Text(
                          _isRegisterMode ? '点我登录' : '点我注册',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 30),
            // 设置选项
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 开启摄像头
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '开启摄像头',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      Switch(
                        value: _isCameraEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isCameraEnabled = value;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // 开启麦克风
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '开启麦克风',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      Switch(
                        value: _isMicrophoneEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isMicrophoneEnabled = value;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 用户个人中心页面（已登录状态）
class UserProfilePage extends StatelessWidget {
  final String username;
  final VoidCallback onLogout;

  const UserProfilePage({
    super.key,
    required this.username,
    required this.onLogout,
  });

  Future<void> _handleLogout(BuildContext context) async {
    // 清除登录状态
    await UserManager.clearLoginState();

    // 显示退出成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已退出登录')),
    );

    // 通知父页面更新状态
    onLogout();

    // 返回主页面
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
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
            SizedBox(height: 30),
            // 用户信息区域
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white,
              ),
              child: Column(
                children: [
                  // 用户头像
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                  // 用户名
                  Text(
                    username,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  // 用户ID
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
            SizedBox(height: 20),
            // 功能菜单
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
            // 退出登录按钮
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

