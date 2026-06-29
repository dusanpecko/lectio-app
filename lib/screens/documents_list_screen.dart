import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pdf_document.dart';
import '../services/documents_service.dart';
import '../shared/app_spacing.dart';
import '../widgets/home_v2/home_v2_tokens.dart';
import 'document_detail_screen.dart';

class DocumentsListScreen extends StatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  State<DocumentsListScreen> createState() => _DocumentsListScreenState();
}

enum _Status { loading, ready, noAccess, error }

class _DocumentsListScreenState extends State<DocumentsListScreen> {
  _Status _status = _Status.loading;
  List<PdfDocument> _documents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final docs = await DocumentsService.instance.fetchDocuments();
      if (!mounted) return;
      setState(() {
        _documents = docs;
        _status = _Status.ready;
      });
    } on DocumentsAccessException {
      if (!mounted) return;
      setState(() => _status = _Status.noAccess);
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _Status.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            HomeV2.isDark(context) ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            HomeV2.isDark(context) ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: HomeV2.background(context),
        body: Column(
          children: [
            _buildHero(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.loading:
        return const Center(child: CircularProgressIndicator());
      case _Status.noAccess:
        return _buildAccessDenied();
      case _Status.error:
        return _buildError();
      case _Status.ready:
        if (_documents.isEmpty) {
          return _buildMessage(
            Icons.folder_off_outlined,
            'documents.empty'.tr(),
          );
        }
        return RefreshIndicator(
          onRefresh: _load,
          color: HomeV2.primary,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              MediaQuery.of(context).viewPadding.bottom + AppSpacing.xxl,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.xl,
              crossAxisSpacing: AppSpacing.lg,
              childAspectRatio: 0.56,
            ),
            itemCount: _documents.length,
            itemBuilder: (_, i) => _buildDocGridItem(_documents[i]),
          ),
        );
    }
  }

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _buildHero() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            HomeV2.primary.withValues(alpha: HomeV2.isDark(context) ? 0.32 : 0.14),
            HomeV2.background(context),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CircleButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'documents.title'.tr(),
            style: HomeV2.serifTitle(context, size: 30, height: 1.1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'documents.subtitle'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: HomeV2.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mriežková položka (obálka knihy) ────────────────────────────────────────
  Widget _buildDocGridItem(PdfDocument doc) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentDetailScreen(document: doc),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HomeV2.radiusSm),
                boxShadow: HomeV2.softShadow(context),
              ),
              clipBehavior: Clip.antiAlias,
              child: _cover(doc),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            doc.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: HomeV2.textDark(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            '${doc.langBadge} · ${doc.totalChapters} ${'documents.chapters_abbr'.tr()}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: HomeV2.gold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover(PdfDocument doc) {
    Widget fallback() => ColoredBox(
          color: HomeV2.primary.withValues(alpha: 0.10),
          child: Center(
            child: Icon(
              Icons.menu_book_rounded,
              color: HomeV2.iconAccent(context).withValues(alpha: 0.6),
              size: 40,
            ),
          ),
        );
    final hasCover = doc.coverImageUrl != null && doc.coverImageUrl!.isNotEmpty;
    return hasCover
        ? CachedNetworkImage(
            imageUrl: doc.coverImageUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) => fallback(),
            errorWidget: (_, _, _) => fallback(),
          )
        : fallback();
  }

  // ── Stavy ─────────────────────────────────────────────────────────────────
  Widget _buildAccessDenied() {
    return _buildMessage(
      Icons.lock_outline_rounded,
      'documents.access_denied_msg'.tr(),
      title: 'documents.access_denied_title'.tr(),
    );
  }

  Widget _buildError() {
    return _buildMessage(
      Icons.cloud_off_rounded,
      'documents.error'.tr(),
      action: TextButton.icon(
        onPressed: _load,
        icon: Icon(Icons.refresh_rounded, color: HomeV2.primary),
        label: Text(
          'retry'.tr(),
          style: TextStyle(color: HomeV2.primary, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildMessage(
    IconData icon,
    String message, {
    String? title,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: HomeV2.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: HomeV2.iconAccent(context)),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (title != null) ...[
              Text(
                title,
                style: HomeV2.serifTitle(context, size: 22),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: HomeV2.textMuted(context),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeV2.card(context).withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: HomeV2.primary, size: 22),
        ),
      ),
    );
  }
}
