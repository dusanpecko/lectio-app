import 'package:flutter/widgets.dart';

/// Zdieľaný route observer — obrazovky cez `RouteAware` vedia reagovať na
/// návrat z inej obrazovky (napr. obnoviť nastavenia po návrate z Nastavení).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
