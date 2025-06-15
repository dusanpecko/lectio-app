import 'package:lectio_divina/services/audio_handler.dart';
import 'package:audio_service/audio_service.dart';

final Future<LectioAudioHandler> audioHandlerFuture = AudioService.init(
  builder: () => LectioAudioHandler(),
  config: const AudioServiceConfig(
    androidNotificationChannelId: 'sk.dusanpecko.lectio_divina.channel.audio',
    androidNotificationChannelName: 'Prehrávanie audia',
    androidNotificationOngoing: true,
  ),
);
