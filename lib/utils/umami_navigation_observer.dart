import 'package:flutter/widgets.dart';
import 'package:lectio_divina/services/umami_analytics_service.dart';
import 'package:lectio_divina/utils/app_logger.dart';

class UmamiNavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreen(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _trackScreen(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackScreen(previousRoute);
    }
  }

  void _trackScreen(Route<dynamic> route) {
    final screenName = route.settings.name;

    if (screenName != null) {
      appLogger.d('📊 Umami Tracking Screen: $screenName');
      UmamiAnalyticsService().trackPageView(path: screenName);
    } else {
      appLogger.w(
        '⚠️ Umami Tracking: Route "${route.runtimeType}" has NO NAME. Add RouteSettings(name: "/...")',
      );
    }
  }
}
