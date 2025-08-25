import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/room_model.dart';
import '../models/login_response.dart';
import '../models/participant_model.dart';

class ApiService {
  static const String baseUrl = 'https://meet.pgm18.com/admin/';
  late final Dio _dio;
  
  // 单例模式
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'User-Agent': 'Flutter-Meeting-App/1.0.0',
      },
    ));
    
    // 添加请求和响应拦截器用于调试
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print('🚀 API请求: ${options.method} ${options.path}');
          if (options.data != null) {
            print('📝 请求数据: ${options.data}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          print('✅ API响应: ${response.statusCode} ${response.requestOptions.path}');
          handler.next(response);
        },
        onError: (error, handler) {
          print('❌ API错误: ${error.message}');
          if (error.response != null) {
            print('📄 错误响应: ${error.response?.data}');
          }
          handler.next(error);
        },
      ),
    );
  }
  
  /// 房间登录 - 对应 room-login.php
  /// 这是核心登录接口，会返回LiveKit Token
  Future<LoginResponse> loginToRoom({
    required String username,
    required String password,
    required String roomId,
  }) async {
    try {
      final response = await _dio.post(
        'room-login.php',
        data: {
          'user_name': username,
          'user_password': password,
          'room_id': roomId,
        },
      );
      
      return LoginResponse.fromJson(response.data);
    } on DioException catch (e) {
      // 处理HTTP错误响应
      if (e.response?.data != null) {
        try {
          return LoginResponse.fromJson(e.response!.data);
        } catch (_) {
          return LoginResponse(
            success: false,
            error: e.response?.data['error'] ?? e.message ?? '登录失败',
          );
        }
      }
      
      // 处理网络错误
      return LoginResponse(
        success: false,
        error: _getErrorMessage(e),
      );
    } catch (e) {
      return LoginResponse(
        success: false,
        error: '登录失败: $e',
      );
    }
  }
  
  /// 获取房间列表 - 对应 list-room.php（需要session认证）
  /// 注意：此接口需要后台登录session，移动端可能无法直接使用
  Future<List<Room>> getRoomList({int page = 1, int? status}) async {
    try {
      final response = await _dio.get('list-room.php', queryParameters: {
        'page': page,
        if (status != null) 'status': status,
      });
      
      if (response.data['data'] != null) {
        final data = response.data['data'] as List;
        return data.map((json) => Room.fromJson(json)).toList();
      }
      
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        throw Exception('无权限访问房间列表');
      }
      throw Exception('获取房间列表失败: ${_getErrorMessage(e)}');
    }
  }
  
  /// 获取房间信息 - 对应 room-info.php（公开接口）
  Future<Room?> getRoomInfo(String roomId) async {
    try {
      final response = await _dio.get('room-info.php', queryParameters: {
        'room_id': roomId,
      });
      
      if (response.data['success'] == true && response.data['room'] != null) {
        return Room.fromJson(response.data['room']);
      }
      return null;
    } catch (e) {
      print('获取房间信息失败: $e');
      return null;
    }
  }
  
  /// 验证邀请码是否有效
  Future<bool> validateInviteCode(String code, String roomId) async {
    try {
      final roomInfo = await getRoomInfo(roomId);
      return roomInfo?.canJoin(code) ?? false;
    } catch (e) {
      print('验证邀请码失败: $e');
      return false;
    }
  }
  
  /// PC注册接口 - 对应 pc-register.php
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String nickname,
  }) async {
    try {
      final response = await _dio.post(
        'pc-register.php',
        data: {
          'user_name': username,
          'user_password': password,
          'user_nickname': nickname,
        },
      );
      
      return {
        'success': response.data['success'] ?? false,
        'message': response.data['message'] ?? response.data['error'] ?? '注册失败',
      };
    } on DioException catch (e) {
      if (e.response?.data != null) {
        return {
          'success': false,
          'message': e.response!.data['error'] ?? e.message ?? '注册失败',
        };
      }
      return {
        'success': false,
        'message': _getErrorMessage(e),
      };
    }
  }
  
  /// 修改密码 - 对应相关接口（需要实现）
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    // 这里需要根据实际PHP接口实现
    // 当前后端可能还没有移动端专用的修改密码接口
    try {
      final response = await _dio.post(
        'update-user-password.php', // 假设接口名
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        },
      );
      
      return {
        'success': response.data['success'] ?? false,
        'message': response.data['message'] ?? response.data['error'] ?? '修改失败',
      };
    } catch (e) {
      return {
        'success': false,
        'message': '修改密码失败: $e',
      };
    }
  }
  
  /// 获取用户信息
  Future<User?> getUserInfo(int userId) async {
    try {
      final response = await _dio.get('get-user-info.php', queryParameters: {
        'user_id': userId,
      });
      
      if (response.data['success'] == true && response.data['user'] != null) {
        return User.fromJson(response.data['user']);
      }
      return null;
    } catch (e) {
      print('获取用户信息失败: $e');
      return null;
    }
  }
  
  /// 获取参与者列表
  Future<List<ParticipantInfo>> getParticipants(String roomId) async {
    try {
      final response = await _dio.get('get-participants.php', queryParameters: {
        'room_id': roomId,
      });
      
      if (response.data['participants'] != null) {
        final data = response.data['participants'] as List;
        return data.map((json) => ParticipantInfo.fromJson(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('获取参与者列表失败: $e');
      return [];
    }
  }
  
  /// 申请上麦 - 对应 apply-mic.php
  Future<bool> applyForMic(String roomId, int userId) async {
    try {
      final response = await _dio.post('apply-mic.php', data: {
        'room_id': roomId,
        'user_id': userId,
      });
      
      return response.data['success'] == true;
    } catch (e) {
      print('申请上麦失败: $e');
      return false;
    }
  }
  
  /// 检查网络连接
  Future<bool> checkConnection() async {
    try {
      await _dio.get('health-check.php');
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// 获取错误信息的统一处理
  String _getErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.sendTimeout:
        return '发送超时，请重试';
      case DioExceptionType.receiveTimeout:
        return '接收超时，请重试';
      case DioExceptionType.connectionError:
        return '网络连接错误';
      case DioExceptionType.badResponse:
        if (error.response?.statusCode == 404) {
          return '接口不存在';
        } else if (error.response?.statusCode == 500) {
          return '服务器内部错误';
        }
        return '请求失败: ${error.response?.statusCode}';
      case DioExceptionType.cancel:
        return '请求已取消';
      case DioExceptionType.unknown:
      default:
        if (error.error is SocketException) {
          return '网络不可用，请检查网络连接';
        }
        return '未知错误: ${error.message}';
    }
  }
}