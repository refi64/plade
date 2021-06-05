import 'dart:io';
import 'dart:math';

import 'package:plade/src/definition.dart';

import 'substring.dart';

/// A set of attributes that a sink backed by a terminal may have.
abstract class TerminalAttributes {
  bool get supportsColors;
  int? get width;
}

/// A derivative of [TerminalAttributes] that uses ahead-of-time fixed values.
class FixedTerminalAttributes implements TerminalAttributes {
  @override
  final bool supportsColors;
  @override
  final int? width;

  const FixedTerminalAttributes(
      {required this.supportsColors, required this.width});

  static const FixedTerminalAttributes defaults =
      FixedTerminalAttributes(supportsColors: false, width: 80);
}

class _StdoutTerminalAttributes implements TerminalAttributes {
  final Stdout out;

  _StdoutTerminalAttributes(this.out);

  @override
  bool get supportsColors => out.hasTerminal;

  @override
  int? get width => out.hasTerminal ? out.terminalColumns : null;
}

/// A function that takes in a sink and returns the [TerminalAttributes] that
/// should be associated with the sink.
typedef TerminalAttributesFactory = TerminalAttributes Function(
    StringSink sink);

/// A default [TerminalAttributesFactory] that will determine the proper
/// terminal attributes if the [sink] is indeed a terminal, otherwise it uses
/// the defaults in [FixedTerminalAttributes.defaults].
TerminalAttributes defaultTerminalAttributesFactory(StringSink sink) {
  if (sink is Stdout) {
    return _StdoutTerminalAttributes(sink);
  } else {
    return FixedTerminalAttributes.defaults;
  }
}

/// A "wrapper" for text, taking in some [text] and a line [width] and returning
/// a list of lines for the wrapped text.
typedef TextWrapper = List<String> Function(String text, int width);

int _nearestMultiple(int n, {required int of}) => n - (n % of);

/// A default [TextWrapper] that wraps on word boundaries (determined by the
/// presence of spaces), using character wrapping as a fallback.
List<String> defaultTextWrapper(String text, int width) {
  var lines = <String>[];

  for (var line in text.split('\n')) {
    if (line.length < width) {
      lines.add(line);
      continue;
    }

    var buffer = StringBuffer();
    for (var word in line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
      var needsSpaceBeforeWord = buffer.isNotEmpty;
      var spaceNeeded = word.length + (needsSpaceBeforeWord ? 1 : 0);

      if (width - buffer.length < spaceNeeded) {
        lines.add(buffer.toString());
        buffer.clear();
        needsSpaceBeforeWord = false;

        if (word.length > width) {
          // Remove full line widths from the word.
          int i;
          for (i = 0;
              i < _nearestMultiple(word.length, of: width);
              i += width) {
            lines.add(word.substring(i, i + width));
          }

          // Save the rest to add to the start of a new line.
          word = word.substring(i);
        }
      }

      if (needsSpaceBeforeWord) {
        buffer.write(' ');
      }

      buffer.write(word);
    }

    if (buffer.isNotEmpty) {
      lines.add(buffer.toString());
    }
  }

  return lines;
}

/// A set of information that should be printed on the program's usage text.
class UsageInfo {
  final String? application;
  final String? prologue;
  final String? epilogue;

  const UsageInfo({this.application, this.prologue, this.epilogue});
}

/// A group that arguments can be associated with, so that the arguments will
/// be grouped under this group's name in the usage text.
class UsageGroup {
  final String name;

  UsageGroup._(this.name);

  @override
  int get hashCode => name.hashCode;
  @override
  bool operator ==(other) => other is UsageGroup && name == other.name;

  @override
  String toString() => 'UsageGroup($name)';
}

UsageGroup privateCreateUsageGroup(String name) => UsageGroup._(name);

/// A list of all nested commands that have been parsed, i.e. given `myapp a b`,
/// the list will contain `a` and `b`.
class UsageContext {
  final List<CommandDefinition> path;

  UsageContext._(List<CommandDefinition> path) : path = List.unmodifiable(path);

  factory UsageContext() => UsageContext._([]);

  UsageContext subCommand(CommandDefinition command) =>
      UsageContext._(List.of(path)..add(command));
}

/// A function that prints usage information to the given [sink]. If
/// [showShortUsage] is `true`, then this should only show a short "usage: "
/// section, otherwise it should show the full help.
typedef UsagePrinter = void Function(
    ArgumentSet args, UsageInfo info, UsageContext context,
    {required StringSink sink, required bool showShortUsage});

extension _WriteLines on StringSink {
  void writeLines(Iterable<String> lines) {
    writeAll(lines, '\n');
    writeln();
  }
}

/// A default implementation of [UsagePrinter].
class DefaultUsagePrinter {
  static final _padding = ' ' * 2;

  final TerminalAttributesFactory attributesFactory;
  final TextWrapper wrapper;

  DefaultUsagePrinter({required this.attributesFactory, required this.wrapper});

  String _formatDefinition(Definition definition,
      {required bool inShortUsage}) {
    if (definition is CommandDefinition) {
      if (inShortUsage) {
        throw StateError('command format in short usage line');
      }

      return definition.name;
    } else if (definition is PositionalArgumentDefinition) {
      return inShortUsage ? '<${definition.name}>' : definition.name;
    } else if (definition is OptionArgumentDefinition) {
      var buffer = StringBuffer();

      if (definition.short != null) {
        var separator = inShortUsage ? '|' : ', ';
        buffer.write('-${definition.short}$separator');
      }
      buffer.write('--');

      var flag = definition.flag;
      if (flag == null) {
        buffer.write(
            '${definition.name}=${definition.valueDescription ?? 'VALUE'}');
      } else {
        var inverse = flag.inverse;
        if (inverse != null) {
          var substring = longestCommonSubstring(definition.name, inverse);
          buffer.write(substring);
        } else {
          buffer.write(definition.name);
        }
        buffer.write('[=true|false]');
      }

      return inShortUsage ? '[${buffer.toString()}]' : buffer.toString();
    } else {
      throw ArgumentError.value(definition.toString());
    }
  }

  String _buildUsageLine(ArgumentSet args) {
    var parts = <String>[];

    if (args.commands.isNotEmpty) {
      parts.add('<command>');
    }

    for (var entry in args
        .allDefinitions(includeInverse: false)
        // Exclude commands on this line.
        .whereType<MapEntry<String, ArgumentDefinition>>()) {
      parts.add(_formatDefinition(entry.value, inShortUsage: true));
    }

    return parts.join(' ');
  }

  List<String> _wrap(String text, TerminalAttributes attributes) =>
      attributes.width != null ? wrapper(text, attributes.width!) : [text];

  void _printGroup(StringSink sink, TerminalAttributes attributes,
      String groupName, List<Definition> contents) {
    if (contents.isEmpty) {
      return;
    }

    sink.writeln();
    sink.writeln('$groupName:');
    sink.writeln();

    var argumentStrings = contents
        .map((def) => _formatDefinition(def, inShortUsage: false))
        .toList();

    var longestSize = argumentStrings.map((s) => s.length).reduce(max);
    var argStringLength = longestSize + (_padding.length * 2);
    int? maxDescriptionWidth;
    if (attributes.width != null) {
      var diff = attributes.width! - _padding.length - argStringLength;
      if (diff > 1) {
        maxDescriptionWidth = diff;
      }
    }

    for (var i = 0; i < contents.length; i++) {
      var definition = contents[i];
      var string = argumentStrings[i];

      sink.write(_padding);
      sink.write(string);

      var description = definition.description;
      if (description != null && description.isNotEmpty) {
        if (maxDescriptionWidth != null) {
          sink.write(' ' * (longestSize - string.length));
          sink.write(_padding);

          var lines = wrapper(description, maxDescriptionWidth);
          sink.writeln(lines.first);
          if (lines.length > 1) {
            // Make sure all other lines are padded on the left to make up for
            // the arg text.
            sink.writeLines(
                lines.skip(1).map((l) => ' ' * argStringLength + l));
          }
        } else {
          sink.writeln(description);
        }
      } else {
        sink.writeln();
      }
    }
  }

  void call(ArgumentSet args, UsageInfo info, UsageContext context,
      {required StringSink sink, required bool showShortUsage}) {
    var attributes = attributesFactory(sink);

    final commandsGroupName = 'Commands';
    final positionalGroupName = 'Positional arguments';
    final optionsGroupName = 'Options';

    var commandsGroup = <Definition>[];
    var positionalGroup = <Definition>[];
    var optionsGroup = <Definition>[];

    var usageGroups = <UsageGroup, List<Definition>>{};

    for (var entry in args.allDefinitions(includeInverse: false)) {
      var definition = entry.value;
      var group = definition.usageGroup;
      if (group != null) {
        usageGroups.update(group, (args) => args..add(definition),
            ifAbsent: () => [definition]);
      } else if (definition is CommandDefinition) {
        commandsGroup.add(definition);
      } else if (definition is PositionalArgumentDefinition) {
        positionalGroup.add(definition);
      } else if (definition is OptionArgumentDefinition) {
        optionsGroup.add(definition);
      } else {
        throw ArgumentError.value(definition);
      }
    }

    var usagePrefix = 'Usage: ${info.application ?? '<this application>'} ';
    if (context.path.isNotEmpty) {
      usagePrefix += context.path.map((c) => c.name).join();
    }

    sink.write(usagePrefix);

    sink.writeLines(_wrap(_buildUsageLine(args), attributes));

    if (!showShortUsage) {
      var prologue = info.prologue;
      if (prologue != null) {
        sink.writeln();
        sink.writeLines(_wrap(prologue, attributes));
      }

      _printGroup(sink, attributes, commandsGroupName, commandsGroup);
      _printGroup(sink, attributes, positionalGroupName, positionalGroup);
      _printGroup(sink, attributes, optionsGroupName, optionsGroup);
      for (var entry in usageGroups.entries) {
        _printGroup(sink, attributes, entry.key.name, entry.value);
      }

      sink.writeln();

      var epilogue = info.epilogue;
      if (epilogue != null) {
        sink.writeLines(_wrap(epilogue, attributes));
        sink.writeln();
      }
    }
  }

  static UsagePrinter create(
          {TerminalAttributesFactory attributesFactory =
              defaultTerminalAttributesFactory,
          TextWrapper wrapper = defaultTextWrapper}) =>
      DefaultUsagePrinter(
          attributesFactory: attributesFactory, wrapper: wrapper);
}
