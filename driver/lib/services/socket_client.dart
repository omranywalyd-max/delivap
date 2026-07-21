import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../env_config.dart';

class SocketClient {
  static final SocketClient _instance = SocketClient._();
  factory SocketClient() => _instance;
  SocketClient._();

  io.Socket? _socket;
  bool _initialized = false;
  final List<String> _rooms = [];
  final List<VoidCallback> _reconnectCallbacks = [];

  io.Socket get socket => _socket!;
  bool get isConnected => _socket?.connected ?? false;
  bool get isInitialized => _initialized;

  void init({String? token}) {
    if (_initialized) return;
    _initialized = true;
    _socket = io.io(EnvConfig.baseUrl, <String, dynamic>{
      'extraHeaders': {
        if (token != null) 'Authorization': 'Bearer $token',
      },
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 20,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
    });

    _socket!.onConnect((_) {
      debugPrint('Socket connected');
      for (final room in _rooms) {
        _socket?.emit('join', room);
      }
    });
    _socket!.onDisconnect((_) {
      debugPrint('Socket disconnected');
    });
    _socket!.onConnectError((err) {
      debugPrint('Socket connect error: $err');
    });
    _socket!.onReconnect((_) {
      debugPrint('Socket reconnected');
      for (final room in _rooms) {
        _socket?.emit('join', room);
      }
      for (final cb in _reconnectCallbacks) {
        cb();
      }
    });
  }

  void join(String room) {
    if (!_rooms.contains(room)) _rooms.add(room);
    _socket?.emit('join', room);
  }

  void leave(String room) {
    _rooms.remove(room);
    _socket?.emit('leave', room);
  }

  void onReconnect(VoidCallback cb) {
    _reconnectCallbacks.add(cb);
  }

  void offReconnect(VoidCallback cb) {
    _reconnectCallbacks.remove(cb);
  }

  void on(String event, dynamic Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic)? handler]) {
    if (handler != null) {
      _socket?.off(event, handler);
    } else {
      _socket?.off(event);
    }
  }

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _initialized = false;
    _rooms.clear();
    _reconnectCallbacks.clear();
  }
}
