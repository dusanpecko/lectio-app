import 'package:flutter/material.dart';

import '../shared/app_colors.dart';
import '../shared/app_spacing.dart';

/// Pomocné metódy pre bežné UI operácie
class UIHelpers {
  UIHelpers._();

  // ═══════════════════════════════════════════════════════════════════════════
  // SNACKBAR HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Zobrazí úspešný snackbar (zelený)
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle,
      duration: duration,
      action: action,
    );
  }

  /// Zobrazí chybový snackbar (červený)
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.red,
      icon: Icons.error,
      duration: duration,
      action: action,
    );
  }

  /// Zobrazí varovný snackbar (oranžový)
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: Colors.orange,
      icon: Icons.warning,
      duration: duration,
      action: action,
    );
  }

  /// Zobrazí informačný snackbar (primárna farba)
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: AppColors.primary,
      icon: Icons.info,
      duration: duration,
      action: action,
    );
  }

  /// Zobrazí základný snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    _showSnackBar(
      context,
      message,
      backgroundColor: backgroundColor,
      duration: duration,
      action: action,
    );
  }

  static void _showSnackBar(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        action: action,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.button,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOG HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Zobrazí potvrdzovací dialóg
  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Áno',
    String cancelText = 'Nie',
    Color? confirmColor,
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor:
                  isDangerous ? Colors.red : (confirmColor ?? AppColors.primary),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Zobrazí loading dialóg
  static void showLoadingDialog(
    BuildContext context, {
    String? message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.dialog),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              if (message != null) ...[
                const SizedBox(width: AppSpacing.lg),
                Flexible(child: Text(message)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Zatvorí loading dialóg
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM SHEET HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Zobrazí modal bottom sheet
  static Future<T?> showBottomSheet<T>(
    BuildContext context, {
    required Widget child,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.bottomSheet),
      builder: (context) => child,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KEYBOARD HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Zatvorí klávesnicu
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Naviguje na novú obrazovku
  static Future<T?> navigateTo<T>(BuildContext context, Widget screen) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  /// Naviguje na novú obrazovku a odstráni predošlé z histórie
  static Future<T?> navigateAndReplace<T>(BuildContext context, Widget screen) {
    return Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  /// Naviguje späť
  static void navigateBack<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop(result);
  }
}

/// Extension metódy pre BuildContext pre jednoduchšie použitie
extension UIHelpersExtension on BuildContext {
  /// Zobrazí úspešný snackbar
  void showSuccess(String message) => UIHelpers.showSuccess(this, message);

  /// Zobrazí chybový snackbar
  void showError(String message) => UIHelpers.showError(this, message);

  /// Zobrazí varovný snackbar
  void showWarning(String message) => UIHelpers.showWarning(this, message);

  /// Zobrazí informačný snackbar
  void showInfo(String message) => UIHelpers.showInfo(this, message);

  /// Zatvorí klávesnicu
  void hideKeyboard() => UIHelpers.hideKeyboard(this);
}

