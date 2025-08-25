import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 初始化认证状态
    await context.read<AuthProvider>().initialize();
    
    // 等待启动画面展示
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // 检查登录状态并导航
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/meetings');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_call,
              size: 80,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              '视频会议',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 40),
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}