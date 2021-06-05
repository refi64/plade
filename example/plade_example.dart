// This is a basic example of using Plade's core APIs. If you prefer a
// class-based approach, you'll want to check out dispatch_example.dart as well.

import 'package:plade/plade.dart';

enum Command { add, echo }

void checkAboveZero(int n) {
  if (n <= 0) {
    throw ValueParserException('Must be >0');
  }
}

void main(List<String> args) {
  var parser = AppArgParser(
      // Pass some usage information to be printed when requesting help.
      info: UsageInfo(
          application: 'plade-example',
          prologue: 'This example is boring.',
          epilogue: 'Copyright Foo Bar Productions Inc.'),
      // You can pass an ArgConfig to customize the details of argument parsing.
      // Here, we use the default config but change the inverseGenerator (which
      // generates inverses to boolean arguments, defaults to `null` meaning
      // "don't generate inverses").
      config: ArgConfig.defaultConfig
          .copyWith(inverseGenerator: PrefixInverseGenerator()))
    // Add the default help options.
    ..addHelpOption();

  // "Usage groups" can be used to group arguments under a certain heading in
  // the usage/help output.
  var loggingGroup = parser.createUsageGroup('Logging options');

  // Multi flags may be passed multiple times, with their values joined via the
  // given accumulator.
  var verbose = parser.addMultiFlag('verbose',
      short: 'v',
      usageGroup: loggingGroup,
      description: 'Increase verbosity',
      defaultValue: 0,
      // This accmulator is provided by Plade itself and counts the number of
      // times the flag is given.
      accumulator: flagCountAccumulator);

  // Creates a new set of commands.
  var commands = parser.addCommands(
      // The parser and printer let you specify custom parsing and printing
      // logic used for command names. Here, we want our command to be an enum,
      // so we use the Plade-provided enum parser and printer.
      parser: enumChoiceValueParser(Command.values),
      printer: enumValuePrinter);

  // Add our add command.
  var add = commands.addCommand(Command.add, description: 'Add two numbers');
  // These two arguments are ints and thus should be parsed via an int parser.
  var addA = add.addPositional('a', parser: intValueParser);
  var addB = add.addPositional('b', parser: intValueParser);

  var echo = commands.addCommand(Command.echo, description: 'Print a string');
  // addPositionalS is a shorthand for addPositional that hardcodes the type to
  // be a string.
  var echoStr = echo.addPositionalS('string', description: 'The string');
  var echoLines = echo.addOption('count',
      defaultValue: 1,
      // .also is a "combinator" of sorts that will run one function after
      // another. Here, after parsing the count as an int, we also check its
      // validity before declaring it has been successfully parsed.
      parser: intValueParser.also(checkAboveZero),
      description: 'Number of times to print the line (default: 1)');

  // After calling this, all the Arg instances returned above from the add*
  // methods will have their .value property filled.
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
