import 'package:plade/plade.dart';

enum Command { add, echo }

void checkAboveZero(int n) {
  if (n <= 0) {
    throw ValueParserException('Must be >0');
  }
}

void main(List<String> args) {
  var parser = AppArgParser(
      info: UsageInfo(
          application: 'plade-example',
          prologue: 'This example is boring.',
          epilogue: 'Copyright Foo Bar Productions Inc.'),
      config: ArgConfig.defaultConfig
          .copyWith(inverseGenerator: PrefixInverseGenerator()))
    ..addHelpOption();

  var loggingGroup = parser.createUsageGroup('Logging options');

  var verbose = parser.addMultiFlag('verbose',
      short: 'v',
      usageGroup: loggingGroup,
      description: 'Increase verbosity',
      defaultValue: 0,
      accumulator: flagCountAccumulator);

  var commands = parser.addCommands(
      parser: enumChoiceValueParser(Command.values), printer: enumValuePrinter);

  var add = commands.addCommand(Command.add, description: 'Add two numbers');
  var addA = add.addPositional('a', parser: intValueParser);
  var addB = add.addPositional('b', parser: intValueParser);

  var echo = commands.addCommand(Command.echo, description: 'Print a string');
  var echoStr = echo.addPositionalS('string', description: 'The string');
  var echoLines = echo.addOption('count',
      defaultValue: 1,
      parser: intValueParser.also(checkAboveZero),
      description: 'Number of times to print the line (default: 1)');

  parser.parseOrQuit(args);

  if (verbose.value >= 1) {
    print('V1: command: ${commands.selected}');
  }

  switch (commands.selected) {
    case Command.add:
      if (verbose.value >= 2) {
        print('V2: a: $addA');
        print('V2: a: $addB');
      }
      print(addA.value + addB.value);
      break;
    case Command.echo:
      Iterable.generate(echoLines.value, (_) => echoStr.value).forEach(print);
      break;
  }

  print(verbose.value);
}
