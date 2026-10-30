import 'package:flutter/foundation.dart';

class TransferNotification {
  const TransferNotification({
    required this.id,
    required this.title,
    required this.amountToea,
    required this.createdAt,
    required this.reference,
    required this.isRead,
  });
  final String id, title, reference;
  final int amountToea;
  final DateTime createdAt;
  final bool isRead;
  factory TransferNotification.fromJson(Map<String, dynamic> json) =>
      TransferNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        amountToea: json['amountToea'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        reference: json['reference'] as String,
        isRead: json['isRead'] as bool,
      );
  String get message =>
      '${amountToea > 0 ? 'Received' : 'Sent'} K ${(amountToea.abs() / 100).toStringAsFixed(2)} · Fictional funds';
}

class NotificationSnapshot {
  const NotificationSnapshot(this.items, this.unreadCount);
  final List<TransferNotification> items;
  final int unreadCount;
}

abstract interface class TransferNotificationGateway {
  Future<NotificationSnapshot> load(String owner);
  Future<void> markRead(String owner, String id);
}

class TransferNotificationStore extends ChangeNotifier {
  // Gateway is optional until Supabase startup completes.
  TransferNotificationStore({TransferNotificationGateway? gateway})
    // ignore: prefer_initializing_formals
    : _gateway = gateway;
  TransferNotificationGateway? _gateway;
  String? _owner;
  int _epoch = 0, _revision = 0;
  bool _disposed = false, _loading = false;
  final Set<String> _marking = {};
  List<TransferNotification> _items = [];
  int _unread = 0;
  String? _error;
  List<TransferNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _unread;
  String? get accountId => _owner;
  String? get error => _error;
  bool get loading => _loading;
  void configure(TransferNotificationGateway gateway) {
    _gateway = gateway;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> useAccount(String? owner) async {
    if (_owner == owner) return;
    _epoch++;
    _owner = owner;
    _items = [];
    _unread = 0;
    _error = null;
    _loading = false;
    _marking.clear();
    _notify();
    await refresh();
  }

  Future<void> refresh() async {
    final owner = _owner;
    final epoch = _epoch;
    final revision = _revision;
    if (_disposed ||
        owner == null ||
        _gateway == null ||
        _loading ||
        _marking.isNotEmpty) {
      return;
    }
    _loading = true;
    _notify();
    try {
      final result = await _gateway!.load(owner);
      if (_disposed || epoch != _epoch || revision != _revision) return;
      _items = result.items;
      _unread = result.unreadCount;
      _error = null;
    } catch (_) {
      if (epoch == _epoch) {
        _error = 'Could not update notifications. Connect and retry.';
      }
    } finally {
      if (epoch == _epoch) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> markRead(String id) async {
    final owner = _owner;
    final epoch = _epoch;
    if (_disposed ||
        owner == null ||
        _gateway == null ||
        _marking.contains(id) ||
        !_items.any((n) => n.id == id && !n.isRead)) {
      return;
    }
    _marking.add(id);
    try {
      await _gateway!.markRead(owner, id);
      if (_disposed || epoch != _epoch) return;
      _revision++;
      _items = _items
          .map(
            (n) => n.id != id
                ? n
                : TransferNotification(
                    id: n.id,
                    title: n.title,
                    amountToea: n.amountToea,
                    createdAt: n.createdAt,
                    reference: n.reference,
                    isRead: true,
                  ),
          )
          .toList();
      if (_unread > 0) _unread--;
      _error = null;
      _notify();
    } catch (_) {
      if (epoch == _epoch) {
        _error = 'Could not mark this notification as read. Please retry.';
        _notify();
      }
    } finally {
      if (epoch == _epoch) _marking.remove(id);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    super.dispose();
  }
}

final transferNotifications = TransferNotificationStore();
