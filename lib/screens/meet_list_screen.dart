import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'video_conference_screen.dart';
import 'simple_profile_screen.dart';
import 'login_register_screen.dart';

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

// 首页 - 会议列表
class MeetListPage extends StatefulWidget {
  const MeetListPage({super.key});

  @override
  State<MeetListPage> createState() => _MeetListPageState();
}

class _MeetListPageState extends State<MeetListPage> with TickerProviderStateMixin {
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

    // 跳转到直播间界面
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
        preferredSize: Size.fromHeight(42), // 增加AppBar高度到42像素 (38+4)
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
                  radius: 12, // 改为12，直径24像素
                  backgroundColor: _isLoggedIn ? Colors.blue : Colors.grey[300],
                  child: Icon(
                    Icons.person,
                    color: _isLoggedIn ? Colors.white : Colors.grey[600],
                    size: 15, // 只减少1px：16 → 15
                  ),
                ),
              ),
            ),
          ],
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 42, // 设置工具栏高度到42像素 (38+4)
        ),
      ),
      backgroundColor: Color(0xFFF5F5F5),
      body: Stack(
        children: [
          ListView.builder(
        padding: EdgeInsets.only(left: 0, right: 0, top: 8, bottom: 24), // 顶部8px，底部24px，配合卡片margin形成顶部16px、底部32px间隙
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