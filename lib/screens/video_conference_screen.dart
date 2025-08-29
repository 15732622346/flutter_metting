import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// 直播间界面
class VideoConferenceScreen extends StatefulWidget {
  final String roomName;
  final String roomId;
  final String inviteCode;

  const VideoConferenceScreen({
    super.key,
    required this.roomName,
    required this.roomId,
    required this.inviteCode,
  });

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
  bool _isVideoInitialized = false;
  bool _isSmallVideoInitialized = false;

  // 小视频窗口状态
  bool _isSmallVideoMinimized = false;

  // 视频控制状态
  bool _showMainVideoControls = false;
  bool _showSmallVideoControls = false;
  bool _isMainVideoPlaying = false;
  bool _isSmallVideoPlaying = false;

  // 视频进度
  Duration _mainVideoPosition = Duration.zero;
  Duration _mainVideoDuration = Duration.zero;
  Duration _smallVideoPosition = Duration.zero;
  Duration _smallVideoDuration = Duration.zero;

  // 麦位和聊天数据
  int _totalMicSeats = 10;
  int _occupiedMicSeats = 8;
  String _moderator = 'wangba';

  // 模拟聊天消息
  List<ChatMessage> _chatMessages = [];
  bool _isInputFocused = false; // 输入框焦点状态
  bool _isSending = false; // 发送状态，防止按钮冲突



  @override
  void initState() {
    super.initState();
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

    // 移除监听器并释放视频控制器
    _videoController?.removeListener(_updateMainVideoState);
    _videoController?.dispose();
    _smallVideoController?.removeListener(_updateSmallVideoState);
    _smallVideoController?.dispose();

    super.dispose();
  }

  /// 初始化视频播放器
  void _initializeVideos() {
    // 主视频 - 使用免费的测试视频
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'),
    );

    // 小视频 - 使用另一个免费测试视频
    _smallVideoController = VideoPlayerController.networkUrl(
      Uri.parse('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4'),
    );

    // 初始化主视频
    _videoController!.initialize().then((_) {
      setState(() {
        _isVideoInitialized = true;
        _isMainVideoPlaying = true;
        _mainVideoDuration = _videoController!.value.duration;
      });
      _videoController!.play();
      _videoController!.setLooping(true);

      // 添加视频状态监听器
      _videoController!.addListener(_updateMainVideoState);
    }).catchError((error) {
      print('主视频初始化失败: $error');
    });

    // 初始化小视频
    _smallVideoController!.initialize().then((_) {
      setState(() {
        _isSmallVideoInitialized = true;
        _isSmallVideoPlaying = true;
        _smallVideoDuration = _smallVideoController!.value.duration;
      });
      _smallVideoController!.play();
      _smallVideoController!.setLooping(true);

      // 添加视频状态监听器
      _smallVideoController!.addListener(_updateSmallVideoState);
    }).catchError((error) {
      print('小视频初始化失败: $error');
    });
  }

  /// 更新主视频状态
  void _updateMainVideoState() {
    if (_videoController != null && mounted) {
      setState(() {
        _isMainVideoPlaying = _videoController!.value.isPlaying;
        _mainVideoPosition = _videoController!.value.position;
        _mainVideoDuration = _videoController!.value.duration;
      });
    }
  }

  /// 更新小视频状态
  void _updateSmallVideoState() {
    if (_smallVideoController != null && mounted) {
      setState(() {
        _isSmallVideoPlaying = _smallVideoController!.value.isPlaying;
        _smallVideoPosition = _smallVideoController!.value.position;
        _smallVideoDuration = _smallVideoController!.value.duration;
      });
    }
  }

  /// 初始化模拟数据 - 完全匹配HTML的消息
  void _initializeData() {
    _chatMessages = [
      ChatMessage(username: '系统', message: '系统：视频直播已开始', isSystem: true),
      ChatMessage(username: '系统', message: '系统：当前播放《大雄兔》测试视频', isSystem: true),
      ChatMessage(username: '系统', message: '系统：右下角按钮可以全屏小视频', isSystem: true),
      ChatMessage(username: '系统', message: '系统：右上角按钮可以缩小窗口', isSystem: true),
      ChatMessage(username: '主持人', message: '主持人：欢迎大家来到直播间！', isSystem: false),
      ChatMessage(username: '用户小明', message: '用户小明：视频播放很流畅！', isSystem: false),
      ChatMessage(username: '用户小红', message: '用户小红：画质很清晰', isSystem: false),
      ChatMessage(username: '用户小李', message: '用户小李：界面非常简洁流畅', isSystem: false),
      ChatMessage(username: '用户小王', message: '用户小王：小视频功能很棒', isSystem: false),
      ChatMessage(username: '系统', message: '系统：视频播放功能正常', isSystem: true),
    ];
  }

  // 移除计时器相关代码，聚焦于聊天功能

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF), // 纯白背景
      resizeToAvoidBottomInset: true, // 明确开启键盘自动适配（默认就是true）
      body: Stack(
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
    );
  }



  /// 构建视频播放区域
  Widget _buildVideoArea() {
    return Container(
      color: Colors.black, // 黑色背景，完全匹配HTML
      child: _isVideoInitialized && _videoController != null
          ? GestureDetector(
              onTap: () {
                setState(() {
                  _showMainVideoControls = !_showMainVideoControls;
                });
                // 3秒后自动隐藏控制条
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      _showMainVideoControls = false;
                    });
                  }
                });
              },
              child: Stack(
                children: [
                  // 视频播放器
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.contain, // 改为contain以完整显示视频
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  ),

                  // 视频控制组件
                  _buildMainVideoControls(),
                ],
              ),
            )
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

  /// 构建主视频控制组件
  Widget _buildMainVideoControls() {
    if (!_showMainVideoControls) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
        ),
      ),
      child: Column(
        children: [
          // 顶部控制栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '主视频',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                // 全屏按钮
                IconButton(
                  onPressed: _toggleMainVideoFullscreen,
                  icon: const Icon(Icons.fullscreen, color: Colors.white),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 中央播放按钮
          Center(
            child: GestureDetector(
              onTap: _toggleMainVideoPlayPause,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMainVideoPlaying ? Icons.pause : Icons.play_arrow,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const Spacer(),

          // 底部控制栏
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 进度条
                Row(
                  children: [
                    Text(
                      _formatDuration(_mainVideoPosition),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: _mainVideoDuration.inMilliseconds > 0
                            ? _mainVideoPosition.inMilliseconds / _mainVideoDuration.inMilliseconds
                            : 0.0,
                        onChanged: (value) {
                          final position = Duration(
                            milliseconds: (value * _mainVideoDuration.inMilliseconds).round(),
                          );
                          _videoController?.seekTo(position);
                        },
                        activeColor: Colors.white,
                        inactiveColor: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    Text(
                      _formatDuration(_mainVideoDuration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),

                // 控制按钮行
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: _rewindMainVideo,
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: _toggleMainVideoPlayPause,
                      icon: Icon(
                        _isMainVideoPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: _forwardMainVideo,
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                    ),
                    IconButton(
                      onPressed: _toggleMainVideoMute,
                      icon: Icon(
                        _videoController?.value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
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

  /// 主视频控制方法
  void _toggleMainVideoPlayPause() {
    if (_videoController != null) {
      setState(() {
        if (_isMainVideoPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      });
    }
  }

  void _rewindMainVideo() {
    if (_videoController != null) {
      final newPosition = _mainVideoPosition - const Duration(seconds: 10);
      _videoController!.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    }
  }

  void _forwardMainVideo() {
    if (_videoController != null) {
      final newPosition = _mainVideoPosition + const Duration(seconds: 10);
      _videoController!.seekTo(newPosition > _mainVideoDuration ? _mainVideoDuration : newPosition);
    }
  }

  void _toggleMainVideoMute() {
    if (_videoController != null) {
      setState(() {
        _videoController!.setVolume(_videoController!.value.volume == 0 ? 1.0 : 0.0);
      });
    }
  }

  void _toggleMainVideoFullscreen() {
    // TODO: 实现全屏功能
    _showToast('主视频全屏功能开发中');
  }

  /// 格式化时间显示
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  /// 构建小视频窗口
  Widget _buildSmallVideoWindow() {
    if (_isSmallVideoMinimized) {
      return Positioned(
        top: 305,
        right: 15,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _isSmallVideoMinimized = false;
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
      top: 305,
      right: 15,
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
              child: _isSmallVideoInitialized && _smallVideoController != null
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _showSmallVideoControls = !_showSmallVideoControls;
                        });
                        // 2秒后自动隐藏控制条
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            setState(() {
                              _showSmallVideoControls = false;
                            });
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _smallVideoController!.value.size.width,
                                height: _smallVideoController!.value.size.height,
                                child: VideoPlayer(_smallVideoController!),
                              ),
                            ),
                          ),
                          // 小视频控制组件
                          _buildSmallVideoControls(),
                        ],
                      ),
                    )
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
                onTap: _toggleSmallVideoFullscreen,
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
    );
  }

  /// 构建小视频控制组件
  Widget _buildSmallVideoControls() {
    if (!_showSmallVideoControls) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.transparent,
            Colors.black.withOpacity(0.6),
          ],
        ),
      ),
      child: Column(
        children: [
          // 顶部信息
          Container(
            padding: const EdgeInsets.all(4),
            child: const Text(
              '小视频',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),

          const Spacer(),

          // 中央播放按钮
          Center(
            child: GestureDetector(
              onTap: _toggleSmallVideoPlayPause,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSmallVideoPlaying ? Icons.pause : Icons.play_arrow,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const Spacer(),

          // 底部进度条
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: LinearProgressIndicator(
              value: _smallVideoDuration.inMilliseconds > 0
                  ? _smallVideoPosition.inMilliseconds / _smallVideoDuration.inMilliseconds
                  : 0.0,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// 小视频控制方法
  void _toggleSmallVideoPlayPause() {
    if (_smallVideoController != null) {
      setState(() {
        if (_isSmallVideoPlaying) {
          _smallVideoController!.pause();
        } else {
          _smallVideoController!.play();
        }
      });
    }
  }

  void _toggleSmallVideoFullscreen() {
    // TODO: 实现小视频全屏功能
    _showToast('小视频全屏功能开发中');
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), // 调整内边距
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4), // 4px圆角
                    borderSide: const BorderSide(color: Color(0xFFdddddd)), // #ddd
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

  /// 显示提示消息
  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.grey[800],
      ),
    );
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



