import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 会议设置界面 - 基于原型图3333333333.png
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _cameraEnabled = true;
  bool _microphoneEnabled = true;
  bool _autoJoinAudio = true;
  bool _autoJoinVideo = true;
  bool _enableEchoCancellation = true;
  bool _enableNoiseSuppression = true;
  double _microphoneVolume = 0.8;
  double _speakerVolume = 0.8;
  String _selectedCamera = 'front';
  String _selectedMicrophone = 'default';
  String _selectedSpeaker = 'default';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('会议设置'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 摄像头设置
            _buildSectionTitle('摄像头设置'),
            _buildSettingsCard([
              SwitchListTile(
                title: const Text('开启摄像头'),
                subtitle: const Text('加入会议时自动开启摄像头'),
                value: _cameraEnabled,
                onChanged: (value) {
                  setState(() {
                    _cameraEnabled = value;
                  });
                },
                activeColor: Colors.green,
              ),
              SwitchListTile(
                title: const Text('自动开启视频'),
                subtitle: const Text('加入会议后自动开启视频'),
                value: _autoJoinVideo,
                onChanged: (value) {
                  setState(() {
                    _autoJoinVideo = value;
                  });
                },
                activeColor: Colors.green,
              ),
              ListTile(
                title: const Text('默认摄像头'),
                subtitle: Text(_selectedCamera == 'front' ? '前置摄像头' : '后置摄像头'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCameraSelector(),
              ),
            ]),

            const SizedBox(height: 20),

            // 麦克风设置
            _buildSectionTitle('麦克风设置'),
            _buildSettingsCard([
              SwitchListTile(
                title: const Text('开启麦克风'),
                subtitle: const Text('加入会议时自动开启麦克风'),
                value: _microphoneEnabled,
                onChanged: (value) {
                  setState(() {
                    _microphoneEnabled = value;
                  });
                },
                activeColor: Colors.green,
              ),
              SwitchListTile(
                title: const Text('自动开启音频'),
                subtitle: const Text('加入会议后自动开启音频'),
                value: _autoJoinAudio,
                onChanged: (value) {
                  setState(() {
                    _autoJoinAudio = value;
                  });
                },
                activeColor: Colors.green,
              ),
              ListTile(
                title: const Text('麦克风音量'),
                subtitle: Slider(
                  value: _microphoneVolume,
                  onChanged: (value) {
                    setState(() {
                      _microphoneVolume = value;
                    });
                  },
                  activeColor: Colors.blue,
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // 音频设置
            _buildSectionTitle('音频设置'),
            _buildSettingsCard([
              SwitchListTile(
                title: const Text('回声消除'),
                subtitle: const Text('减少音频回声和反馈'),
                value: _enableEchoCancellation,
                onChanged: (value) {
                  setState(() {
                    _enableEchoCancellation = value;
                  });
                },
                activeColor: Colors.green,
              ),
              SwitchListTile(
                title: const Text('噪音抑制'),
                subtitle: const Text('减少背景噪音'),
                value: _enableNoiseSuppression,
                onChanged: (value) {
                  setState(() {
                    _enableNoiseSuppression = value;
                  });
                },
                activeColor: Colors.green,
              ),
              ListTile(
                title: const Text('扬声器音量'),
                subtitle: Slider(
                  value: _speakerVolume,
                  onChanged: (value) {
                    setState(() {
                      _speakerVolume = value;
                    });
                  },
                  activeColor: Colors.blue,
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // 网络设置
            _buildSectionTitle('网络设置'),
            _buildSettingsCard([
              ListTile(
                title: const Text('网络质量'),
                subtitle: const Text('自动调节视频质量以适应网络'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '良好',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              ListTile(
                title: const Text('数据使用'),
                subtitle: const Text('查看会议中的数据使用情况'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showDataUsageDialog(),
              ),
            ]),

            const SizedBox(height: 20),

            // 其他设置
            _buildSectionTitle('其他设置'),
            _buildSettingsCard([
              ListTile(
                title: const Text('测试摄像头'),
                subtitle: const Text('测试摄像头是否正常工作'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _testCamera(),
              ),
              ListTile(
                title: const Text('测试麦克风'),
                subtitle: const Text('测试麦克风是否正常工作'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _testMicrophone(),
              ),
              ListTile(
                title: const Text('恢复默认设置'),
                subtitle: const Text('将所有设置恢复为默认值'),
                trailing: const Icon(Icons.refresh),
                onTap: () => _resetToDefaults(),
              ),
            ]),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// 构建分类标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// 构建设置卡片
  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: children.map((child) {
          final isLast = children.indexOf(child) == children.length - 1;
          return Column(
            children: [
              child,
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: Colors.grey[200],
                    height: 1,
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _cameraEnabled = prefs.getBool('camera_enabled') ?? true;
        _microphoneEnabled = prefs.getBool('microphone_enabled') ?? true;
        _autoJoinAudio = prefs.getBool('auto_join_audio') ?? true;
        _autoJoinVideo = prefs.getBool('auto_join_video') ?? true;
        _enableEchoCancellation = prefs.getBool('echo_cancellation') ?? true;
        _enableNoiseSuppression = prefs.getBool('noise_suppression') ?? true;
        _microphoneVolume = prefs.getDouble('microphone_volume') ?? 0.8;
        _speakerVolume = prefs.getDouble('speaker_volume') ?? 0.8;
        _selectedCamera = prefs.getString('selected_camera') ?? 'front';
        _selectedMicrophone = prefs.getString('selected_microphone') ?? 'default';
        _selectedSpeaker = prefs.getString('selected_speaker') ?? 'default';
      });
    } catch (e) {
      print('加载设置失败: $e');
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('camera_enabled', _cameraEnabled);
      await prefs.setBool('microphone_enabled', _microphoneEnabled);
      await prefs.setBool('auto_join_audio', _autoJoinAudio);
      await prefs.setBool('auto_join_video', _autoJoinVideo);
      await prefs.setBool('echo_cancellation', _enableEchoCancellation);
      await prefs.setBool('noise_suppression', _enableNoiseSuppression);
      await prefs.setDouble('microphone_volume', _microphoneVolume);
      await prefs.setDouble('speaker_volume', _speakerVolume);
      await prefs.setString('selected_camera', _selectedCamera);
      await prefs.setString('selected_microphone', _selectedMicrophone);
      await prefs.setString('selected_speaker', _selectedSpeaker);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('设置已保存'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存设置失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 显示摄像头选择器
  void _showCameraSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择摄像头'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('前置摄像头'),
              value: 'front',
              groupValue: _selectedCamera,
              onChanged: (value) {
                setState(() {
                  _selectedCamera = value!;
                });
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<String>(
              title: const Text('后置摄像头'),
              value: 'back',
              groupValue: _selectedCamera,
              onChanged: (value) {
                setState(() {
                  _selectedCamera = value!;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示数据使用对话框
  void _showDataUsageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('数据使用情况'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本次会议：'),
            Text('• 上传：15.2 MB'),
            Text('• 下载：28.7 MB'),
            Text('• 总计：43.9 MB'),
            SizedBox(height: 16),
            Text('本月累计：'),
            Text('• 上传：156.8 MB'),
            Text('• 下载：287.3 MB'),
            Text('• 总计：444.1 MB'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 测试摄像头
  void _testCamera() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('摄像头测试'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam,
              size: 64,
              color: Colors.green,
            ),
            SizedBox(height: 16),
            Text('摄像头测试功能正在开发中...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 测试麦克风
  void _testMicrophone() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('麦克风测试'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic,
              size: 64,
              color: Colors.green,
            ),
            SizedBox(height: 16),
            Text('麦克风测试功能正在开发中...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 恢复默认设置
  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认设置'),
        content: const Text('确定要将所有设置恢复为默认值吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performReset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              '恢复',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// 执行重置
  void _performReset() {
    setState(() {
      _cameraEnabled = true;
      _microphoneEnabled = true;
      _autoJoinAudio = true;
      _autoJoinVideo = true;
      _enableEchoCancellation = true;
      _enableNoiseSuppression = true;
      _microphoneVolume = 0.8;
      _speakerVolume = 0.8;
      _selectedCamera = 'front';
      _selectedMicrophone = 'default';
      _selectedSpeaker = 'default';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已恢复默认设置'),
        backgroundColor: Colors.green,
      ),
    );
  }
}