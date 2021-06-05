import 'dart:io';

import 'definition.dart';
import 'config.dart';
import 'parser_base.dart';
import 'parser_context.dart';
import 'usage.dart';
import 'value.dart';

/// A base argument parser, shared by [AppArgParser] and [CommandParser].
///
/// Methods ending with `S` are shorthand for adding positionals and options
/// that parse strings, by setting the `parser` to [idValueParser]. Similarly,
/// methods ending in `N` use `null` as the default value. Methods ending in
/// `SN` combine both: they parse strings with `null` as a default.
class ArgParser {
  final UsageInfo info;
  final UsageContext usageContext;
  final UsagePrinter usagePrinter;
  final ArgParserBase _base;
  final _commandParsers = <String, CommandParser>{};

  ArgParser._(
      {required this.info,
      required this.usageContext,
      required this.usagePrinter,
      required ArgParserBase base})
      : _base = base;

  /// A list of all registered arguments. This interface is not guaranteed to be
  /// stable!
  ArgumentSet get args => _base.args;

  // A map of all registered subcommands, by their ID after being passed to the
  // CommandSet's printer. This interface is not guaranteed to be stable!
  Map<String, CommandParser> get commandParsers =>
      Map.unmodifiable(_commandParsers);

  /// A list of all registered usage groups. This interface is not guaranteed to
  /// be stable!
  Set<UsageGroup> get usageGroups => _base.usageGroups;

  /// Creates a new usage group with the given name.
  UsageGroup createUsageGroup(String name) => _base.createUsageGroup(name);

  /// Shorthand for [addPositional] for strings with a default value of `null`.
  Arg<String?> addPositionalSN(String name,
          {String? description,
          UsageGroup? usageGroup,
          bool? noOptionsFollowing}) =>
      addPositional(name,
          description: description,
          usageGroup: usageGroup,
          requires: Requires.optional(null),
          parser: idValueParser,
          noOptionsFollowing: noOptionsFollowing);

  /// Shorthand for [addPositional] for strings.
  Arg<String> addPositionalS(String name,
          {String? description,
          UsageGroup? usageGroup,
          Requires<String>? requires,
          bool? noOptionsFollowing}) =>
      addPositional(name,
          description: description,
          usageGroup: usageGroup,
          requires: requires,
          parser: idValueParser,
          noOptionsFollowing: noOptionsFollowing);

  /// Shorthand for [addPositional] with a default value of `null`.
  Arg<T?> addPositionalN<T>(String name,
          {String? description,
          UsageGroup? usageGroup,
          required ValueParser<T> parser,
          ValuePrinter<T?>? printer,
          bool? noOptionsFollowing}) =>
      addPositional(name,
          description: description,
          usageGroup: usageGroup,
          requires: Requires.optional(null),
          parser: parser,
          printer: printer,
          noOptionsFollowing: noOptionsFollowing);

  /// Adds a new positional argument.
  ///
  /// If [noOptionsFollowing] is `true`, all arguments after this positional
  /// will be parsed as positionals, not options.
  Arg<T> addPositional<T>(String name,
          {String? description,
          UsageGroup? usageGroup,
          Requires<T>? requires,
          required ValueParser<T> parser,
          ValuePrinter<T>? printer,
          bool? noOptionsFollowing}) =>
      _base.addPositional(name,
          description: description,
          usageGroup: usageGroup,
          requires: requires,
          parser: parser,
          printer: printer,
          accumulator: discardAccumulator,
          isMulti: false,
          noOptionsFollowing: noOptionsFollowing);

  /// Shorthand for [addMultiPositional] for strings.
  Arg<U> addMultiPositionalS<U>(String name,
          {String? description,
          UsageGroup? usageGroup,
          Requires<U>? requires,
          required Accumulator<String, U> accumulator,
          bool? noOptionsFollowing}) =>
      addMultiPositional(name,
          description: description,
          usageGroup: usageGroup,
          requires: requires,
          parser: idValueParser,
          accumulator: accumulator,
          noOptionsFollowing: noOptionsFollowing);

  /// Adds a new positional argument that can take multiple values.
  ///
  /// If [noOptionsFollowing] is `true`, all arguments after this positional
  /// will be parsed as positionals, not options.
  Arg<U> addMultiPositional<T, U>(String name,
          {String? description,
          UsageGroup? usageGroup,
          Requires<U>? requires,
          required ValueParser<T> parser,
          ValuePrinter<T>? printer,
          required Accumulator<T, U> accumulator,
          bool? noOptionsFollowing}) =>
      _base.addPositional(name,
          description: description,
          usageGroup: usageGroup,
          requires: requires,
          parser: parser,
          printer: printer,
          accumulator: accumulator,
          isMulti: true,
          noOptionsFollowing: noOptionsFollowing);

  /// Shorthand for [addOption] for strings.
  Arg<String> addOptionS(String name,
          {String? description,
          String? valueDescription,
          UsageGroup? usageGroup,
          String? short,
          required String defaultValue}) =>
      addOption(name,
          description: description,
          valueDescription: valueDescription,
          usageGroup: usageGroup,
          short: short,
          defaultValue: defaultValue,
          parser: idValueParser);

  /// Shorthand for [addOption] for strings with a default value of `null`.
  Arg<String?> addOptionSN(String name,
          {String? description,
          String? valueDescription,
          UsageGroup? usageGroup,
          String? short}) =>
      addOption(name,
          description: description,
          valueDescription: valueDescription,
          usageGroup: usageGroup,
          short: short,
          defaultValue: null,
          parser: idValueParser);

  /// Shorthand for [addOption] with a default value of `null`.
  Arg<T?> addOptionN<T>(String name,
          {String? description,
          UsageGroup? usageGroup,
          String? valueDescription,
          String? short,
          required ValueParser<T> parser,
          ValuePrinter<T>? printer}) =>
      addOption(name,
          description: description,
          valueDescription: valueDescription,
          usageGroup: usageGroup,
          short: short,
          defaultValue: null,
          parser: parser);

  /// Adds a new option.
  ///
  /// If [short] is not null, it will be used as a short option alias for this
  /// long option.
  Arg<T> addOption<T>(String name,
          {String? description,
          String? valueDescription,
          UsageGroup? usageGroup,
          String? short,
          required T defaultValue,
          required ValueParser<T> parser,
          ValuePrinter<T>? printer}) =>
      addMultiOption(name,
          description: description,
          valueDescription: valueDescription,
          usageGroup: usageGroup,
          short: short,
          defaultValue: defaultValue,
          parser: parser,
          accumulator: discardAccumulator);

  /// Shorthand for [addMultiOption] for strings.
  Arg<U> addMultiOptionS<U>(String name,
          {String? description,
          String? valueDescription,
          UsageGroup? usageGroup,
          String? short,
          required U defaultValue,
          required Accumulator<String, U> accumulator}) =>
      addMultiOption(name,
          description: description,
          valueDescription: valueDescription,
          usageGroup: usageGroup,
          short: short,
          defaultValue: defaultValue,
          parser: idValueParser,
          accumulator: accumulator);

  /// Shorthand for [addMultiOption] for strings with a default value of `null`.
  Arg<U?> addMultiOptionSN<U>(String name,
          {String? description,
          String? valueDescription,
          String? short,
          required Accumulator<String, U> accumulator}) =>
      addMultiOption(name,
          description: description,
          valueDescription: valueDescription,
          short: short,
          defaultValue: null,
          parser: idValueParser,
          accumulator: accumulator);

  /// Shorthand for [addMultiOption] with a default value of `null`.
  Arg<U?> addMultiOptionN<T, U>(String name,
          {String? description,
          String? valueDescription,
          UsageGroup? usageGroup,
          String? short,
          required ValueParser<T> parser,
          ValuePrinter<T>? printer,
          required Accumulator<T, U> accumulator}) =>
      addMultiOption(name,
          description: description,
          valueDescription: valueDescription,
          usageGroup: usageGroup,
          short: short,
          defaultValue: null,
          parser: parser,
          printer: printer,
          accumulator: accumulator);

  /// Adds a new option that can be passed multiple times.
  ///
  /// If [short] is not null, it will be used as a short option alias for this
  /// long option.
  Arg<U> addMultiOption<T, U>(String name,
          {String? description,
          String? valueDescription,
          UsageGroup? usageGroup,
          String? short,
          required U defaultValue,
          required ValueParser<T> parser,
          ValuePrinter<T>? printer,
          required Accumulator<T, U> accumulator}) =>
      _base.addOption(name,
          description: description,
          valueDescription: valueDescription,
          usageGroup: usageGroup,
          short: short,
          flag: null,
          defaultValue: defaultValue,
          parser: parser,
          printer: printer,
          accumulator: accumulator);

  /// Adds a new boolean flag.
  ///
  /// If [short] is not null, it will be used as a short option alias for this
  /// long option.
  ///
  /// If [inverse] is not null, it will be used as the name of an "inverse"
  /// flag, i.e. a flag that, when given, will set this to `false` rather than
  /// `true`. If `null`, then the default inverse generator specified in this
  /// parser's [ArgConfig] will be used. If you want to opt this flag out of
  /// inverse generation altogether, pass [disableFlagInverse] to [inverse].
  Arg<bool> addFlag(String name,
          {String? description,
          UsageGroup? usageGroup,
          String? short,
          String? inverse,
          bool defaultValue = false,
          void Function(bool value)? onParse}) =>
      addMultiFlag(name,
          description: description,
          usageGroup: usageGroup,
          short: short,
          inverse: inverse,
          defaultValue: defaultValue,
          accumulator: discardAccumulator,
          onParse: onParse);

  /// Adds a new boolean flag that can be passed multiple times.
  ///
  /// If [short] is not null, it will be used as a short option alias for this
  /// long option.
  ///
  /// If [inverse] is not null, it will be used as the name of an "inverse"
  /// flag, i.e. a flag that, when given, will set this to `false` rather than
  /// `true`. If `null`, then the default inverse generator specified in this
  /// parser's [ArgConfig] will be used. If you want to opt this flag out of
  /// inverse generation altogether, pass [disableFlagInverse] to [inverse].
  Arg<U> addMultiFlag<U>(String name,
          {String? description,
          UsageGroup? usageGroup,
          String? short,
          String? inverse,
          required U defaultValue,
          required Accumulator<bool, U> accumulator,
          void Function(bool value)? onParse}) =>
      _base.addOption(name,
          description: description,
          valueDescription: null,
          usageGroup: usageGroup,
          short: short,
          flag: Flag(inverse: inverse),
          defaultValue: defaultValue,
          parser: boolValueParser.also(onParse ?? (_) {}),
          accumulator: accumulator);

  /// Shorthand for [addCommands] for strings.
  CommandSet<String> addCommandsS() => addCommands(parser: idValueParser);

  /// Sets up this parser to parse subcommands.
  CommandSet<T> addCommands<T>(
          {required ValueParser<T> parser, ValuePrinter<T>? printer}) =>
      CommandSet._(
          this,
          _base.addCommands<T>(
              parser: parser, printer: printer ?? toStringValuePrinter));

  /// Prints the usage information using this parser's [usagePrinter] to the
  /// given [sink]. If [showShortUsage] is `true`, then the printed usage will
  /// only contain the "Usage:" line showing a brief summary of how to use
  /// this parser.
  void printUsage({StringSink? sink, bool showShortUsage = false}) =>
      usagePrinter(args, info, usageContext,
          sink: sink ?? stdout, showShortUsage: showShortUsage);
}

/// A set of commands that can be parsed by its parent [ArgParser].
class CommandSet<T> {
  final ArgParser parent;
  final CommandSetBase<T> _base;

  CommandSet._(this.parent, this._base);

  /// Adds a new command with the given [id] to this command set.
  CommandParser addCommand(T id,
      {String? description, UsageGroup? usageGroup}) {
    var added = _base.addCommand(
        id: id, description: description, usageGroup: usageGroup);
    var parser = CommandParser._(parent, added.command, added.subBase);
    parent._commandParsers[_base.commandSet.printer(id)] = parser;
    return parser;
  }

  /// The ID of the command that the user selected. Attempting to access this
  /// before arguments are parsed will throw an exception.
  T get selected => _base.commandSet.valueHolder.value;
}

/// An argument parser, the primary entry point to this library.
class AppArgParser extends ArgParser {
  AppArgParser(
      {UsageInfo info = const UsageInfo(),
      UsagePrinter? usagePrinter,
      ArgConfig config = ArgConfig.defaultConfig})
      : super._(
            info: info,
            usageContext: UsageContext(),
            usagePrinter: usagePrinter ?? DefaultUsagePrinter.create(),
            base: ArgParserBase(config));

  /// Parses the argument list in [args], throwing an [ArgParsingError] if the
  /// argument parsing fails.
  void parse(List<String> args) =>
      ParserContext.parse(_base.config, _base.args, args);

  /// Parses the argument list in [args], printing the error and usage to [sink]
  /// (defaults to [stderr]) if an error occurs.
  void parseOrQuit(List<String> args,
      {StringSink? sink, bool showShortUsage = true}) {
    try {
      parse(args);
    } on ArgParsingError catch (ex) {
      sink ??= stderr;

      sink.writeln(ex);
      printUsage(sink: sink, showShortUsage: showShortUsage);

      exit(1);
    }
  }

  /// Adds a help option to this parser that prints the usage.
  void addHelpOption(
      {String name = 'help',
      String? short = 'h',
      String description = 'Show this help',
      StringSink? sink}) {
    addFlag(name, short: short, description: description, onParse: (_) {
      ArgParser currentParser = this;

      while (true) {
        var commandSet = currentParser.args.commandSet;
        if (commandSet == null || commandSet.valueHolder.isValueEmpty) {
          break;
        }

        var commandId = commandSet.printer(commandSet.valueHolder.value);
        currentParser = currentParser.commandParsers[commandId]!;
      }

      currentParser.printUsage(sink: sink, showShortUsage: false);
      exit(0);
    });
  }
}

/// An [ArgParser] returned by [CommandSet.addCommand] that adds arguments to
/// a single command.
class CommandParser extends ArgParser {
  CommandParser._(
      ArgParser parent, CommandDefinition command, ArgParserBase base)
      : super._(
            info: parent.info,
            usageContext: parent.usageContext.subCommand(command),
            usagePrinter: parent.usagePrinter,
            base: base);

  CommandDefinition get command => usageContext.path.last;
}
