import 'dart:async';

/// Lightweight event bus for cross-component communication.
///
/// Allows widgets to broadcast data change events without tight coupling.
/// For example, when a mutation occurs in one tab, other tabs can
/// listen for the event and refresh their data automatically.
///
/// Usage:
///   EventBus().fire(DataChangedEvent('clients'));
///   EventBus().on`<DataChangedEvent>`().listen((e) => refresh());
class EventBus {
  static final EventBus _instance = EventBus._();
  factory EventBus() => _instance;
  EventBus._();

  // UI mutations use the bus as an immediate invalidation signal. Synchronous
  // delivery keeps the ordering deterministic: a caller that fires an event
  // knows all current subscribers have observed it before the mutation flow
  // continues.
  final _controller = StreamController<Object>.broadcast(sync: true);

  /// Fire an event to all listeners.
  void fire(Object event) {
    _controller.add(event);
  }

  /// Listen for events of a specific type [T].
  Stream<T> on<T extends Object>() {
    return _controller.stream.where((e) => e is T).cast<T>();
  }

  /// Dispose the event bus.
  void dispose() {
    _controller.close();
  }
}

/// Event fired when data has been changed (created, updated, or deleted).
class DataChangedEvent {
  final String resourceType;
  final String? resourceId;
  final ChangeType changeType;

  const DataChangedEvent(
    this.resourceType, {
    this.resourceId,
    this.changeType = ChangeType.updated,
  });

  bool get isCreate => changeType == ChangeType.created;
  bool get isUpdate => changeType == ChangeType.updated;
  bool get isDelete => changeType == ChangeType.deleted;
}

enum ChangeType { created, updated, deleted }
