import 'dart:async';

import 'package:plade/plade.dart';
import 'package:plade/dispatch.dart';

class CommandAdd extends CommandHandler<String> {
  @override
  final String id = 'add';

  @override
  final String description = 'Add two numbers';

  late Arg<int> a;
  late Arg<int> b;

  @override
  void register(ArgParser parser) {
    a = parser.addPositional('a', parser: intValueParser);
    b = parser.addPositional('b', parser: intValueParser);
  }

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

class DispatchExampleHandler extends AppHandler
    implements WithCommands<String> {
  @override
  final usageInfo = UsageInfo(
      application: 'dispatch-example',
      prologue: 'This is another boring example.',
      epilogue: 'Copyright Foo Bar Productions Inc.');

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
    if (verbose.value >= 1) {
      print('V1: command: ${commands.selected}');
    }
  }
}

void main(List<String> args) => DispatchExampleHandler().runAppOrQuit(args);
