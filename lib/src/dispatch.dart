import 'dart:async';

import '../plade.dart';
import '../unstable.dart';

/// A `.then()` method for [FutureOr] that will run its function instantly if
/// the value is not a [Future].
extension _FutureOrThen on FutureOr<void> {
  FutureOr<void> then(FutureOr<void> Function() next) =>
      this is Future ? (this as Future<void>).then((_) => next()) : next();
}

/// A context of all "parent" handlers. This can be used by [Handler.run] on a
/// subcommand to access the [Handler] of parent command handlers / the root
/// app handler, like a lightweight service container.
class HandlerContext {
  final _parents = <Handler>[];

  HandlerContext._();

  T parent<T extends Handler>() => _parents.reversed.whereType<T>().last;

  void _add(Handler handler) {
    _parents.add(handler);
  }
}

/// A class that can register arguments with an [ArgParser] and then run after
/// parsing.
abstract class Handler {
  CommandSet? _commandSet;

  void register(ArgParser parser);
  FutureOr<void> run(HandlerContext context);
}

/// An interface that a [Handler] can implement to register subcommands. If this
/// is implemented, then its [Handler.run] method will be called *before* any
/// subcommand's [Handler.run].
abstract class WithCommands<T> implements Handler {
  CommandHandlerSet<T> get commands;
}

extension _Run on Handler {
  FutureOr<void> _runWithCommands(HandlerContext context) {
    var withCommands = this is WithCommands ? this as WithCommands : null;
    if (withCommands != null) {
      withCommands.commands._selected = _commandSet!.selected;
    }

    return run(context).then(() {
      if (withCommands != null) {
        context._add(this);

        dynamic selected = _commandSet!.selected;
        var handler =
            withCommands.commands.handlers.where((h) => h.id == selected).first;
        return handler._runWithCommands(context);
      }
    });
  }
}

/// A [Handler] for handling a subcommand.
abstract class CommandHandler<T> extends Handler {
  T get id;

  String? get description => null;
  UsageGroup? get usageGroup => null;
}

/// A set of [CommandHandler] instances representing subcommands.
class CommandHandlerSet<T> {
  final List<CommandHandler<T>> _handlers;
  final ValueParser<T> parser;
  final ValuePrinter<T>? printer;
  late T _selected;

  CommandHandlerSet.custom(this._handlers,
      {required this.parser, this.printer});

  static CommandHandlerSet<String> from(
          List<CommandHandler<String>> handlers) =>
      CommandHandlerSet.custom(handlers, parser: idValueParser);

  List<CommandHandler<T>> get handlers => List.unmodifiable(_handlers);

  void add(CommandHandler<T> handler) => _handlers.add(handler);
  void addAll(Iterable<CommandHandler<T>> handlers) =>
      _handlers.addAll(handlers);

  T get selected => _selected;
}

abstract class AppHandler extends Handler {
  bool get addHelp => true;
  UsageInfo get usageInfo => UsageInfo();
  UsagePrinter? get usagePrinter => null;
  ArgConfig get config => ArgConfig.defaultConfig;

  FutureOr<void> _runApp(void Function(AppArgParser parser) runParser) {
    var parser = AppArgParser(
        info: usageInfo, usagePrinter: usagePrinter, config: config);

    if (addHelp) {
      parser.addHelpOption();
    }

    register(parser);
    if (this is WithCommands) {
      _registerCommands<dynamic>(parser, this as WithCommands);
    }

    runParser(parser);

    return _runWithCommands(HandlerContext._());
  }

  FutureOr<void> runApp(List<String> args) =>
      _runApp((parser) => parser.parse(args));

  FutureOr<void> runAppOrQuit(List<String> args) =>
      _runApp((parser) => parser.parseOrQuit(args));
}

void _registerCommands<T>(ArgParser parent, WithCommands<T> parentHandler) {
  if (parentHandler.commands.handlers.isEmpty) {
    return;
  }

  var commands = parent.addCommands(
      parser: parentHandler.commands.parser,
      printer: parentHandler.commands.printer);
  parentHandler._commandSet = commands;

  for (var handler in parentHandler.commands.handlers) {
    var parser = commands.addCommand(handler.id,
        description: handler.description, usageGroup: handler.usageGroup);
    handler.register(parser);
    if (handler is WithCommands) {
      _registerCommands<dynamic>(parser, handler as WithCommands);
    }
  }
}
