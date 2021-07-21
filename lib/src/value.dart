/// A function that takes in a string and parses it, returning some result value
/// of type [T]. If the value cannot be parsed, a [ValueParserException] should
/// be thrown.
typedef ValueParser<T> = T Function(String s);

/// A function that will stringify the given value, primarily for help messages
/// or for parsing.
typedef ValuePrinter<T> = String Function(T value);

/// A set of utilities for composing single-argument functions together.
extension FunctionComposition<A, R> on R Function(A) {
  /// Calls this function, then calls [func] with that value, and returns
  /// [func]'s result. Similar to function composition seen in various
  /// functional languages.
  ///
  /// ```dart
  /// var inc = (n) => n + 1;
  /// var double = (n) => n * 2;
  /// var incAndDouble = inc.then(double);
  /// print(incAndDouble(2));  // (2 + 1) * 2 => 6
  /// ```
  S Function(A value) then<S>(S Function(R value) func) => (s) => func(this(s));

  /// Calls this function, then calls [func] with the result. Unlike [then()],
  /// [func] is not expected to return a value.
  ///
  /// ```dart
  /// var inc = (n) => n + 1;
  /// var debug = (n) => print('The current value is: $n');
  /// var incAndDebug = inc.also(debug);
  ///
  /// var result = incAndDebug(2);  // Prints "The current value is: 3"
  /// print(result);  // 2 + 1 => 3
  /// ```
  R Function(A value) also(void Function(R value) func) => then((value) {
        func(value);
        return value;
      });
}

/// An exception thrown by a [ValueParser] when it cannot parse the provided
/// string.
class ValueParserException extends FormatException {
  final String reason;

  ValueParserException(this.reason);
}

/// A default [ValuePrinter] that simply calls [Object.toString()].
String toStringValuePrinter<T>(T value) => value.toString();

/// A variant of [toStringValuePrinter] designed for enum values. Since
/// `toString()` on an enum returns `Enum.value`, this printer strips off the
/// `Enum.` prefix.
String enumValuePrinter<T>(T value) =>
    toStringValuePrinter(value).split('.')[1];

/// A [ValueParser] that simply returns the original string.
String idValueParser(String s) => s;

int _parseInt(String s, {int? radix}) {
  var value = int.tryParse(s, radix: radix);
  if (value == null) {
    throw ValueParserException('Invalid int');
  }

  return value;
}

/// A [ValueParser] that attempts to parse the string as an `int`. If you need
/// a custom radix, use [intValueParserWithRadix].
int intValueParser(String s) => _parseInt(s);

/// A [ValueParser] like [intValueParser] but takes a custom [radix].
ValueParser<int> intValueParserWithRadix(int radix) =>
    (s) => _parseInt(s, radix: radix);

/// Returns a [ValueParser] that will stringify each choice using the given
/// [printer] (defaults to [toStringValuePrinter()]) and returns a value parser
/// that will map a choice's string to the choice value.
///
/// ```dart
/// var boolValueParser = stringChoiceValueParser([true, false]);
/// print(boolValueParser('true'));  // returns the boolean `true`
/// boolValueParser('thing');        // throws an exception
/// ```
ValueParser<T> stringChoiceValueParser<T>(List<T> choices,
    {ValuePrinter<T>? printer}) {
  printer ??= toStringValuePrinter;
  var choiceMap = {
    for (var choice in choices) printer(choice): choice,
  };

  return (s) {
    var choice = choiceMap[s];
    if (choice == null) {
      var formattedChoices = choiceMap.keys.join(', ');
      throw ValueParserException(
          'Value not in available choices: $formattedChoices');
    }

    return choice;
  };
}

/// A specialization of [stringChoiceValueParser] that uses [enumValuePrinter]
/// by default in order to parse enums.
///
/// If [interceptPrinter] is not `null`, then it will be called on the result of
/// [enumValuePrinter] to modify it.
///
/// ```dart
/// enum X { a, b, c }
///
/// var xParser = enumChoiceValueParser(X.values);
/// print(xParser('a'));  // X.a
/// xParser('foo');       // throws an exception
/// ```
ValueParser<T> enumChoiceValueParser<T>(List<T> values,
        {ValuePrinter<String>? interceptPrinter}) =>
    stringChoiceValueParser(values, printer: (value) {
      var result = enumValuePrinter(value);
      if (interceptPrinter != null) {
        result = interceptPrinter(result);
      }
      return result;
    });

/// A [ValueParser] that parses boolean values using [stringChoiceValueParser].
final boolValueParser = stringChoiceValueParser([true, false]);

/// Returns a [ValueParser] that constraints an already-parsed value to some
/// sequence of acceptable inputs. See [ValueParserExtensions.choice] for a
/// slightly more elegant alternative.
///
/// ```dart
/// var twoOrFourParser = choiceValueParser([2, 4], intValueParser);
/// print(twoOrFourParser('2'));  // 2
/// twoOrFourParser('3');         // throws an exception
/// ```
ValueParser<T> choiceValueParser<T>(
        List<T> choices, ValueParser<T> unconstrainedParser,
        {ValuePrinter<T>? printer}) =>
    unconstrainedParser.also((value) {
      if (!choices.contains(value)) {
        var formattedChoices =
            choices.map(printer ?? toStringValuePrinter).join(', ');
        throw ValueParserException(
            'Value not in available choices: $formattedChoices');
      }
    });

/// A [ValueParser] that wraps another `ValueParser<bool>` but flips the value.
/// See [ValueParserFlagExtensions.negateFlag] for a slightly more elegant
/// alternative.
///
/// ```dart
/// var negatedParser = negateFlagValueParser(boolValueParser);
/// print(negatedParser('true'));   // false
/// print(negatedParser('false'));  // true
/// ```
ValueParser<bool> negateFlagValueParser(ValueParser<bool> parser) =>
    parser.then((value) => !value);

extension ValueParserExtensions<T> on ValueParser<T> {
  /// An extension version of [choiceValueParser].
  ///
  /// ```dart
  /// // Equivalent:
  /// choiceValueParser([2, 4], intValueParser);
  /// intValueParser.choice([2, 4]);
  /// ```
  ValueParser<T> choice(List<T> choices, {ValuePrinter<T>? printer}) =>
      choiceValueParser(choices, this, printer: printer);
}

extension ValueParserFlagExtensions on ValueParser<bool> {
  /// An extension versin of [negateFlagValueParser].
  ///
  /// ```
  /// // Equivalent:
  /// negateFlagValueParser(boolValueParser);
  /// boolValueParser.negateFlag();
  /// ```
  ValueParser<bool> negateFlag() => negateFlagValueParser(this);
}

/// A function that takes a newly parsed argument value [value] and a
/// potentially existing accumulated value [previous] and returns a new
/// accumulated value. In other words, this is very similar to
/// [Iterable.reduce], but designed for Plade.
///
/// ```dart
/// // An accumulator that sums all the given arguments.
/// Accumulator<int, int> sumAccumulator =
///     (i, sum) => (sum ?? 0) + i;
/// // An accumulator that counts how many times an argument is given the same
/// // value.
/// Accumulator<String, Map<String, int>> freqAccumulator =
///     (arg, freqs) => (freqs ?? <String, int>{})
///         ..update(arg, (v) => v + 1, ifAbsent: () => 1);
/// ```
typedef Accumulator<T, U> = U Function({required T value, U? previous});

/// An [Accumulator] that adds all the values to a list.
List<T> listAccumulator<T>({required T value, List<T>? previous}) =>
    (previous ?? <T>[])..add(value);

/// An [Accumulator] that adds all the values to a set.
Set<T> setAccumulator<T>({required T value, Set<T>? previous}) =>
    (previous ?? <T>{})..add(value);

/// An [Accumulator] that discards all values but the last.
T discardAccumulator<T>({required T value, T? previous}) => value;

/// An [Accumulator] for flag arguments that counts the number of times the
/// argument was true, minus the number of times the argument was false. May
/// return a value less than 0 if more false values are given than true values.
int flagCountAccumulator({required bool value, int? previous}) =>
    (previous ?? 0) + (value ? 1 : -1);
