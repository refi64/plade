import 'usage.dart';
import 'value.dart';

/// A holder for an eventual value given on the command line.
class ValueHolder<T> {
  T? _value;

  ValueHolder._([this._value]);

  /// The value given on the command line. Attempting to access this before
  /// arguments are parsed will throw an exception.
  T get value => _value as T;

  @override
  String toString() => _value?.toString() ?? '<empty>';
}

/// A holder for the eventual value of an argument.
class Arg<T> extends ValueHolder<T> {
  final String name;
  bool _wasGiven = false;

  Arg._(this.name, [T? value]) : super._(value);

  /// Whether or not this parameter was given on the command line. If `false`,
  /// then [value] will just hold the default.
  bool get wasGiven => _wasGiven;
}

/// A non-exported extension for [ValueHolder] designed for internal use.
extension PrivateValueHolder<T> on ValueHolder<T> {
  bool get isValueEmpty => _value == null;
}

abstract class ValueTarget<T> {
  String get name;
  ValueParser<T> get parser;
  void _fill(T value);
}

/// A non-exported extension for [ValueTarget] designed for internal use.
extension PrivateValueTarget<T> on ValueTarget<T> {
  void parseAndFill(String value) => _fill(parser(value));
}

/// A representation of the requirement state of an argument. Can mandate that
/// the argument is mandatory or optional (with a default).
class Requires<U> {
  final bool isMandatory;
  final U? defaultValue;

  const Requires._({required this.isMandatory, required this.defaultValue});

  factory Requires.mandatory() =>
      Requires._(isMandatory: true, defaultValue: null);
  factory Requires.optional(U defaultValue) =>
      Requires._(isMandatory: false, defaultValue: defaultValue);
}

abstract class Definition {
  final String name;
  final String? description;
  final UsageGroup? usageGroup;

  Definition(
      {required this.name,
      required this.description,
      required this.usageGroup});
}

abstract class ArgumentDefinition<T, U> extends Definition
    implements ValueTarget<T> {
  final Requires<U> requires;

  @override
  final ValueParser<T> parser;
  final ValuePrinter<T> printer;
  final Accumulator<T, U> accumulator;

  final Arg<U> valueHolder;

  ArgumentDefinition(
      {required String name,
      required String? description,
      required UsageGroup? usageGroup,
      required this.requires,
      required this.parser,
      required this.printer,
      required this.accumulator})
      : valueHolder = Arg._(name, requires.defaultValue),
        super(name: name, description: description, usageGroup: usageGroup);

  @override
  void _fill(T value) {
    valueHolder._value =
        accumulator(value: value, previous: valueHolder._value);
    valueHolder._wasGiven = true;
  }
}

class PositionalArgumentDefinition<T, U> extends ArgumentDefinition<T, U> {
  final bool isMulti;
  final bool? noOptionsFollowing;

  PositionalArgumentDefinition(
      {required String name,
      required String? description,
      required UsageGroup? usageGroup,
      required Requires<U> requires,
      required ValueParser<T> parser,
      required ValuePrinter<T> printer,
      required Accumulator<T, U> accumulator,
      required this.isMulti,
      required this.noOptionsFollowing})
      : super(
            name: name,
            description: description,
            usageGroup: usageGroup,
            requires: requires,
            parser: parser,
            printer: printer,
            accumulator: accumulator);
}

/// Can be passed to the `inverse` argument of [ArgParser] flag methods to
/// disable the inverse completely. See [ArgParser.addMultiFlag] for more
/// information.
const disableFlagInverse = '';

class Flag {
  final String? inverse;

  Flag({this.inverse});

  Flag withInverse(String? inverse) => Flag(inverse: inverse);
}

class OptionArgumentDefinition<T, U> extends ArgumentDefinition<T, U> {
  final String? valueDescription;
  final String? short;
  final Flag? flag;

  OptionArgumentDefinition(
      {required String name,
      required String? description,
      required this.valueDescription,
      required UsageGroup? usageGroup,
      required U defaultValue,
      required ValueParser<T> parser,
      required ValuePrinter<T> printer,
      required Accumulator<T, U> accumulator,
      required this.short,
      required this.flag})
      : super(
            name: name,
            description: description,
            usageGroup: usageGroup,
            requires: Requires.optional(defaultValue),
            parser: parser,
            printer: printer,
            accumulator: accumulator);

  // Option arguments always have a default, so this case should not fail unless
  // there is a bug in this library.
  U get defaultValue => requires.defaultValue as U;
}

class CommandSetDefinition<T> implements ValueTarget<T> {
  @override
  final String name = 'command';
  @override
  final ValueParser<T> parser;
  final ValuePrinter<T> printer;
  final ValueHolder<T> valueHolder;

  CommandSetDefinition({required this.parser, required this.printer})
      : valueHolder = ValueHolder._();

  @override
  void _fill(T value) => valueHolder._value = value;
}

class CommandDefinition extends Definition {
  final ArgumentSet _args;

  CommandDefinition(
      {required String name,
      required String? description,
      required UsageGroup? usageGroup,
      required ArgumentSet args})
      : _args = args,
        super(name: name, description: description, usageGroup: usageGroup);

  ArgumentSet get args => ArgumentSet.unmodifiable(_args);
}

class ArgumentSet {
  final List<PositionalArgumentDefinition> positional;
  final Map<String, OptionArgumentDefinition> options;
  final Map<String, String> shortToLong;
  final Map<String, CommandDefinition> commands;

  CommandSetDefinition? _commandSet;

  final bool _mutable;

  CommandSetDefinition? get commandSet => _commandSet;

  set commandSet(CommandSetDefinition? commandSet) {
    if (!_mutable) {
      throw UnsupportedError('Cannot modify unmodifiable ArgumentSet');
    }

    _commandSet = commandSet;
  }

  ArgumentSet()
      : positional = <PositionalArgumentDefinition>[],
        options = <String, OptionArgumentDefinition>{},
        shortToLong = <String, String>{},
        commands = <String, CommandDefinition>{},
        _mutable = true;

  ArgumentSet.subCommand(ArgumentSet parent)
      : positional = List.of(parent.positional),
        options = Map.of(parent.options),
        shortToLong = Map.of(parent.shortToLong),
        // Always clear the commands.
        commands = <String, CommandDefinition>{},
        _mutable = true;

  ArgumentSet.unmodifiable(ArgumentSet other)
      : positional = List.unmodifiable(other.positional),
        options = Map.unmodifiable(other.options),
        shortToLong = Map.unmodifiable(other.shortToLong),
        commands = Map.unmodifiable(other.commands),
        _commandSet = other.commandSet,
        _mutable = false;

  Iterable<MapEntry<String, Definition>> allDefinitions(
      {required bool includeInverse}) sync* {
    yield* commands.entries;
    yield* positional.map((p) => MapEntry(p.name, p));

    var optionsIter = options.entries;
    if (!includeInverse) {
      optionsIter = optionsIter.where((e) =>
          e.value is! OptionArgumentDefinition ||
          e.key != e.value.flag?.inverse);
    }
    yield* optionsIter;
  }
}
