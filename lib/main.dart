import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/video_conference_screen.dart';
import 'screens/simple_profile_screen.dart';
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
        // 设置应用栏主题
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.blue, // 状态栏背景色设为蓝色
            statusBarIconBrightness: Brightness.light, // 状态栏图标为白色
            statusBarBrightness: Brightness.dark, // iOS状态栏内容为白色
          ),
        ),
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
  bool _isMeetingCardClickable = true; // 防抖标志

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
      // 已登录 - 使用简洁的个人中心页面
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleProfileScreen(
            username: _currentUsername,
            onLogout: _onLogout,
          ),
        ),
      );
    } else {
      // 未登录 - 弹出下拉菜单
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

  void _handleMeetingCardTap(String title, bool isActive) {
    // 防抖处理
    if (!_isMeetingCardClickable) return;

    setState(() {
      _isMeetingCardClickable = false;
    });

    if (isActive) {
      // 进行中的会议 - 弹出邀请码面板
      _showInviteCodePanel(title);
    } else {
      // 已结束的会议 - 显示结束提示
      _showMeetingEndedMessage();
    }

    // 1秒后重置点击状态
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isMeetingCardClickable = true;
        });
      }
    });
  }

  void _showMeetingEndedMessage() {
    // 先清除现有的Banner，避免叠加
    ScaffoldMessenger.of(context).clearMaterialBanners();

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 14,
              ),
            ),
            SizedBox(width: 12),
            Text(
              '会议已结束！',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF424242),
        actions: [Container()], // 必须要有actions，但设置为空容器
      ),
    );

    // 2秒后自动隐藏
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
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
        builder: (context) => LoginRegisterPage(
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(38), // 进一步减少AppBar高度到48*4/5=38
        child: AppBar(
          leading: Container(
            margin: EdgeInsets.only(left: 10),
            child: Image.asset(
              'assets/images/logo.png',
              height: 17, // 扩大1/5：14 * 1.2 = 16.8 ≈ 17
              fit: BoxFit.contain,
            ),
          ),
          leadingWidth: 86, // 扩大1/5：72 * 1.2 = 86.4 ≈ 86
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 10), // 进一步减少右边距到12*4/5=10
              child: GestureDetector(
                onTap: _handleUserIconTap,
                child: CircleAvatar(
                  radius: 14, // 扩大1/5：12 * 1.2 = 14.4 ≈ 14
                  backgroundColor: _isLoggedIn ? Colors.blue : Colors.grey[300],
                  child: Icon(
                    Icons.person,
                    color: _isLoggedIn ? Colors.white : Colors.grey[600],
                    size: 16, // 扩大1/5：13 * 1.2 = 15.6 ≈ 16
                  ),
                ),
              ),
            ),
          ],
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 38, // 设置工具栏高度到38
        ),
      ),
      backgroundColor: Color(0xFFF5F5F5),
      body: Stack(
        children: [
          ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8), // 上下各8px，配合卡片的8px margin形成16px间隙
        itemCount: 4,
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
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 背景图片区域
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Stack(
              children: [
                // 背景图
                Image.asset(
                  'assets/images/card_thumb_bg.webp',
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                ),
                
                // 状态标签 - 右上角
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                
                // 中央播放按钮
                Positioned.fill(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _handleMeetingCardTap(title, isActive),
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 底部信息区域 - 白色背景
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '云会议 - ID: $roomId',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: Colors.grey[300],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      '主持人：$host',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Spacer(),
                    GestureDetector(
                      onTap: () => _handleMeetingCardTap(title, isActive),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '进入',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
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



