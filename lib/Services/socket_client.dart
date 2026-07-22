import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:socket_io_common/src/util/event_emitter.dart';
import 'env_config.dart';

class SocketClient {
  static io.Socket? _socket;
  static bool _initialized = false;
  static final List<String> _rooms = [];
  static final List<VoidCallback> _reconnectCallbacks = [];

  static bool get isConnected => _socket?.connected ?? false;
  static bool get isInitialized => _initialized;

  static void init({String? token}) {
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
      for (final room in _rooms) {
        _socket?.emit('join', room);
      }
    });
    _socket!.onDisconnect((_) {
    });
    _socket!.onConnectError((err) {
    });
    _socket!.onReconnect((_) {
      for (final room in _rooms) {
        _socket?.emit('join', room);
      }
      for (final cb in _reconnectCallbacks) {
        cb();
      }
    });
    _socket!.connect();
  }

  static void join(String room) {
    if (!_rooms.contains(room)) _rooms.add(room);
    _socket?.emit('join', room);
  }

  static void leave(String room) {
    _rooms.remove(room);
    _socket?.emit('leave', room);
  }

  static void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  static void onReconnect(VoidCallback cb) {
    _reconnectCallbacks.add(cb);
  }

  static void offReconnect(VoidCallback cb) {
    _reconnectCallbacks.remove(cb);
  }

  static void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  static void off(String event, [Function? handler]) {
    if (handler != null) {
      _socket?.off(event, handler as EventHandler<dynamic>?);
    } else {
      _socket?.off(event);
    }
  }

  static void dispose() {
    _socket?.dispose();
    _initialized = false;
    _rooms.clear();
    _reconnectCallbacks.clear();
  }
}
