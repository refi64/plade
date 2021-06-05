// This is an example of using Plade's class-based command APIs. Note that this
// file assumes you already saw plade_example, since the ArgParser methods will
// be re-used here in the same way.

import 'dart:async';

import 'package:plade/plade.dart';
import 'package:plade/dispatch.dart';

// With the dispatch API, commands are represented by a CommandHandler, with the
// generic type being the type used to hold the command value itsef. Here, a
// String is used (unlike the other example which uses an enum).
class CommandAdd extends CommandHandler<String> {
  // Command name and description are below.

  @override
  final String id = 'add';

  @override
  final String description = 'Add two numbers';

  // These need to be 'late' since they're assigned in .register below.
  late Arg<int> a;
  late Arg<int> b;

  // register() is called to register the arguments with the parser.
  @override
  void register(ArgParser parser) {
    a = parser.addPositional('a', parser: intValueParser);
    b = parser.addPositional('b', parser: intValueParser);
  }

  // When run() is called, we can assume that this command's arguments were
  // parsed successfully. In addition, the HandlerContext lets us get "parent"
  // commands or the main handler instance itself.
  @override
  void run(HandlerContext context) {
    var parent = context.parent<DispatchExampleHandler>();

    if (parent.verbose.value >= 2) {
      print('V2: a: $a');
      print('V2: b: $b');
    }

    print(a.value + b.value);
  }
}

// Defines another command...not much special here.
class CommandEcho extends CommandHandler<String> {
  @override
  final String id = 'echo';

  @override
  final String description = 'Print a string';

  late Arg<String> str;
  late Arg<int> lines;

  void _checkAboveZero(int n) {
    if (n <= 0) {
      throw ValueParserException('Must be >0');
    }
  }

  @override
  void register(ArgParser parser) {
    str = parser.addPositionalS('string',
        description: 'The string', requires: Requires.optional(''));
    lines = parser.addOption('count',
        short: 'c',
        defaultValue: 1,
        parser: intValueParser.also(_checkAboveZero),
        description: 'Number of times to print the line (default: 1)');
  }

  @override
  void run(HandlerContext context) {
    Iterable.generate(lines.value, (_) => str.value).forEach(print);
  }
}

// The AppHandler is the main entry point to the class-based API. If your app
// has subcommands, you'll also want to implement WithCommands<CommandType>, as
// shown here.
class DispatchExampleHandler extends AppHandler
    implements WithCommands<String> {
  @override
  final usageInfo = UsageInfo(
      application: 'dispatch-example',
      prologue: 'This is another boring example.',
      epilogue: 'Copyright Foo Bar Productions Inc.');

  // The CommandHandlerSet is a wrapper over a list of commands, where you can
  // also specify a custom parser/printer and, after parsing, get the selected
  // command.
  @override
  final commands = CommandHandlerSet.from([CommandAdd(), CommandEcho()]);

  late Arg<int> verbose;

  @override
  void register(ArgParser parser) {
    var loggingGroup = parser.createUsageGroup('Logging options');

    verbose = parser.addMultiFlag('verbose',
        short: 'v',
        usageGroup: loggingGroup,
        description: 'Increase verbosity',
        defaultValue: 0,
        accumulator: flagCountAccumulator);
  }

  @override
  FutureOr<void> run(HandlerContext context) {
    // This will be run *before* the selected command's run() is called.
    if (verbose.value >= 1) {
      print('V1: command: ${commands.selected}');
    }
  }
}

void main(List<String> args) => DispatchExampleHandler().runAppOrQuit(args);
