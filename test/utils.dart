import 'package:plade/plade.dart';
import 'package:test/test.dart';

class _ArgErrorTest extends Matcher {
  final ArgParsingErrorKind kind;

  _ArgErrorTest(this.kind);

  @override
  bool matches(dynamic item, Map matchState) {
    try {
      item();
    } on ArgParsingError catch (ex) {
      matchState['error'] = ex;
      matchState['errorKind'] = ex.kind;
      return ex.kind == kind;
    }

    return false;
  }

  @override
  Description describe(Description description) =>
      description.add(kind.toString());

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription,
          Map matchState, bool verbose) =>
      mismatchDescription.add(matchState['error'] != null
          ? 'threw: [${matchState['errorKind']}] ${matchState['error']}'
          : 'succeeded');
}

_ArgErrorTest throwsArgError(ArgParsingErrorKind expectedKind) =>
    _ArgErrorTest(expectedKind);
