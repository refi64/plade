import 'package:plade/plade.dart';

import 'definition.dart';
import 'config.dart';
import 'value.dart';

/// A split option, with an option name and an optional value provided.
class _OptionSplit {
  final String optionName;
  final String? value;

  _OptionSplit._({required this.optionName, required this.value});

  static _OptionSplit forLongOption(String optionText) {
    if (optionText.contains('=')) {
      var parts = optionText.split('=');
      return _OptionSplit._(
          optionName: parts[0], value: parts.sublist(1).join('='));
    } else {
      return _OptionSplit._(optionName: optionText, value: null);
    }
  }

  static _OptionSplit forShortOption(String optionText) {
    if (optionText.length >= 2) {
      return optionText.substring(1, 2) == '='
          ? forLongOption(optionText)
          : _OptionSplit._(
              optionName: optionText.substring(0, 1),
              value: optionText.substring(1));
    } else {
      return _OptionSplit._(optionName: optionText, value: null);
    }
  }
}

/// The kind of argument parsing error encountered.
enum ArgParsingErrorKind {
  /// The given option was unknown.
  unknownOption,

  /// The argument's [ValueParser] threw a [ValueParserException] when parsing
  /// the argument's value.
  parsingValue,

  /// More positional arguments than available were given.
  tooManyPositionals,

  /// A command is required but was not given.
  missingCommand,

  /// Some positional arguments that are required were not given.
  missingPositionals,

  /// An option that requires a value was not given one.
  missingOptionValue,

  /// The given command was unknown.
  unknownCommand
}

/// An exception thrown when parsing arguments fails.
class ArgParsingError {
  final ArgParsingErrorKind kind;
  final String message;

  ArgParsingError.unknownOption({required String arg})
      : kind = ArgParsingErrorKind.unknownOption,
        message = 'Unknown option: $arg';

  ArgParsingError.parsingValue(
      {required String name, required String value, required String reason})
      : kind = ArgParsingErrorKind.parsingValue,
        message = 'Failed to parse $name[=$value]: $reason';

  ArgParsingError.tooManyPositionals(String positional)
      : kind = ArgParsingErrorKind.tooManyPositionals,
        message = 'Too many positional arguments: $positional';

  ArgParsingError.missingCommand()
      : kind = ArgParsingErrorKind.missingCommand,
        message = 'A command is required';

  ArgParsingError.missingPositionals(List<String> positionals)
      : kind = ArgParsingErrorKind.missingPositionals,
        message =
            'Missing required positional argument(s): ${positionals.join(', ')}';

  ArgParsingError.missingOptionValue(String option)
      : kind = ArgParsingErrorKind.missingOptionValue,
        message = 'Option $option requires a value';

  ArgParsingError.unknownCommand(String command)
      : kind = ArgParsingErrorKind.unknownCommand,
        message = 'Unknown command: $command';

  @override
  String toString() => message;
}

enum _ArgumentKind { positional, longOption, shortOption }

class _ParsedArgument {
  final _ArgumentKind kind;
  final String text;

  _ParsedArgument({required this.kind, required this.text});
}

class ParserContext {
  final ArgConfig config;
  final ArgumentSet argSet;

  /// The last option argumenet parsed without a value.
  ///
  /// Options can have their value given in a separate argument, i.e.
  /// `foo -a 1` and `foo -a1` are equivalent. In the former case, the option is
  /// saved here and then assigned when the second argument is read.
  OptionArgumentDefinition? _waitingForValue;

  /// Whether or not we are currently in a context where options cannot be
  /// parsed, i.e. only positional arguments can be parsed.
  var _optionsAvailable = true;

  /// The index into [argSet.positional] of the next positional argument.
  var _nextPositionalArg = 0;

  ParserContext._(this.config, this.argSet);

  static void parse(ArgConfig config, ArgumentSet argSet, List<String> args) =>
      ParserContext._(config, argSet)._parse(args);

  void _parse(List<String> args) {
    for (var i = 0; i < args.length; i++) {
      if (_waitingForValue != null) {
        _fillValueTarget(_waitingForValue!, args[i]);
        _waitingForValue = null;
        continue;
      }

      if (config.disableOptionsAfter == args[i]) {
        _optionsAvailable = false;
        continue;
      }

      var parsed = _parseArgument(args[i]);
      var argText = parsed.text;

      switch (parsed.kind) {
        case _ArgumentKind.positional:
          if (argSet.commands.isNotEmpty) {
            _parseCommand(argText, args.sublist(i + 1));
            return;
          }

          _parsePositional(argText);
          break;
        case _ArgumentKind.shortOption:
          _parseShortOption(argText);
          break;
        case _ArgumentKind.longOption:
          _parseLongOption(fullArg: args[i], argText: argText);
          break;
      }
    }

    var commandSet = argSet.commandSet;
    if (commandSet != null && commandSet.valueHolder.isValueEmpty) {
      throw ArgParsingError.missingCommand();
    }

    if (_nextPositionalArg < argSet.positional.length) {
      var remainingMandatory = argSet.positional
          .skip(_nextPositionalArg)
          // _nextPositionalArg may still be pointing to an already-parsed
          // argument if it can take multiple values. To handle that acse, we
          // need to skip all the arguments that laready have a value.
          .skipWhile((p) => p.valueHolder.wasGiven)
          .takeWhile((p) => p.requires.isMandatory)
          .toList();
      if (remainingMandatory.isNotEmpty) {
        throw ArgParsingError.missingPositionals(
            remainingMandatory.map((p) => p.name).toList());
      }
    }

    if (_waitingForValue != null) {
      throw ArgParsingError.missingOptionValue(_waitingForValue!.name);
    }
  }

  _ParsedArgument _parseArgument(String arg) {
    if (_optionsAvailable) {
      if (arg.startsWith(config.longPrefix)) {
        return _ParsedArgument(
            kind: _ArgumentKind.longOption,
            text: arg.substring(config.longPrefix.length));
      }

      var shortPrefix = config.shortPrefix;
      if (shortPrefix != null && arg.startsWith(shortPrefix)) {
        return _ParsedArgument(
            kind: _ArgumentKind.shortOption,
            text: arg.substring(shortPrefix.length));
      }
    }

    return _ParsedArgument(kind: _ArgumentKind.positional, text: arg);
  }

  void _parsePositional(String argText) {
    if (_nextPositionalArg == argSet.positional.length) {
      throw ArgParsingError.tooManyPositionals(argText);
    }

    var positional = argSet.positional[_nextPositionalArg];
    _fillValueTarget(positional, argText);

    if (!positional.isMulti) {
      // Make sure we only move on if this argument can take no more values.
      _nextPositionalArg++;
    }

    if (positional.noOptionsFollowing ?? config.noOptionsAfterPositional) {
      _optionsAvailable = false;
    }
  }

  void _parseCommand(String argText, List<String> args) {
    var command = argSet.commands[argText];
    if (command == null) {
      throw ArgParsingError.unknownCommand(argText);
    }

    _fillValueTarget(argSet.commandSet!, argText);

    parse(config, command.args, args);
  }

  void _parseLongOption({required String fullArg, required String argText}) {
    var split = _OptionSplit.forLongOption(argText);

    var option = _lookupOption(name: split.optionName, arg: fullArg);
    var value = split.value;

    if (value == null) {
      if (option.flag != null) {
        _fillValueTargetWithFlag(option,
            inverse: split.optionName == option.flag!.inverse);
      } else {
        _waitingForValue = option;
      }
    } else {
      _fillValueTarget(option, value);
    }
  }

  void _parseShortOption(String argText) {
    var i = 0;

    while (i < argText.length) {
      var short = argText.substring(i, i + 1);
      var isLastChar = i == argText.length - 1;
      var nextChar = !isLastChar ? argText.substring(i + 1, i + 2) : null;

      // Synthesize a string with just this short option for the error messages.
      var synthesizedFullArg = '-$short';
      var option = _lookupOptionByShort(short: short, arg: synthesizedFullArg);

      if (option.flag != null && nextChar != '=') {
        // This can never be the inverse, because inverses are not short
        // options.
        _fillValueTargetWithFlag(option, inverse: false);
        i++;
        continue;
      }

      if (isLastChar) {
        _waitingForValue = option;
      } else {
        var split = _OptionSplit.forShortOption(argText.substring(i));
        _fillValueTarget(option, split.value!);
      }

      break;
    }
  }

  OptionArgumentDefinition _lookupOption(
      {required String name, required String arg}) {
    var option = argSet.options[name];
    if (option == null) {
      throw ArgParsingError.unknownOption(arg: arg);
    }

    return option;
  }

  OptionArgumentDefinition _lookupOptionByShort(
      {required String short, required String arg}) {
    var longOptionName = argSet.shortToLong[short];
    if (longOptionName == null) {
      throw ArgParsingError.unknownOption(arg: arg);
    }

    // This should never be null if the argSet were created correctly.
    return argSet.options[longOptionName]!;
  }

  void _fillValueTargetWithFlag(OptionArgumentDefinition option,
      {required bool inverse}) {
    _fillValueTarget(option, (!inverse).toString());
  }

  void _fillValueTarget(ValueTarget target, String rawValue) {
    try {
      target.parseAndFill(rawValue);
    } on ValueParserException catch (ex) {
      throw ArgParsingError.parsingValue(
          name: target.name, value: rawValue, reason: ex.reason);
    }
  }
}
