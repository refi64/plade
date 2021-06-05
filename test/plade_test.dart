import 'package:plade/plade.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  late AppArgParser parser;

  setUp(() {
    parser = AppArgParser();
  });

  group('Positional arguments', () {
    test('are parsed', () {
      var a = parser.addPositionalS('a');
      var b = parser.addPositionalS('b');
      parser.parse(['arg1', 'arg2']);

      expect(a.value, equals('arg1'));
      expect(b.value, equals('arg2'));
    });

    test('cannot be in excess', () {
      parser.addPositionalS('a');
      parser.addPositionalS('b');

      expect(() => parser.parse(['arg1', 'arg2', 'arg3']),
          throwsArgError(ArgParsingErrorKind.tooManyPositionals));
    });

    test('can be made optional', () {
      var a = parser.addPositionalS('a');
      var b = parser.addPositionalS('b', requires: Requires.optional('def'));

      parser.parse(['arg1']);

      expect(a.value, equals('arg1'));
      expect(b.value, equals('def'));
    });

    test('must be given if mandatory', () {
      parser.addPositionalS('a');
      parser.addPositionalS('b');

      expect(() => parser.parse([]),
          throwsArgError(ArgParsingErrorKind.missingPositionals));
      expect(() => parser.parse(['arg1']),
          throwsArgError(ArgParsingErrorKind.missingPositionals));
    });

    test('can stop parsing of subsequent options', () {
      var a = parser.addPositionalS('a', noOptionsFollowing: true);
      var b = parser.addPositionalS('b');

      parser.parse(['x', '-y']);

      expect(a.value, equals('x'));
      expect(b.value, equals('-y'));
    });

    group('that can take multiple values', () {
      test('are parsed', () {
        var a = parser.addMultiPositionalS('a', accumulator: listAccumulator);

        parser.parse(['x', 'y']);

        expect(a.value, equals(['x', 'y']));
      });

      test('can be made optional', () {
        var a = parser.addMultiPositionalS('a',
            accumulator: listAccumulator,
            requires: Requires.optional(<String>[]));

        parser.parse([]);

        expect(a.value, equals(<String>[]));
      });

      test('must be given if mandatory', () {
        parser.addMultiPositionalS('b', accumulator: listAccumulator);

        expect(() => parser.parse([]),
            throwsArgError(ArgParsingErrorKind.missingPositionals));
      });
    });
  });

  group('Regular options', () {
    test('are parsed', () {
      var a = parser.addOptionSN('a');
      var b = parser.addOptionSN('b');

      parser.parse(['--a=x', '--b=y']);

      expect(a.value, equals('x'));
      expect(b.value, equals('y'));
    });

    test('are optional', () {
      var a = parser.addOptionSN('a');
      var b = parser.addOptionSN('b');

      parser.parse(['--a=x']);

      expect(a.value, equals('x'));
      expect(b.wasGiven, isFalse);
      expect(b.value, isNull);
    });

    test('can have values passed separately', () {
      var a = parser.addOptionSN('a');

      parser.parse(['--a', 'x']);

      expect(a.value, equals('x'));
    });

    test('must have a value passed', () {
      parser.addOptionSN('a');

      expect(() => parser.parse(['--a']),
          throwsArgError(ArgParsingErrorKind.missingOptionValue));
    });

    test('stop being parsed after --', () {
      var a = parser.addPositionalS('a');
      var b = parser.addOptionSN('b');
      var c = parser.addPositionalSN('c');

      parser.parse(['x', '--', '-b']);

      expect(a.value, equals('x'));
      expect(b.wasGiven, isFalse);
      expect(c.value, equals('-b'));
    });

    group('that can take multiple values', () {
      test('are parsed', () {
        var a = parser.addMultiOptionSN('a', accumulator: listAccumulator);

        parser.parse(['--a=x', '--a', 'y', '--a=z']);

        expect(a.value, equals(['x', 'y', 'z']));
      });

      test('are optional', () {
        var a = parser.addMultiOptionSN('aa', accumulator: listAccumulator);

        parser.parse([]);

        expect(a.value, isNull);
      });
    });
  });

  group('Flag options', () {
    test('are parsed', () {
      var a = parser.addFlag('a');
      var b = parser.addFlag('b');

      parser.parse(['--a', '--b']);

      expect(a.value, isTrue);
      expect(b.value, isTrue);
    });

    test('are optional', () {
      var a = parser.addFlag('a');
      var b = parser.addFlag('b');

      parser.parse(['--a']);

      expect(a.value, isTrue);
      expect(a.wasGiven, isTrue);
      expect(b.value, isFalse);
      expect(b.wasGiven, isFalse);
    });

    test('cannot be unknown', () {
      expect(() => parser.parse(['--a']),
          throwsArgError(ArgParsingErrorKind.unknownOption));
    });

    test('can have boolean values explicitly given', () {
      var a = parser.addFlag('a');

      parser.parse(['--a=false']);

      expect(a.wasGiven, isTrue);
      expect(a.value, isFalse);
    });

    test('cannot have a value given separately', () {
      var a = parser.addFlag('a');
      var b = parser.addPositionalSN('b');

      parser.parse(['--a', 'false']);

      expect(a.value, isTrue);
      expect(b.wasGiven, isTrue);
      expect(b.value, equals('false'));
    });

    test('can have an inverse set', () {
      var a = parser.addFlag('a', inverse: 'invert-a');

      parser.parse(['--invert-a']);

      expect(a.value, isFalse);
      expect(a.wasGiven, isTrue);
    });

    group('with a prefixed inverse', () {
      setUp(() {
        parser = AppArgParser(
            config: ArgConfig.defaultConfig
                .copyWith(inverseGenerator: PrefixInverseGenerator()));
      });

      test('add the proper inverses for options', () {
        var a = parser.addFlag('with-a');
        var b = parser.addFlag('enable-b');
        var c = parser.addFlag('c');

        parser.parse(['--without-a', '--disable-b', '--no-c']);

        expect(a.value, isFalse);
        expect(a.wasGiven, isTrue);

        expect(b.value, isFalse);
        expect(b.wasGiven, isTrue);

        expect(c.value, isFalse);
        expect(c.wasGiven, isTrue);
      });

      test('can opt out of inverse generation', () {
        parser.addFlag('a', inverse: disableFlagInverse);

        expect(() => parser.parse(['--no-a']),
            throwsArgError(ArgParsingErrorKind.unknownOption));
      });
    });
  });

  group('Short options and flags', () {
    test('are parsed', () {
      var a = parser.addOptionSN('aa', short: 'a');
      var b = parser.addFlag('bb', short: 'b');

      parser.parse(['-a=a', '-b']);

      expect(a.value, equals('a'));
      expect(b.wasGiven, isTrue);
    });

    test('can have a required value specified w/ an optional equals', () {
      var a = parser.addOptionSN('aa', short: 'a');
      var b = parser.addOptionSN('bb', short: 'b');

      parser.parse(['-ab', '-b=a']);

      expect(a.value, equals('b'));
      expect(b.value, equals('a'));
    });

    test('must have a value passed', () {
      parser.addOptionSN('aa', short: 'a');

      expect(() => parser.parse(['-a']),
          throwsArgError(ArgParsingErrorKind.missingOptionValue));
    });

    test('can be combined', () {
      var a = parser.addOptionSN('aa', short: 'a');
      var b = parser.addFlag('bb', short: 'b');
      var c = parser.addOptionSN('cc', short: 'c');
      var d = parser.addFlag('dd', short: 'd');
      var e = parser.addFlag('ee', short: 'e');
      var f = parser.addFlag('ff', short: 'f');

      parser.parse(['-bax', '-ec', 'y', '-df']);

      expect(a.value, equals('x'));
      expect(b.value, isTrue);
      expect(c.value, equals('y'));
      expect(d.value, isTrue);
      expect(e.value, isTrue);
      expect(f.value, isTrue);
    });

    test('can be disabled', () {
      parser = AppArgParser(config: ArgConfig.go);
      var ab = parser.addFlag('ab');

      parser.parse(['-ab']);

      expect(ab.value, isTrue);
    });
  });

  group('Custom value types', () {
    test('can be parsed', () {
      var a = parser.addPositionalN('a', parser: intValueParser);

      parser.parse(['1']);

      expect(a.value, equals(1));
    });

    test('check for errors', () {
      parser.addPositionalN('a', parser: intValueParser);

      expect(() => parser.parse(['x']),
          throwsArgError(ArgParsingErrorKind.parsingValue));
    });
  });

  group('Commands', () {
    test('can be parsed', () {
      var commands = parser.addCommandsS();
      commands.addCommand('a');
      commands.addCommand('b');

      parser.parse(['a']);

      expect(commands.selected, equals('a'));
    });

    test('must be given', () {
      var commands = parser.addCommandsS();
      commands.addCommand('a');

      expect(() => parser.parse([]),
          throwsArgError(ArgParsingErrorKind.missingCommand));
    });

    test('inherit the initial arguments', () {
      var a = parser.addMultiPositionalS('a', accumulator: listAccumulator);
      var b = parser.addMultiOptionSN('b', accumulator: listAccumulator);

      var commands = parser.addCommandsS();
      commands.addCommand('a');
      commands.addCommand('b');

      parser.parse(['--b=1', 'a', '--b=2', 'x']);

      expect(commands.selected, equals('a'));
      expect(a.value, equals(['x']));
      expect(b.value, equals(['1', '2']));
    });

    test('can have their own arguments', () {
      var commands = parser.addCommandsS();
      var a = commands.addCommand('a');
      var b = commands.addCommand('b');

      var ac = a.addFlag('c');
      var bc = b.addFlag('c');

      parser.parse(['b', '--c']);

      expect(commands.selected, equals('b'));
      expect(ac.value, isFalse);
      expect(bc.value, isTrue);
    });

    test('cannot be unknown', () {
      var commands = parser.addCommandsS();
      commands.addCommand('a');
      commands.addCommand('b');

      expect(() => parser.parse(['c']),
          throwsArgError(ArgParsingErrorKind.unknownCommand));
    });
  });
}
