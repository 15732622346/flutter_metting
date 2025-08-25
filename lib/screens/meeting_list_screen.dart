import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/room_model.dart';
import '../services/api_service.dart';

/// 会议列表界面 - 基于原型图22222222222222.png
class MeetingListScreen extends StatefulWidget {
  const MeetingListScreen({super.key});

  @override
  State<MeetingListScreen> createState() => _MeetingListScreenState();
}

class _MeetingListScreenState extends State<MeetingListScreen> {
  final ApiService _apiService = ApiService();
  List<Room> _rooms = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('视频会议'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _rooms.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRooms,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_call_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '暂无可用会议',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRooms,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rooms.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _rooms.length) {
            // 加载更多指示器
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final room = _rooms[index];
          return _buildRoomCard(room);
        },
      ),
    );
  }

  /// 构建房间卡片（匹配原型图样式）
  Widget _buildRoomCard(Room room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 房间标题和状态
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 会议状态标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: room.isActive ? Colors.blue : Colors.grey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          room.statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 房间名称（类似TikTok流量与变现获客）
                      Text(
                        room.roomName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // 创建时间和主持人信息
                      Text(
                        '创建于 ${_formatDateTime(room.createTime)} • ${room.hostDisplayName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 加入按钮
                SizedBox(
                  width: 60,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: room.isActive ? () => _joinRoom(room) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      '加入',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 房间信息
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.mic,
                  text: room.audioEnabled ? '音频开启' : '音频关闭',
                  color: room.audioEnabled ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.videocam,
                  text: room.cameraEnabled ? '视频开启' : '视频关闭',
                  color: room.cameraEnabled ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                _buildInfoChip(
                  icon: Icons.people,
                  text: '${room.maxMicSlots}人',
                  color: Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建信息芯片
  Widget _buildInfoChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: 0, // 首页
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
      onTap: (index) {
        if (index == 1) {
          // 加入会议 - 回到登录页面
          Navigator.pushReplacementNamed(context, '/login');
        } else if (index == 2) {
          // 个人中心 - 回到登录页面
          Navigator.pushReplacementNamed(context, '/login');
        }
      },
    );
  }

  /// 加载房间列表
  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 注意：这个接口需要后台session，移动端可能无法直接调用
      // 可能需要添加公开的房间列表接口
      final rooms = await _apiService.getRoomList(page: _currentPage);
      
      setState(() {
        if (_currentPage == 1) {
          _rooms = rooms;
        } else {
          _rooms.addAll(rooms);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      
      // 如果是权限问题，显示模拟数据
      if (e.toString().contains('权限')) {
        _showMockRooms();
      }
    }
  }

  /// 显示模拟房间数据（用于演示）
  void _showMockRooms() {
    setState(() {
      _rooms = [
        Room(
          roomId: 'tiktok_marketing_001',
          roomName: 'TikTok流量与变现获客 记录新机划',
          userId: 1,
          hostUserId: 1,
          roomState: 1,
          audioState: 1,
          cameraState: 1,
          chatState: 1,
          inviteCode: '1315',
          maxMicSlots: 8,
          createTime: DateTime.now().subtract(const Duration(hours: 1)),
          hostName: 'wangqin',
        ),
        Room(
          roomId: 'tiktok_marketing_002',
          roomName: 'TikTok流量与变现获客 记录新机划',
          userId: 2,
          hostUserId: 2,
          roomState: 1,
          audioState: 1,
          cameraState: 1,
          chatState: 1,
          inviteCode: '1315',
          maxMicSlots: 8,
          createTime: DateTime.now().subtract(const Duration(hours: 2)),
          hostName: 'wangqin',
        ),
        Room(
          roomId: 'tiktok_marketing_003',
          roomName: 'TikTok流量与变现获客 记录新机划',
          userId: 3,
          hostUserId: 3,
          roomState: 0, // 已结束
          audioState: 1,
          cameraState: 1,
          chatState: 1,
          inviteCode: '1315',
          maxMicSlots: 8,
          createTime: DateTime.now().subtract(const Duration(hours: 3)),
          hostName: 'wangqin',
        ),
      ];
      _error = null;
      _isLoading = false;
    });
  }

  /// 加入房间
  void _joinRoom(Room room) {
    // 这里应该显示登录对话框或跳转到登录页面
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('加入会议'),
        content: Text('要加入会议「${room.roomName}」，请先登录您的账号。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}