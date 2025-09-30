import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/user_manager.dart';
import '../models/room_model.dart';
import '../services/room_list_service.dart';
import '../models/room_join_data.dart';
import '../services/gateway_api_service.dart';
import '../providers/auth_provider.dart';
import 'video_conference_screen.dart';
import 'simple_profile_screen.dart';
import 'login_register_screen.dart';

// 首页 - 会议列表
class MeetListPage extends StatefulWidget {
  const MeetListPage({super.key});

  @override
  State<MeetListPage> createState() => _MeetListPageState();
}

class _MeetListPageState extends State<MeetListPage>
    with TickerProviderStateMixin {
  bool _isUserMenuVisible = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  final RoomListService _roomListService = RoomListService();
  final GatewayApiService _gatewayService = GatewayApiService();
  static const Duration _tokenRefreshSafetyWindow = Duration(minutes: 5);
  List<Room> _rooms = const <Room>[];
  bool _isLoadingRooms = false;
  String? _roomListError;

  // 邀请码验证面板相关
  bool _isInviteCodePanelVisible = false;
  late AnimationController _inviteCodeAnimationController;
  late Animation<double> _inviteCodeSlideAnimation;
  final TextEditingController _inviteCodeController = TextEditingController();
  String _selectedMeetingTitle = '';
  String _selectedRoomId = '';
  bool _isMeetingCardClickable = true; // 防抖标志
  bool _isInviteSubmitting = false;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _secureAuthKey = AuthProvider.secureAuthKey;

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

    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoadingRooms = true;
      _roomListError = null;
    });

    try {
      final rooms = await _roomListService.fetchRooms();
      if (!mounted) {
        return;
      }
      setState(() {
        _rooms = rooms;
        _isLoadingRooms = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _roomListError = _readableRoomError(error);
        _isLoadingRooms = false;
      });
    }
  }

  String _readableRoomError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
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

  void _showInviteCodePanel(String meetingTitle, String roomId) {
    setState(() {
      _isInviteCodePanelVisible = true;
      _selectedMeetingTitle = meetingTitle;
      _selectedRoomId = roomId;
      _isInviteSubmitting = false;
      _inviteCodeController.clear();
    });
    _inviteCodeAnimationController.forward();
  }

  void _hideInviteCodePanel() {
    _inviteCodeAnimationController.reverse().then((_) {
      setState(() {
        _isInviteCodePanelVisible = false;
        _inviteCodeController.clear();
        _selectedRoomId = '';
        _isInviteSubmitting = false;
      });
    });
  }

  void _handleMeetingCardTap(String title, String roomId, bool isActive) {
    // 防抖处理
    if (!_isMeetingCardClickable) return;

    setState(() {
      _isMeetingCardClickable = false;
    });

    if (isActive) {
      // 进行中的会议 - 弹出邀请码面板
      _showInviteCodePanel(title, roomId);
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

  String? _coalesceStrings(Map<String, dynamic>? source, List<String> keys) {
    if (source == null) {
      return null;
    }
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _resolveJwtToken(Map<String, dynamic>? stored) {
    final directToken = _coalesceStrings(
      stored,
      const ['jwtToken', 'jwt_token', 'accessToken', 'access_token'],
    );
    if (directToken != null && directToken.isNotEmpty) {
      return directToken;
    }

    final tokens = stored?['tokens'];
    if (tokens is Map<String, dynamic>) {
      final nested = _coalesceStrings(
        tokens.cast<String, dynamic>(),
        const ['access_token', 'jwt_token'],
      );
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
    return '';
  }

  Future<String> _ensureValidJwtToken(
    Map<String, dynamic> stored,
    String fallbackUsername,
  ) async {
    String currentToken = _resolveJwtToken(stored);
    if (currentToken.isEmpty) {
      final fallbackSecure = await _secureStorage.read(key: _secureAuthKey);
      if (fallbackSecure != null && fallbackSecure.isNotEmpty) {
        try {
          final decoded = jsonDecode(fallbackSecure);
          if (decoded is Map<String, dynamic>) {
            stored.addAll(Map<String, dynamic>.from(decoded));
            currentToken = _resolveJwtToken(stored);
          }
        } catch (_) {
          // ignore malformed secure payload
        }
      }
    }
    if (currentToken.isEmpty) {
      return currentToken;
    }

    final expiresAt = _parseDateValue(
          stored['accessExpiresAt'] ?? stored['access_expires_at'],
        ) ??
        _parseDateValue(
          (stored['tokens'] as Map<String, dynamic>?)?['access_expires_at'],
        ) ??
        _decodeJwtExpiry(currentToken);

    final now = DateTime.now();
    final shouldRefresh = expiresAt != null &&
        !expiresAt.isAfter(now.add(_tokenRefreshSafetyWindow));

    if (!shouldRefresh) {
      return currentToken;
    }

    final refreshToken = _resolveRefreshToken(stored);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('登录状态已过期，请重新登录');
    }

    try {
      final refreshResult =
          await _gatewayService.refreshAuthToken(refreshToken: refreshToken);

      if (!refreshResult.success || !refreshResult.hasJwtToken) {
        throw Exception(
          refreshResult.error ?? refreshResult.message ?? 'Token刷新失败，请重新登录',
        );
      }

      final newToken =
          refreshResult.jwtToken ?? refreshResult.accessToken ?? currentToken;

      stored['jwtToken'] = newToken;
      stored['accessToken'] = refreshResult.accessToken ?? newToken;
      if (refreshResult.accessExpiresAt != null) {
        stored['accessExpiresAt'] =
            refreshResult.accessExpiresAt!.toIso8601String();
      } else {
        stored.remove('accessExpiresAt');
      }
      if (refreshResult.refreshExpiresAt != null) {
        stored['refreshExpiresAt'] =
            refreshResult.refreshExpiresAt!.toIso8601String();
      }
      if (refreshResult.refreshToken?.isNotEmpty == true) {
        stored['refreshToken'] = refreshResult.refreshToken;
      } else if (!stored.containsKey('refreshToken') &&
          refreshToken.isNotEmpty) {
        stored['refreshToken'] = refreshToken;
      }
      if (refreshResult.tokens != null) {
        stored['tokens'] = refreshResult.tokens;
      }

      final usernameToPersist = fallbackUsername.isNotEmpty
          ? fallbackUsername
          : (_coalesceStrings(
                stored,
                const ['userName', 'user_name', 'username'],
              ) ??
              '');

      if (usernameToPersist.isNotEmpty) {
        await UserManager.saveLoginState(
          username: usernameToPersist,
          extraData: stored,
        );
      }

      try {
        await _secureStorage.write(
          key: _secureAuthKey,
          value: jsonEncode(stored),
        );
      } catch (_) {
        // ignore secure storage write failures
      }

      return newToken;
    } catch (error) {
      final message = error.toString();
      final displayMessage = message.startsWith('Exception: ')
          ? message.substring('Exception: '.length)
          : message;
      throw Exception(displayMessage);
    }
  }

  String? _resolveRefreshToken(Map<String, dynamic>? stored) {
    final direct = _coalesceStrings(
      stored,
      const ['refreshToken', 'refresh_token'],
    );
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final tokens = stored?['tokens'];
    if (tokens is Map<String, dynamic>) {
      final nested = _coalesceStrings(
        tokens.cast<String, dynamic>(),
        const ['refresh_token'],
      );
      if (nested != null && nested.isNotEmpty) {
        return nested;
      }
    }
    return null;
  }

  DateTime? _parseDateValue(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return parsed;
      }
      final asInt = int.tryParse(trimmed);
      if (asInt != null) {
        if (asInt > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(asInt);
        }
        if (asInt > 0) {
          return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
        }
      }
      final asDouble = double.tryParse(trimmed);
      if (asDouble != null) {
        final millis = asDouble > 1000000000000
            ? asDouble.round()
            : (asDouble * 1000).round();
        if (millis > 0) {
          return DateTime.fromMillisecondsSinceEpoch(millis);
        }
      }
    }
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value > 0) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    if (value is double) {
      final millis =
          value > 1000000000000 ? value.round() : (value * 1000).round();
      if (millis > 0) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }
    return null;
  }

  DateTime? _decodeJwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }
    try {
      final normalized = base64.normalize(
        parts[1].replaceAll('-', '+').replaceAll('_', '/'),
      );
      final payload = jsonDecode(utf8.decode(base64.decode(normalized)));
      final exp = payload['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      }
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch((exp * 1000).round());
      }
    } catch (_) {
      return null;
    }
    return null;
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

  Future<void> _verifyInviteCode() async {
    final messenger = ScaffoldMessenger.of(context);
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('??????')));
      return;
    }
    if (_selectedRoomId.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('??????????')));
      return;
    }

    setState(() {
      _isInviteSubmitting = true;
    });

    try {
      final loginState = await UserManager.getLoginState();
      final bool isLoggedIn = loginState['isLoggedIn'] == true;
      final Map<String, dynamic>? storedUserData =
          loginState['userData'] as Map<String, dynamic>?;

      final Map<String, dynamic> combinedUserData = {};
      if (storedUserData != null) {
        combinedUserData.addAll(storedUserData);
      }
      final rawSecureAuth = await _secureStorage.read(key: _secureAuthKey);
      if (rawSecureAuth != null && rawSecureAuth.isNotEmpty) {
        try {
          final decodedAuth = jsonDecode(rawSecureAuth);
          if (decodedAuth is Map<String, dynamic>) {
            combinedUserData.addAll(decodedAuth);
          } else {
            debugPrint('Secure auth payload is not a Map: ' + decodedAuth.runtimeType.toString());
          }
        } catch (error) {
          debugPrint('Failed to decode secure auth payload: ' + error.toString());
        }
      } else {
        debugPrint('No secure auth payload found');
      }
      debugPrint('Combined auth keys: ' + combinedUserData.keys.join(', '));

      GatewayRoomDetailResult detailResult;
      String? effectiveJwtToken;

      if (isLoggedIn && combinedUserData.isNotEmpty) {
        final storedUsername = loginState['username'] as String? ?? '';
        final userName = _coalesceStrings(
              combinedUserData,
              const ['userName', 'user_name', 'username'],
            ) ??
            storedUsername;

        String jwtToken;
        try {
          jwtToken = await _ensureValidJwtToken(
            combinedUserData,
            userName.isNotEmpty ? userName : storedUsername,
          );
        } catch (error) {
          await UserManager.clearLoginState();
          setState(() {
            _isLoggedIn = false;
          });
          final message = error.toString();
          final displayMessage = message.startsWith('Exception: ')
              ? message.substring('Exception: '.length)
              : message;
          throw Exception(displayMessage);
        }

        final wsUrl = _coalesceStrings(
          combinedUserData,
          const ['wsUrl', 'ws_url'],
        );

        if (userName.isEmpty || jwtToken.isEmpty) {
          throw Exception('登录状态已失效，请重新登录');
        }

        detailResult = await _gatewayService.joinRoom(
          roomId: _selectedRoomId,
          inviteCode: code,
          userName: userName,
          userJwtToken: jwtToken,
          wssUrl: wsUrl,
        );
        effectiveJwtToken = jwtToken;
      } else {
        final authStatus = await _gatewayService.getAuthStatus();
        if (!authStatus.success) {
          final message =
              authStatus.error ?? authStatus.message ?? '??????????????';
          throw Exception(message);
        }

        final guestName = authStatus.userName ??
            authStatus.userNickname ??
            'guest_${DateTime.now().millisecondsSinceEpoch}';
        final guestToken = authStatus.jwtToken ?? '';
        if (guestToken.isEmpty) {
          throw Exception('????????????');
        }

        detailResult = await _gatewayService.joinRoom(
          roomId: _selectedRoomId,
          inviteCode: code,
          userName: guestName,
          userJwtToken: guestToken,
          wssUrl: authStatus.wsUrl,
        );
        effectiveJwtToken = guestToken;
      }

      if (!detailResult.success || !detailResult.hasLiveKitToken) {
        final message =
            detailResult.error ?? detailResult.message ?? '???????????';
        throw Exception(message);
      }

      final resolvedRoomId = detailResult.roomId ?? _selectedRoomId;
      final resolvedRoomName = detailResult.roomName ??
          (_selectedMeetingTitle.isNotEmpty
              ? _selectedMeetingTitle
              : resolvedRoomId);
      final participantName = detailResult.userNickname ??
          detailResult.userName ??
          (loginState['username'] as String? ?? '??');

      final joinData = RoomJoinData(
        roomId: resolvedRoomId,
        roomName: resolvedRoomName,
        inviteCode: code,
        participantName: participantName,
        liveKitToken: detailResult.livekitToken ?? '',
        wsUrl: detailResult.wssUrl ?? '',
        roomInfo: detailResult.room,
        userInfo: detailResult.user,
        userRoles: detailResult.userRoles,
        userId: detailResult.userId,
        userJwtToken: effectiveJwtToken,
      );

      if (joinData.liveKitToken.isEmpty) {
        throw Exception('????????????????');
      }

      _hideInviteCodePanel();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoConferenceScreen(joinData: joinData),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isInviteSubmitting = false;
        });
      }
    }
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

  Widget _buildRoomListSection() {
    const listPadding = EdgeInsets.only(left: 0, right: 0, top: 8, bottom: 24);

    if (_isLoadingRooms && _rooms.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRooms,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: listPadding,
          children: const [
            SizedBox(
              height: 240,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      );
    }

    if (_roomListError != null && _rooms.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRooms,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          children: [
            _buildRoomErrorState(),
          ],
        ),
      );
    }

    if (_rooms.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRooms,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          children: [
            _buildEmptyRoomState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: listPadding,
        itemCount: _rooms.length,
        itemBuilder: (context, index) {
          final room = _rooms[index];
          return _buildMeetingCard(
            title: room.roomName,
            roomId: room.roomId,
            host: room.hostDisplayName,
            status: room.statusText,
            isActive: room.isActive,
          );
        },
      ),
    );
  }

  Widget _buildRoomErrorState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.redAccent,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            _roomListError ?? '??????',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _loadRooms();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('????'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRoomState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.meeting_room_outlined,
            color: Colors.blueGrey,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            '???????',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              _loadRooms();
            },
            child: const Text('????'),
          ),
        ],
      ),
    );
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
          _buildRoomListSection(),

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
                              // ????? - ??????
                              Expanded(
                                child: Text(
                                  '???$_currentUsername',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ] else ...[
                              // ????? - ????????
                              ElevatedButton(
                                onPressed: () {
                                  _toggleUserMenu();
                                  _navigateToPersonalCenter(true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child:
                                    Text('注册', style: TextStyle(fontSize: 14)),
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
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                child:
                                    Text('登录', style: TextStyle(fontSize: 14)),
                              ),
                            ],
                            Spacer(),
                            // 关闭按钮
                            GestureDetector(
                              onTap: _toggleUserMenu,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                                color: Colors.grey[300]!),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide:
                                                BorderSide(color: Colors.blue),
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
                                          onPressed: _isInviteSubmitting
                                              ? null
                                              : _verifyInviteCode,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: _isInviteSubmitting
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : const Text(
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
                      onTap: () =>
                          _handleMeetingCardTap(title, roomId, isActive),
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
                      onTap: () =>
                          _handleMeetingCardTap(title, roomId, isActive),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
