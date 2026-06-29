import 'lectio_data_service.dart';

/// Načíta dnešné „actio" (text + súradnice dňa) z `lectio_sources`.
///
/// Deleguje na zdieľanú reťazenú logiku [LectioDataService.getDailyQuote]
/// (fallback jazyk používateľa → EN → SK), aby logika nebola duplikovaná.
class ActioService {
  ActioService._();
  static final ActioService instance = ActioService._();

  Future<DailyQuote?> fetchTodaysActio(String locale) async {
    return LectioDataService.instance.getDailyQuote(locale: locale);
  }
}
