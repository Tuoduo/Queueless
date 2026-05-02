import '../events/event_bus.dart';

/// Base Command interface for Command Pattern.
/// Wraps user actions into command objects for tracking and undo support.
abstract class Command {
  String get description;
  Future<void> execute();
  Future<void> undo();
}

/// Command History for tracking and undo operations
class CommandHistory {
  static final CommandHistory _instance = CommandHistory._internal();
  factory CommandHistory() => _instance;
  CommandHistory._internal();

  final List<Command> _history = [];
  final EventBus _eventBus = EventBus();

  List<Command> get history => List.unmodifiable(_history);

  Future<void> executeCommand(Command command) async {
    await command.execute();
    _history.add(command);
  }

  Future<void> undoLast() async {
    if (_history.isNotEmpty) {
      final command = _history.removeLast();
      await command.undo();
    }
  }

  bool get canUndo => _history.isNotEmpty;

  void clear() {
    _history.clear();
  }
}
