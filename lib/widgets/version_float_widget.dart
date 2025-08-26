import 'package:flutter/material.dart';
import '../config/version_config.dart';

/// 版本标识浮动框组件
/// 显示在主页中间，用于区分旧版本和新版本
class VersionFloatWidget extends StatefulWidget {
  @override
  _VersionFloatWidgetState createState() => _VersionFloatWidgetState();
}

class _VersionFloatWidgetState extends State<VersionFloatWidget>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // 创建动画控制器
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    );
    
    // 缩放动画
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    // 透明度动画
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));
    
    // 启动动画
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!VersionConfig.SHOW_VERSION_FLOAT) {
      return SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: VersionConfig.versionColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: VersionConfig.versionColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 版本标识
                  Text(
                    VersionConfig.versionText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4),
                  
                  // 版本描述
                  Text(
                    VersionConfig.versionDescription,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  
                  // 版本号
                  Text(
                    'v${VersionConfig.versionNumber}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 浮动版本标签 - 简化版本
class SimpleVersionTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!VersionConfig.SHOW_VERSION_FLOAT) {
      return SizedBox.shrink();
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: VersionConfig.versionColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            VersionConfig.IS_NEW_VERSION ? Icons.new_releases : Icons.info,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 6),
          Text(
            VersionConfig.versionText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}