import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Globálny logger pre aplikáciu.
/// V release móde loguje len warning a vyššie.
/// V debug móde loguje všetko.
final Logger appLogger = Logger(
  filter: _AppLogFilter(),
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.none,
  ),
);

/// Filter pre Logger - v release móde potlačí debug a info logy.
class _AppLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kReleaseMode) {
      // V produkcii logujeme len warning, error, fatal
      return event.level.index >= Level.warning.index;
    }
    // V debug móde logujeme všetko
    return true;
  }
}
