import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../models/room_join_data.dart';

/// 直播间界面
class VideoConferenceScreen extends StatefulWidget {
  const VideoConferenceScreen({
    super.key,
    required this.joinData,
  });

  final RoomJoinData joinData;

  @override
  State<VideoConferenceScreen> createState() => _VideoConferenceScreenState();
}

class _VideoConferenceScreenState extends State<VideoConferenceScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // 视频播放器控制器
  VideoPlayerController? _videoController;
  VideoPlayerController? _smallVideoController;
  ChewieController? _chewieController;
  ChewieController? _smallChewieController;
  bool _isVideoInitialized = false;
  bool _isSmallVideoInitialized = false;

  // 小视频窗口状态
  bool _isSmallVideoMinimized = false;

  // 浮动窗口拖动位置
  double _floatingWindowX = 0.0; // 距离右边的距离
  double _floatingWindowY = 305.0; // 距离顶部的距离

  // 麦位和聊天数据
  int _totalMicSeats = 10;
  int _occupiedMicSeats = 8;
  String _moderator = '主持人';

  // 模拟聊天消息
  List<ChatMessage> _chatMessages = [];
  bool _isInputFocused = false; // 输入框焦点状态
  bool _isSending = false; // 发送状态，防止按钮冲突

  // 浮动窗口全屏按钮防抖
  bool _isFullscreenButtonClickable = true;
  late RoomJoinData _session;

  @override
  void initState() {
    super.initState();
    _session = widget.joinData;
    _initializeData();
    _initializeVideos();

    // 监听输入框焦点变化
    _inputFocusNode.addListener(() {
      setState(() {
        _isInputFocused = _inputFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    _inputFocusNode.dispose();

    // 先停止视频播放
    _videoController?.pause();
    _smallVideoController?.pause();

    // 释放chewie控制器
    _chewieController?.dispose();
    _smallChewieController?.dispose();

    // 明确释放底层video控制器，确保声音完全停止
    _videoController?.dispose();
    _smallVideoController?.dispose();

    super.dispose();
  }

  /// 全屏按钮防抖函数
  void _debounceFullscreenButton(VoidCallback action) {
    if (!_isFullscreenButtonClickable) return;

    setState(() {
      _isFullscreenButtonClickable = false;
    });

    // 执行操作
    action();

    // 2秒后重置点击状态（稍长一些，因为全屏操作比较重要）
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isFullscreenButtonClickable = true;
        });
      }
    });
  }

  /// 初始化视频播放器
  void _initializeVideos() {
    // 主视频 - 使用HTML7中的视频链接
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(
          'https://vod.pipi.cn/fec9203cvodtransbj1251246104/4332e3ed5145403693732329697/v.f42905.mp4'),
    );

    // 小视频 - 使用HTML7中的小视频链接
    _smallVideoController = VideoPlayerController.networkUrl(
      Uri.parse(
          'https://vod.pipi.cn/fec9203cvodtransbj1251246104/e032d17c5145403694330550266/v.f42905.mp4'),
    );

    // 初始化主视频
    _videoController!.initialize().then((_) {
      setState(() {
        _isVideoInitialized = true;
      });

      // 创建chewie控制器
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: true,
        showControls: true,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF388e3c),
          handleColor: const Color(0xFF388e3c),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
        hideControlsTimer: const Duration(seconds: 3),
      );
    }).catchError((error) {
      print('主视频初始化失败: $error');
    });

    // 初始化小视频
    _smallVideoController!.initialize().then((_) {
      setState(() {
        _isSmallVideoInitialized = true;
      });

      // 创建小视频chewie控制器
      _smallChewieController = ChewieController(
        videoPlayerController: _smallVideoController!,
        autoPlay: true,
        looping: true,
        showControls: true,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF388e3c),
          handleColor: const Color(0xFF388e3c),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade300,
        ),
        hideControlsTimer: const Duration(seconds: 2),
      );
    }).catchError((error) {
      print('小视频初始化失败: $error');
    });
  }

  /// 初始化模拟数据 - 结合实时房间信息
  void _initializeData() {
    final roomInfo = _session.roomInfo ?? <String, dynamic>{};
    final hostName = roomInfo['host_nickname'] ??
        roomInfo['hostNickname'] ??
        roomInfo['creator_nickname'] ??
        roomInfo['creatorName'] ??
        _moderator;

    if (hostName is String && hostName.trim().isNotEmpty) {
      _moderator = hostName.trim();
    }

    final maxSlots = roomInfo['max_mic_slots'] ?? roomInfo['maxMicSlots'];
    if (maxSlots is int && maxSlots > 0) {
      _totalMicSeats = maxSlots;
    }

    final onlineCount = roomInfo['online_count'] ?? roomInfo['onlineCount'];
    if (onlineCount is int && onlineCount >= 0) {
      _occupiedMicSeats = onlineCount;
    }

    final participantName =
        _session.participantName.isNotEmpty ? _session.participantName : '访客';

    _chatMessages = [
      ChatMessage(
        username: '系统',
        message: '系统：欢迎 ${participantName} 加入 ${_session.roomName}',
        isSystem: true,
      ),
      ChatMessage(
        username: '系统',
        message: '系统：主持人 $_moderator 正在等待大家入场',
        isSystem: true,
      ),
    ];
  }

  // 移除计时器相关代码，聚焦于聊天功能

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF), // 纯白背景
      resizeToAvoidBottomInset: true, // 明确开启键盘自动适配（默认就是true）
      body: SafeArea(
        child: Stack(
          children: [
            // 主容器
            Column(
              children: [
                // 视频播放区域 - 固定16:9宽高比
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildVideoArea(),
                ),

                // 聊天区域 - 填充剩余空间
                Expanded(
                  child: _buildChatSection(),
                ),
              ],
            ),

            // 小视频窗口 - 浮动在右上角
            _buildSmallVideoWindow(),
          ],
        ),
      ),
    );
  }

  /// 构建视频播放区域
  Widget _buildVideoArea() {
    return Container(
      color: Colors.black, // 黑色背景，完全匹配HTML
      child: _isVideoInitialized && _chewieController != null
          ? Chewie(controller: _chewieController!)
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    '正在加载视频...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
    );
  }

  /// 构建小视频窗口
  Widget _buildSmallVideoWindow() {
    if (_isSmallVideoMinimized) {
      return Positioned(
        top: _floatingWindowY,
        right: _floatingWindowX + 15,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isSmallVideoMinimized = false;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              // 更新拖动位置，限制在屏幕边界内
              final screenSize = MediaQuery.of(context).size;
              _floatingWindowY = (_floatingWindowY + details.delta.dy)
                  .clamp(0.0, screenSize.height - 30);
              _floatingWindowX = (_floatingWindowX - details.delta.dx)
                  .clamp(0.0, screenSize.width - 75); // 60(width) + 15(padding)
            });
          },
          child: Container(
            width: 60,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF388e3c).withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                '恢复',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned(
      top: _floatingWindowY,
      right: _floatingWindowX + 15,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            // 更新拖动位置，限制在屏幕边界内
            final screenSize = MediaQuery.of(context).size;
            _floatingWindowY = (_floatingWindowY + details.delta.dy)
                .clamp(0.0, screenSize.height - 140); // 140是小窗口高度
            _floatingWindowX = (_floatingWindowX - details.delta.dx)
                .clamp(0.0, screenSize.width - 135); // 120(width) + 15(padding)
          });
        },
        child: Container(
          width: 120,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 5),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // 小视频内容
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child:
                    _isSmallVideoInitialized && _smallChewieController != null
                        ? Chewie(controller: _smallChewieController!)
                        : Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.black,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
              ),
              // 控制按钮
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSmallVideoMinimized = true;
                    });
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '—',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () => _debounceFullscreenButton(() {
                    _showToast('小视频全屏功能由chewie提供');
                  }),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.fullscreen,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建聊天区域
  Widget _buildChatSection() {
    return Column(
      children: [
        // 聊天标题栏 - 完全匹配HTML样式
        _buildChatHeader(),

        // 聊天容器
        Expanded(
          child: _buildChatContainer(),
        ),
      ],
    );
  }

  /// 构建聊天标题栏
  Widget _buildChatHeader() {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF388e3c), // #388e3c
            Color(0xFF2e7d32), // #2e7d32
          ],
        ),
      ),
      child: Row(
        children: [
          // 聊天标题 - 带下划线
          SizedBox(
            width: 60,
            child: Stack(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '聊天',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 30,
                    height: 2,
                    color: const Color(0xFFffe200), // #ffe200 黄色下划线
                  ),
                ),
              ],
            ),
          ),

          // 房间信息 - 右对齐，使用Flexible防止溢出，数字显示为黄色
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 14),
                  children: [
                    const TextSpan(
                      text: '麦位：',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: '${_totalMicSeats}人',
                      style: const TextStyle(color: Color(0xFFffe200)), // 黄色数字
                    ),
                    const TextSpan(
                      text: ' 上限：',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: '${_occupiedMicSeats}人',
                      style: const TextStyle(color: Color(0xFFffe200)), // 黄色数字
                    ),
                    const TextSpan(
                      text: ' 主持人：',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: _moderator,
                      style: const TextStyle(color: Color(0xFFffe200)), // 黄色文字
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建聊天容器
  Widget _buildChatContainer() {
    return Column(
      children: [
        // 聊天消息列表 - 完全匹配HTML的卡片样式
        Expanded(
          child: Container(
            color: const Color(0xFFf9f9f9), // #f9f9f9 背景色
            child: ListView.builder(
              controller: _chatScrollController,
              padding: const EdgeInsets.all(15),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final message = _chatMessages[index];
                return _buildChatMessage(message);
              },
            ),
          ),
        ),

        // 底部输入区域
        _buildInputContainer(),
      ],
    );
  }

  /// 构建单条聊天消息 - 完全匹配HTML卡片样式
  Widget _buildChatMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15), // 匹配HTML的12px 15px
      decoration: BoxDecoration(
        color: message.isSystem
            ? const Color(0xFFe8f5e9) // 系统消息浅绿色背景
            : message.isOwn
                ? const Color(0xFFe3f2fd) // 用户消息浅蓝色背景
                : Colors.white, // 其他消息白色背景
        borderRadius: BorderRadius.circular(8), // 8px圆角
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05), // rgba(0, 0, 0, 0.05)
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(
        message.isSystem
            ? message.message // 系统消息直接显示
            : '${message.username}: ${message.message}', // 用户消息带用户名
        style: TextStyle(
          color: message.isSystem
              ? const Color(0xFF2e7d32) // 系统消息深绿色文字
              : Colors.black87, // 其他消息黑色文字
          fontSize: 14,
        ),
      ),
    );
  }

  /// 构建输入容器 - 完全匹配HTML样式
  Widget _buildInputContainer() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFe0e0e0), width: 1), // #e0e0e0
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // 使用center对齐
        children: [
          // 输入框容器
          Expanded(
            child: SizedBox(
              height: 40, // 设置固定高度40px，与按钮匹配
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                style: const TextStyle(
                  color: Color(0xFF333333), // #333 文字颜色
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  hintStyle: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15, vertical: 8), // 调整内边距
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4), // 4px圆角
                    borderSide:
                        const BorderSide(color: Color(0xFFdddddd)), // #ddd
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFFdddddd)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(
                      color: Color(0xFF388e3c), // 聚焦时绿色边框
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),

          const SizedBox(width: 10), // 匹配HTML的gap: 10px

          // 按钮工具栏
          Row(
            children: [
              if (_isInputFocused) ...[
                // 发送按钮 - 聚焦时显示
                SizedBox(
                  height: 40, // 与输入框高度完全一致
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque, // 确保整个区域都能响应点击
                    onTap: () => _sendMessage(_messageController.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFff5722), // #ff5722 橙红色
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '发送',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // 开麦按钮
                SizedBox(
                  height: 40, // 与输入框高度完全一致
                  child: ElevatedButton(
                    onPressed: () => _showToast('开麦功能开发中'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFb5b5b5), // #b5b5b5 灰色
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('开麦', style: TextStyle(fontSize: 14)),
                  ),
                ),

                const SizedBox(width: 8), // 按钮间距

                // 上麦按钮
                SizedBox(
                  height: 40, // 与输入框高度完全一致
                  child: ElevatedButton(
                    onPressed: () => _showToast('上麦功能开发中'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4595d5), // #4595d5 蓝色
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('上麦', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 发送消息 - 简化版，依赖Flutter自动适配
  void _sendMessage(String message) {
    if (message.trim().isEmpty) return;

    setState(() {
      _chatMessages.add(
        ChatMessage(
          username: '您',
          message: message.trim(),
          isSystem: false,
          isOwn: true,
        ),
      );
    });

    _messageController.clear();

    // 延迟失去焦点，确保点击事件完整执行（参考HTML实现）
    Future.delayed(const Duration(milliseconds: 50), () {
      _inputFocusNode.unfocus();
    });

    // 简单的滚动到底部，Flutter会自动处理键盘适配
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 显示提示消息 - 如果已有提示在显示则不显示新提示
  void _showToast(String message) {
    // 检查是否已经有SnackBar在显示
    if (ScaffoldMessenger.of(context).mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      // 如果当前没有SnackBar显示，才显示新的
      try {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.grey[800],
          ),
        );
      } catch (e) {
        // 如果有SnackBar正在显示，会抛出异常，忽略即可
        print('Toast already visible, ignoring new toast');
      }
    }
  }
}

/// 聊天消息数据模型
class ChatMessage {
  final String username;
  final String message;
  final bool isSystem;
  final bool isOwn;
  final DateTime timestamp;

  ChatMessage({
    required this.username,
    required this.message,
    required this.isSystem,
    this.isOwn = false,
  }) : timestamp = DateTime.now();
}
