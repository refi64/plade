class LongestCommonSubstring {
  /// The prefix of the substring in the first string.
  final String firstPrefix;

  /// The suffix of the substring in the first string.
  final String secondPrefix;

  /// The prefix of the substring in the second string.
  final String firstSuffix;

  /// The suffix of the substring in the second string.
  final String secondSuffix;

  final String substring;

  LongestCommonSubstring(
      {required this.firstPrefix,
      required this.secondPrefix,
      required this.firstSuffix,
      required this.secondSuffix,
      required this.substring});

  String _showChoice(String a, String b) {
    if (a.isEmpty && b.isEmpty) {
      return '';
    }

    var choice = a.isEmpty || b.isEmpty
        ? [a, b].firstWhere((s) => s.isNotEmpty)
        : [a, b].join(',');
    return '{$choice}';
  }

  @override
  String toString() {
    var prefix = _showChoice(firstPrefix, secondPrefix);
    var suffix = _showChoice(firstSuffix, secondSuffix);
    return '${prefix}${substring}${suffix}';
  }
}

// https://en.wikipedia.org/wiki/Longest_common_substring_problem
LongestCommonSubstring longestCommonSubstring(String s, String t) {
  var l = List.generate(s.length, (_) => List.generate(t.length, (_) => 0));
  var z = 0;

  var sr = s.runes.toList();
  var tr = t.runes.toList();

  var iRet = 0, jRet = 0;

  for (var i = 0; i < sr.length; i++) {
    for (var j = 0; j < tr.length; j++) {
      if (sr[i] == tr[j]) {
        l[i][j] = i == 0 || j == 0 ? 1 : l[i - 1][j - 1] + 1;
        if (l[i][j] > z) {
          z = l[i][j];
          iRet = i;
          jRet = j;
        }
      } else {
        l[i][j] = 0;
      }
    }
  }

  var sBegin = iRet - z + 1;
  var tBegin = jRet - z + 1;
  var sEnd = iRet + 1;
  var tEnd = jRet + 1;

  return LongestCommonSubstring(
      firstPrefix: String.fromCharCodes(sr.sublist(0, sBegin)),
      secondPrefix: String.fromCharCodes(tr.sublist(0, tBegin)),
      firstSuffix: String.fromCharCodes(sr.sublist(sEnd)),
      secondSuffix: String.fromCharCodes(tr.sublist(tEnd)),
      substring: String.fromCharCodes(sr.sublist(sBegin, sEnd)));
}
