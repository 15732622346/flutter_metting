import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // 直播间状态
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _isFullScreen = false;
  int _currentTime = 0; // 秒 - 重置为0
  int _totalTime = 70; // 秒

  // 麦位和聊天数据
  int _totalMicSeats = 10;
  int _occupiedMicSeats = 8;

  // 模拟聊天消息
  List<ChatMessage> _chatMessages = [];
  bool _isInputFocused = false; // 输入框焦点状态



  @override
  void initState() {
    super.initState();
    _initializeData();
    _startTimer();

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
    super.dispose();
  }

  /// 初始化模拟数据
  void _initializeData() {
    // 初始化聊天消息
    _chatMessages = [
      ChatMessage(username: '用户2', message: '阿塞法赛阿福赛', isSystem: false),
      ChatMessage(username: '用户5', message: '扥刚扥刚扥刚', isSystem: false),
      ChatMessage(username: '用户7', message: '阿塞法东阿福萨达', isSystem: false),
      ChatMessage(username: '用户9', message: '绕弯儿去玩儿去玩儿', isSystem: false),
      ChatMessage(username: '用户3', message: '阿塞法东法赛阿福', isSystem: true),
    ];


  }

  /// 启动计时器（模拟直播时间）
  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isPlaying) {
        setState(() {
          _currentTime++;
          // 防止超过最大时间
          if (_currentTime > _totalTime) {
            _currentTime = _totalTime;
          }
        });
        _startTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 改为白色背景
      body: SafeArea(
        minimum: EdgeInsets.symmetric(vertical: 10), // 只添加上下10px安全区域
        child: Column(
          children: [
            // 视频播放区域 - 固定16:9宽高比
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildVideoArea(),
            ),

            // 麦位信息栏
            _buildMicSeatInfo(),

            // 聊天区域 - 填充剩余空间
            Expanded(
              child: _buildChatArea(),
            ),

            // 底部输入区域
            _buildBottomInputArea(),
          ],
        ),
      ),
    );
  }



  /// 构建视频播放区域
  Widget _buildVideoArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
      ),
      child: Stack(
        children: [
          // 视频背景
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue[900]!,
                  Colors.blue[700]!,
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 播放按钮
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                      });
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 40,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 直播标题
                  const Text(
                    '"素式"挂片',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '《天龙八部手游》爱好者的外观团队',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '青春营剧力作',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '今年我们将看到一群关爱你的朋友',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部进度条
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: _buildProgressBar(),
          ),
        ],
      ),
    );
  }

  /// 构建进度条
  Widget _buildProgressBar() {
    return Row(
      children: [
        Text(
          _formatTime(_currentTime),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: (_currentTime > _totalTime ? _totalTime : _currentTime).toDouble(),
              min: 0,
              max: _totalTime.toDouble(),
              activeColor: Colors.white,
              inactiveColor: Colors.white30,
              onChanged: (value) {
                setState(() {
                  _currentTime = value.toInt();
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '-${_formatTime(_totalTime - _currentTime)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 16),
        // 画中画按钮
        Icon(
          Icons.picture_in_picture_alt,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 12),
        // 设置按钮
        Icon(
          Icons.settings,
          color: Colors.white,
          size: 20,
        ),
      ],
    );
  }

  /// 格式化时间
  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }



  /// 构建麦位信息栏
  Widget _buildMicSeatInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green,
      ),
      child: Row(
        children: [
          const Text(
            '聊天',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '麦位：$_totalMicSeats人',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 20),
          Text(
            '上麦：$_occupiedMicSeats人',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建聊天区域
  Widget _buildChatArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // 白色背景
        border: Border.all(color: Colors.grey[300]!), // 添加边框
      ),
      child: Column(
        children: [
          // 聊天消息列表
          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              padding: EdgeInsets.all(12),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final message = _chatMessages[index];
                return _buildChatMessage(message);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单条聊天消息
  Widget _buildChatMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户名
          Text(
            '${message.username}：',
            style: TextStyle(
              color: message.isSystem
                  ? Colors.green[700] // 系统消息绿色
                  : message.isOwn
                      ? Colors.blue[700] // 自己的消息蓝色
                      : Colors.grey[600], // 其他用户消息灰色
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          // 消息内容
          Expanded(
            child: Text(
              message.message,
              style: const TextStyle(
                color: Colors.black, // 改为黑色文字
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部输入区域
  Widget _buildBottomInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white, // 改为白色背景
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1), // 浅色边框
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // 输入框
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100], // 浅灰色输入框背景
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[300]!), // 添加边框
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _inputFocusNode,
                  style: const TextStyle(color: Colors.black), // 黑色文字
                  decoration: const InputDecoration(
                    hintText: '输入消息...',
                    hintStyle: TextStyle(color: Colors.grey), // 灰色提示文字
                    border: InputBorder.none,
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 根据输入框焦点状态显示不同按钮
            if (_isInputFocused) ...[
            // 发送按钮（输入框获取焦点时显示）
            SizedBox(
              height: 48, // 设置固定高度与输入框等高
              child: ElevatedButton(
                onPressed: () {
                  final message = _messageController.text.trim();
                  if (message.isNotEmpty) {
                    _sendMessage(message);
                    _messageController.clear();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '发送',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ] else ...[
            // 开麦和上麦按钮（输入框未获取焦点时显示）
            SizedBox(
              height: 48, // 设置固定高度与输入框等高
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 实现开麦功能
                  _showToast('开麦功能开发中');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '开麦',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48, // 设置固定高度与输入框等高
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 实现上麦功能
                  _showToast('上麦功能开发中');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '上麦',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }

  /// 发送消息
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

    // 滚动到底部
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



