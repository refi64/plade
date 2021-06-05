/// A set of APIs without any guaranteed stability at the moment, designed for
/// advanced usage.
library unstable;

export 'src/definition.dart' hide PrivateValueHolder, PrivateValueTarget;
export 'src/usage.dart' hide privateCreateUsageGroup;
