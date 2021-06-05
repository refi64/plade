import 'definition.dart';
import 'config.dart';
import 'usage.dart';
import 'value.dart';

class ArgParserBase {
  final ArgConfig config;
  final ArgumentSet _args;
  final _usageGroups = <UsageGroup>{};

  ArgParserBase(this.config) : _args = ArgumentSet();

  ArgParserBase.subCommand(ArgParserBase parent)
      : config = parent.config,
        _args = ArgumentSet.subCommand(parent.args);

  ArgumentSet get args => ArgumentSet.unmodifiable(_args);
  Set<UsageGroup> get usageGroups => Set.unmodifiable(_usageGroups);

  UsageGroup createUsageGroup(String name) {
    var group = privateCreateUsageGroup(name);
    if (_usageGroups.contains(group)) {
      throw ArgumentError.value(name, null, 'Duplicate usage group');
    }

    _usageGroups.add(group);
    return group;
  }

  Arg<U> addPositional<T, U>(String name,
      {required String? description,
      required UsageGroup? usageGroup,
      required Requires<U>? requires,
      required ValueParser<T> parser,
      required ValuePrinter<T>? printer,
      required Accumulator<T, U> accumulator,
      required bool isMulti,
      required bool? noOptionsFollowing}) {
    // XXX: Bad time complexity here, but it shouldn't really matter...
    if (_args.positional.any((p) => p.name == name)) {
      throw ArgumentError.value(name, 'name', 'Duplicate argument');
    }

    requires ??= Requires.mandatory();

    if (_args.positional.isNotEmpty) {
      var last = _args.positional.last;

      if (!last.requires.isMandatory && requires.isMandatory) {
        throw ArgumentError.value(name, null,
            'Mandatory positionals cannot come after optional ones');
      }

      if (last.isMulti) {
        throw ArgumentError.value(
            name, null, 'A multi-valued positional argument must be last');
      }
    }

    var def = PositionalArgumentDefinition<T, U>(
        name: name,
        description: description,
        usageGroup: usageGroup,
        requires: requires,
        parser: parser,
        printer: printer ?? toStringValuePrinter,
        accumulator: accumulator,
        isMulti: isMulti,
        noOptionsFollowing: noOptionsFollowing);

    _args.positional.add(def);
    return def.valueHolder;
  }

  Arg<U> addOption<T, U>(String name,
      {required String? description,
      required String? valueDescription,
      required UsageGroup? usageGroup,
      required String? short,
      required Flag? flag,
      required U defaultValue,
      required ValueParser<T> parser,
      ValuePrinter<T>? printer,
      required Accumulator<T, U> accumulator}) {
    if (_args.options.containsKey(name)) {
      throw ArgumentError.value(name, 'name', 'Duplicate argument');
    } else if (short != null) {
      if (_args.shortToLong.containsKey(short)) {
        throw ArgumentError.value(short, 'short', 'Duplicate argument');
      } else if (short.length != 1) {
        throw ArgumentError.value(short, 'short', 'Must be a single character');
      }
    }

    if (flag != null && flag.inverse == null) {
      flag = flag.withInverse(config.inverseGenerator?.call(name));
    }

    var def = OptionArgumentDefinition<T, U>(
        name: name,
        description: description,
        valueDescription: valueDescription,
        usageGroup: usageGroup,
        defaultValue: defaultValue,
        parser: parser,
        printer: printer ?? toStringValuePrinter,
        accumulator: accumulator,
        short: short,
        flag: flag);

    _args.options[name] = def;
    if (flag != null &&
        flag.inverse != null &&
        flag.inverse != disableFlagInverse) {
      _args.options[flag.inverse!] = def;
    }

    if (short != null) {
      _args.shortToLong[short] = name;
    }

    return def.valueHolder;
  }

  CommandSetBase<T> addCommands<T>(
      {required ValueParser<T> parser, required ValuePrinter<T> printer}) {
    if (_args.commandSet != null) {
      throw ArgumentError('Already added a command set');
    }

    var commandSet = CommandSetDefinition<T>(parser: parser, printer: printer);
    _args.commandSet = commandSet;
    return CommandSetBase._(parent: this, commandSet: commandSet);
  }
}

class AddedCommand {
  final ArgParserBase subBase;
  final CommandDefinition command;

  AddedCommand(this.subBase, this.command);
}

class CommandSetBase<T> {
  final ArgParserBase parent;
  final CommandSetDefinition<T> commandSet;

  CommandSetBase._({required this.parent, required this.commandSet});

  AddedCommand addCommand(
      {required T id,
      required String? description,
      required UsageGroup? usageGroup}) {
    if (parent._args.commands.containsKey(id)) {
      throw ArgumentError.value(id, 'name', 'Duplicate command');
    }

    var name = commandSet.printer(id);

    var subBase = ArgParserBase.subCommand(parent);
    var command = CommandDefinition(
        name: name,
        description: description,
        usageGroup: usageGroup,
        // Note that using _args is important, otherwise this will pass an
        // unmodifiable ArgumentSet copy.
        args: subBase._args);

    parent._args.commands[name] = command;

    return AddedCommand(subBase, command);
  }
}
