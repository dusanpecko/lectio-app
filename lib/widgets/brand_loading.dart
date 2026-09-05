import 'package:flutter/material.dart';

import 'home_v2/home_v2_tokens.dart';

/// Brandovaný loading — jemné pulzovanie loga lectio.one na pozadí obrazovky
/// (splash štýl). Nahrádza `CircularProgressIndicator` pri načítavaní obsahu.
class BrandLoading extends StatefulWidget {
  const BrandLoading({super.key, this.size = 88});

  /// Veľkosť loga (šírka = výška).
  final double size;

  @override
  State<BrandLoading> createState() => _BrandLoadingState();
}

class _BrandLoadingState extends State<BrandLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
    return Center(
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(curved),
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.06).animate(curved),
          child: Image.asset(
            'assets/icon/lectio_logo.png',
            width: widget.size,
            height: widget.size,
            errorBuilder: (_, _, _) =>
                CircularProgressIndicator(color: HomeV2.primary),
          ),
        ),
      ),
    );
  }
}
