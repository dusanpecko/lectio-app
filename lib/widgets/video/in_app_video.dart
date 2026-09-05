import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../services/audio_exclusive.dart';
import '../../shared/app_spacing.dart';
import '../../utils/app_logger.dart';
import '../home_v2/home_v2_tokens.dart';

/// Rozpoznaný typ video zdroja.
enum VideoKind { youtube, vimeo, gdrive, file, unknown }

/// Origin, na ktorej „beží" stránka s embedom. YouTube podľa Refereru overuje,
/// či smie video prehrať — musí to byť skutočná https doména projektu.
const String kEmbedBaseUrl = 'https://lectio.one';

/// Zdroj videa rozpoznaný z URL — vie zostaviť embed URL a náhľad.
///
/// YouTube/Vimeo hráme cez ich OFICIÁLNY embed player (v súlade s ich
/// podmienkami; nesnažíme sa extrahovať priame stream URL, čo je zakázané a
/// v praxi sa to rozbíja). Používame privacy variantu domén (`youtube-nocookie`,
/// Vimeo `dnt=1`), aby sme divákovi nesadili zbytočný tracking.
class VideoSource {
  final VideoKind kind;
  final String url;
  final String? id;
  const VideoSource({required this.kind, required this.url, this.id});

  static final _youtube = RegExp(
    r'(?:youtu\.be/|youtube(?:-nocookie)?\.com/(?:watch\?(?:.*&)?v=|embed/|shorts/|live/|v/))([A-Za-z0-9_-]{11})',
    caseSensitive: false,
  );
  static final _vimeo = RegExp(
    r'vimeo\.com/(?:video/|channels/[^/]+/|groups/[^/]+/videos/)?(\d+)',
    caseSensitive: false,
  );
  // Google Drive — súbor zdieľaný odkazom („ktokoľvek s odkazom"). Podporené
  // sú obe bežné podoby: /file/d/{ID}/view aj ?id={ID}.
  static final _gdrive = RegExp(
    r'(?:drive|docs)\.google\.com/(?:file/d/|open\?id=|uc\?(?:.*&)?id=)([A-Za-z0-9_-]{10,})',
    caseSensitive: false,
  );
  static final _file = RegExp(r'\.(mp4|m4v|mov|webm|m3u8)(\?|$)', caseSensitive: false);

  factory VideoSource.parse(String raw) {
    final url = raw.trim();
    if (url.isEmpty) return VideoSource(kind: VideoKind.unknown, url: url);

    final yt = _youtube.firstMatch(url);
    if (yt != null) return VideoSource(kind: VideoKind.youtube, url: url, id: yt.group(1));

    final vm = _vimeo.firstMatch(url);
    if (vm != null) return VideoSource(kind: VideoKind.vimeo, url: url, id: vm.group(1));

    final gd = _gdrive.firstMatch(url);
    if (gd != null) return VideoSource(kind: VideoKind.gdrive, url: url, id: gd.group(1));

    if (_file.hasMatch(url)) return VideoSource(kind: VideoKind.file, url: url);
    return VideoSource(kind: VideoKind.unknown, url: url);
  }

  /// URL embed playera pre webview (null pre priame súbory / neznáme).
  String? get embedUrl {
    switch (kind) {
      case VideoKind.youtube:
        // playsinline=1 → hrá v ráme, nie v natívnom fullscreene;
        // rel=0 → na konci neponúka cudzie videá.
        return 'https://www.youtube-nocookie.com/embed/$id'
            '?playsinline=1&rel=0&modestbranding=1&autoplay=1';
      case VideoKind.vimeo:
        return 'https://player.vimeo.com/video/$id?autoplay=1&playsinline=1&dnt=1';
      case VideoKind.gdrive:
        // Drive preview player — bez reklám. Súbor musí byť zdieľaný odkazom.
        return 'https://drive.google.com/file/d/$id/preview';
      case VideoKind.file:
      case VideoKind.unknown:
        return null;
    }
  }

  /// Náhľadový obrázok, ak ho vieme odvodiť bez volania API.
  String? get thumbnailUrl {
    switch (kind) {
      case VideoKind.youtube:
        return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
      case VideoKind.gdrive:
        return 'https://drive.google.com/thumbnail?id=$id&sz=w640';
      case VideoKind.vimeo:
      case VideoKind.file:
      case VideoKind.unknown:
        return null;
    }
  }

  bool get isEmbed =>
      kind == VideoKind.youtube || kind == VideoKind.vimeo || kind == VideoKind.gdrive;

  /// Stránka s embedom v `<iframe>`. Embed URL sa NESMIE načítať priamo ako
  /// hlavný dokument — YouTube vtedy odmietne prehrávanie (chyba 153: chýbajúci
  /// / neplatný Referer). Preto ho vložíme do iframe na našej origin
  /// ([kEmbedBaseUrl]), presne ako to robí oficiálny YouTube IFrame player.
  String get iframeHtml => '''
<!DOCTYPE html>
<html><head>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
  iframe{position:absolute;inset:0;width:100%;height:100%;border:0}
</style>
</head><body>
<iframe src="$embedUrl"
        allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
        allowfullscreen></iframe>
</body></html>
''';
}

/// Video prehrávané PRIAMO V APLIKÁCII.
///
/// Najprv sa ukáže ľahký 16:9 náhľad (bez webview → nulová záťaž pri scrollovaní
/// zoznamu médií). Až po ťuknutí sa nahrá prehrávač:
///   · YouTube/Vimeo → oficiálny embed vo webview s inline prehrávaním
///   · priamy súbor (.mp4/.m3u8/…) → `video_player`
/// Externé otvorenie ostáva len ako záloha — napr. keď autor videa zakázal
/// embedovanie, alebo formát na danej platforme nie je podporovaný.
class InAppVideo extends StatefulWidget {
  const InAppVideo({
    super.key,
    required this.url,
    required this.accent,
    this.title,
  });

  final String url;
  final Color accent;
  final String? title;

  @override
  State<InAppVideo> createState() => _InAppVideoState();
}

class _InAppVideoState extends State<InAppVideo> {
  late final VideoSource _src = VideoSource.parse(widget.url);

  bool _started = false;
  bool _failed = false;

  WebViewController? _web;
  VideoPlayerController? _file;

  @override
  void dispose() {
    _file?.dispose();
    super.dispose();
  }

  /// Spustenie na ťuknutie — audio a video nesmú hrať naraz, tak zastavíme
  /// to, čo práve hrá (lectio bus, pobožnosti, …).
  Future<void> _start() async {
    HapticFeedback.lightImpact();
    await AudioExclusive.stopCurrent();
    if (!mounted) return;

    if (_src.isEmbed) {
      _initWeb();
    } else if (_src.kind == VideoKind.file) {
      await _initFile();
    } else {
      // Neznámy formát — nevieme ho spoľahlivo prehrať, ponúkneme externé otvorenie.
      setState(() {
        _started = true;
        _failed = true;
      });
      return;
    }
    if (mounted) setState(() => _started = true);
  }

  void _initWeb() {
    try {
      // Inline prehrávanie musíme zapnúť per platforma, inak iOS prepne video
      // do natívneho fullscreenu a Android čaká na ďalšie gesto.
      final params = WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              allowsInlineMediaPlayback: true,
              mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
            )
          : const PlatformWebViewControllerCreationParams();

      final c = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(NavigationDelegate(
          onWebResourceError: (e) {
            // Chyby podrámov (reklamy, tracking) prehrávanie nelámu — hlásime
            // len zlyhanie hlavného dokumentu.
            if (e.isForMainFrame ?? true) {
              appLogger.w('InAppVideo: embed zlyhal (${e.errorCode}) ${e.description}');
              if (mounted) setState(() => _failed = true);
            }
          },
        ));

      if (c.platform is AndroidWebViewController) {
        (c.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
      }
      // Nie loadRequest(embedUrl) — viď [VideoSource.iframeHtml] (YouTube 153).
      c.loadHtmlString(_src.iframeHtml, baseUrl: kEmbedBaseUrl);
      _web = c;
    } catch (e) {
      appLogger.e('InAppVideo: init webview zlyhal', error: e);
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _initFile() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(_src.url));
      await c.initialize();
      await c.play();
      _file = c;
      if (mounted) setState(() {});
    } catch (e) {
      appLogger.w('InAppVideo: priamy súbor sa nepodarilo prehrať: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(HomeV2.radiusSm),
        boxShadow: HomeV2.softShadowSm(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_started)
              _preview()
            else if (_failed)
              _errorState()
            else if (_src.isEmbed && _web != null)
              WebViewWidget(controller: _web!)
            else if (_file != null && _file!.value.isInitialized)
              _filePlayer()
            else
              const ColoredBox(
                color: Colors.black,
                child: Center(child: CircularProgressIndicator(color: Colors.white70)),
              ),

            // Záloha pre prípad, že autor zakázal embedovanie — vtedy YouTube
            // vypíše hlášku vnútri rámu a my to z Flutteru nedetegujeme.
            if (_started && !_failed)
              Positioned(
                right: 4,
                bottom: 4,
                child: _ghostButton(tr('video_open_external'), _openExternal),
              ),
          ],
        ),
      ),
    );
  }

  // ── Náhľad pred spustením ──────────────────────────────────────────────────
  Widget _preview() {
    final thumb = _src.thumbnailUrl;
    return Semantics(
      button: true,
      label: '${tr('video_play')}${widget.title != null ? ' — ${widget.title}' : ''}',
      child: GestureDetector(
        onTap: _start,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null)
              Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallbackBg())
            else
              _fallbackBg(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.transparent, Colors.black87],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 14)],
                ),
                child: Icon(Icons.play_arrow_rounded, color: widget.accent, size: 38),
              ),
            ),
            if (widget.title != null && widget.title!.trim().isNotEmpty)
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.sm,
                child: Text(
                  widget.title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Prehrávač priameho súboru ──────────────────────────────────────────────
  Widget _filePlayer() {
    final c = _file!;
    return GestureDetector(
      onTap: () => setState(() => c.value.isPlaying ? c.pause() : c.play()),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            Center(
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, color: widget.accent, size: 34),
              ),
            ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: widget.accent,
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Zlyhanie → jasná hláška + externé otvorenie ────────────────────────────
  Widget _errorState() {
    return ColoredBox(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 30),
              const SizedBox(height: AppSpacing.sm),
              Text(tr('video_load_failed'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: widget.accent),
                onPressed: _openExternal,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: Text(tr('video_open_external')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackBg() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [widget.accent.withValues(alpha: 0.85), widget.accent],
          ),
        ),
      );

  Widget _ghostButton(String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox(
            width: 34, height: 34,
            child: Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 17),
          ),
        ),
      ),
    );
  }
}
