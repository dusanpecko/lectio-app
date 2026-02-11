// lib/screens/adoration_detail_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:just_audio/just_audio.dart';
import '../models/adoration_model.dart';
import '../services/adoration_service.dart';
import '../shared/app_colors.dart';
import '../widgets/audio/universal_audio_player.dart';
import '../widgets/audio/audio_player_models.dart';

class AdorationDetailScreen extends StatefulWidget {
  final String adorationId;
  final Adoration? initialAdoration;

  const AdorationDetailScreen({
    super.key,
    required this.adorationId,
    this.initialAdoration,
  });

  @override
  State<AdorationDetailScreen> createState() => _AdorationDetailScreenState();
}

class _AdorationDetailScreenState extends State<AdorationDetailScreen> {
  final AdorationService _adorationService = AdorationService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Adoration? _adoration;
  bool _isLoading = true;
  String? _error;
  Adoration? _nextAdoration;
  Adoration? _previousAdoration;

  @override
  void initState() {
    super.initState();
    if (widget.initialAdoration != null) {
      _adoration = widget.initialAdoration;
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAdoration();
  }

  Future<void> _loadAdoration() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lang = context.locale.languageCode;

      // Load adoration if not provided initially
      Adoration? adoration = _adoration;
      if (adoration == null) {
        adoration = await _adorationService.getAdoration(widget.adorationId);
        if (adoration == null) {
          throw Exception(tr('adoration_not_found'));
        }
      }

      // Load navigation (next/previous)
      final next = await _adorationService.getNextAdoration(
        adoration.order,
        lang,
      );
      final previous = await _adorationService.getPreviousAdoration(
        adoration.order,
        lang,
      );

      if (mounted) {
        setState(() {
          _adoration = adoration;
          _nextAdoration = next;
          _previousAdoration = previous;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToAdoration(String adorationId, Adoration adoration) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => AdorationDetailScreen(
          adorationId: adorationId,
          initialAdoration: adoration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return _buildLoadingScreen(theme);
    }

    if (_error != null || _adoration == null) {
      return _buildErrorScreen(theme);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.1),
              theme.scaffoldBackgroundColor,
              AppColors.accent.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(theme),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Audio Player
                  if (_adoration!.hasAudio)
                    UniversalAudioPlayer.rosary(
                      audioUrl: _adoration!.audioRecording,
                      title: _adoration!.title,
                      author: _adoration!.author ?? tr('unknown_author'),
                      albumName: tr('eucharistic_adoration'),
                      artworkUrl: _adoration!.hasImage
                          ? _adoration!.illustrationImage
                          : null,
                      id: 'adoration_${_adoration!.id}',
                      categoryColor: AppColors.primary,
                      audioPlayer: _audioPlayer,
                      config: AudioPlayerConfig.rosary.copyWith(
                        showTitle: false,
                        showAuthor: true,
                      ),
                    ),

                  // Content
                  Column(
                    children: [
                      _buildBiblicalText(theme),
                      _buildIntroduction(theme),
                      if (_adoration!.introductoryPrayers?.isNotEmpty == true)
                        _buildIntroductoryPrayers(theme),
                      _buildLectioDivinaSections(theme),
                      if (_adoration!.commentary?.isNotEmpty == true)
                        _buildComment(theme),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildNavigationButtons(theme),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.1),
              theme.scaffoldBackgroundColor,
              AppColors.accent.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 20),
                Text(
                  tr('loading_adoration'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('preparing_spiritual_journey'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(tr('adoration_not_found'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 20),
              Text(
                tr('adoration_not_found'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _error ?? tr('requested_adoration_not_found'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(tr('back_to_list')),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _loadAdoration,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(tr('try_again')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(ThemeData theme) {
    return SliverAppBar(
      expandedHeight: 300,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      title: Text(
        _adoration!.title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_adoration!.hasImage)
              CachedNetworkImage(
                imageUrl: _adoration!.illustrationImage!,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: AppColors.primary),
                errorWidget: (context, url, error) =>
                    Container(color: AppColors.primary),
              )
            else
              Container(color: AppColors.primary),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.5),
                    AppColors.primary.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _adoration!.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_adoration!.author?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        _adoration!.author!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiblicalText(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        elevation: 2,
        color: AppColors.primary.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _adoration!.biblicalText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroduction(ThemeData theme) {
    if (_adoration!.introduction.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 2,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('introduction'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Html(
                data: _adoration!.introduction,
                style: {
                  "body": Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  "p": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                    margin: Margins.only(top: 0, bottom: 4),
                  ),
                  "div": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                    margin: Margins.zero,
                  ),
                  "hr": Style(
                    margin: Margins.only(top: 8, bottom: 8),
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroductoryPrayers(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 2,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('introductory_prayers'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Html(
                data: _adoration!.introductoryPrayers!,
                style: {
                  "body": Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  "p": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                    margin: Margins.only(top: 0, bottom: 4),
                  ),
                  "div": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                    margin: Margins.zero,
                  ),
                  "hr": Style(
                    margin: Margins.only(top: 8, bottom: 8),
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLectioDivinaSections(ThemeData theme) {
    final sections = <String, String>{
      if (_adoration!.lectioText?.isNotEmpty == true)
        'lectio': _adoration!.lectioText!,
      if (_adoration!.meditatioText?.isNotEmpty == true)
        'meditatio': _adoration!.meditatioText!,
      if (_adoration!.oratioHtml?.isNotEmpty == true)
        'oratio': _adoration!.oratioHtml!,
      if (_adoration!.contemplatioText?.isNotEmpty == true)
        'contemplatio': _adoration!.contemplatioText!,
      if (_adoration!.actioText?.isNotEmpty == true)
        'actio': _adoration!.actioText!,
    };

    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      children: sections.entries.map((entry) {
        final sectionInfo = _getSectionInfo(entry.key);
        return _buildSection(theme, sectionInfo, entry.value);
      }).toList(),
    );
  }

  Map<String, dynamic> _getSectionInfo(String key) {
    final lectioDivinaSteps = {
      'lectio': {
        'name': 'Lectio',
        'subtitle': tr('reading'),
        'color': AppColors.primary,
      },
      'meditatio': {
        'name': 'Meditatio',
        'subtitle': tr('meditation'),
        'color': AppColors.primary,
      },
      'oratio': {
        'name': 'Oratio',
        'subtitle': tr('prayer'),
        'color': AppColors.primary,
      },
      'contemplatio': {
        'name': 'Contemplatio',
        'subtitle': tr('contemplation'),
        'color': AppColors.primary,
      },
      'actio': {
        'name': 'Actio',
        'subtitle': tr('action'),
        'color': AppColors.primary,
      },
    };

    return lectioDivinaSteps[key] ??
        {'name': key, 'subtitle': '', 'color': AppColors.primary};
  }

  Widget _buildSection(
    ThemeData theme,
    Map<String, dynamic> sectionInfo,
    String content,
  ) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 2,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionInfo['name'],
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: sectionInfo['color'],
                ),
              ),
              if (sectionInfo['subtitle'].isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  sectionInfo['subtitle'],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Html(
                data: content,
                style: {
                  "body": Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  "p": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                    margin: Margins.only(top: 0, bottom: 4),
                  ),
                  "div": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                    margin: Margins.zero,
                  ),
                  "hr": Style(
                    margin: Margins.only(top: 8, bottom: 8),
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComment(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 2,
        color: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('comment'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              Html(
                data: _adoration!.commentary!,
                style: {
                  "body": Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  "p": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                    margin: Margins.only(top: 0, bottom: 4),
                  ),
                  "div": Style(
                    lineHeight: const LineHeight(1.6),
                    color: theme.colorScheme.onSurface,
                    margin: Margins.zero,
                  ),
                  "hr": Style(
                    margin: Margins.only(top: 8, bottom: 8),
                    border: const Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    final hasPrevious = _previousAdoration != null;
    final hasNext = _nextAdoration != null;

    if (!hasPrevious && !hasNext) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          if (hasPrevious)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _navigateToAdoration(
                  _previousAdoration!.id,
                  _previousAdoration!,
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(
                  tr('previous'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),

          if (hasPrevious && hasNext) const SizedBox(width: 12),

          // Next Button
          if (hasNext)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () =>
                    _navigateToAdoration(_nextAdoration!.id, _nextAdoration!),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  tr('next'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
