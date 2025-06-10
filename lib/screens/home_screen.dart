import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'lectio_screen.dart';
import 'support_screen.dart';
import 'slider_detail_screen.dart';
import 'news_list_screen.dart';
import 'settings_screen.dart';
import 'package:lectio_divina/widgets/app_floating_menu.dart';
import 'package:lectio_divina/shared/fab_menu_position.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notes_list_screen.dart';
import 'about_screen.dart';
import 'intentions_list_screen.dart';
import 'Intention_Submit_Screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FabMenuPosition fabMenuPosition = FabMenuPosition.right; // default

  final List<String> imagePaths = [
    'assets/images/slide1.jpg',
    'assets/images/slide2.jpg',
    'assets/images/slide3.jpg',
    'assets/images/slide4.jpg',
    'assets/images/slide5.jpg',
  ];

  // Lokalizované cez kľúče
  final List<String> slideTitleKeys = [
    'god_word',
    'lectio_divina',
    'meditatio',
    'oratio',
    'contemplatio',
  ];

  final List<String> slideSubtitleKeys = [
    'slider_subtitle_god_word',
    'slider_subtitle_lectio',
    'slider_subtitle_meditatio',
    'slider_subtitle_oratio',
    'slider_subtitle_contemplatio',
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  String? quoteText;
  String? quoteReference;
  String? nameDay;
  String? liturgicalDay;
  String? saints;
  bool isLoading = true;

  List<Map<String, dynamic>> contentCards = [];
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _startSliderTimer();
    _loadFabPosition();
    // fetchData(); // NEVOLAŤ tu!
    // fetchContentCards(); // NEVOLAŤ tu!
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      fetchData();
      fetchContentCards().then((data) {
        if (mounted) {
          setState(() {
            contentCards = data;
          });
        }
      });
      _dataLoaded = true;
    }
  }

  Future<void> _loadFabPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('fab_menu_position');
    if (index != null && index >= 0 && index < FabMenuPosition.values.length) {
      setState(() {
        fabMenuPosition = FabMenuPosition.values[index];
      });
    }
  }

  void _startSliderTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (!mounted) return;
      setState(() {
        if (_currentPage < imagePaths.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeIn,
          );
        }
      });
    });
  }

  Future<void> fetchData() async {
    final supabase = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final locale = context.locale.languageCode; // napr. 'sk', 'en'
      // Daily quotes
      final quoteRes = await supabase
          .from('daily_quotes')
          .select()
          .eq('date', today)
          .eq('lang', locale)
          .limit(1)
          .maybeSingle();

      // Calendar info (meniny, liturgický deň, svätí), tiež jazyková mutácia
      final calendarRes = await supabase
          .from('calendar_info')
          .select()
          .eq('date', today)
          .eq('lang', locale)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        quoteText = quoteRes?['quote'];
        quoteReference = quoteRes?['reference'];
        nameDay = calendarRes?['name_day'];
        liturgicalDay = calendarRes?['liturgical_day'];
        saints = calendarRes?['saints'];
        isLoading = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Chyba pri načítavaní dát zo Supabase: $e');
      debugPrint('📍 Stack trace: $stack');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchContentCards() async {
    final supabase = Supabase.instance.client;
    final now = DateTime.now().toIso8601String();

    final response = await supabase
        .from('content_cards')
        .select()
        .lte('visible_from', now)
        .gte('visible_to', now)
        .order('priority', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  FloatingActionButtonLocation getFabLocation([FabMenuPosition? pos]) {
    final position = pos ?? fabMenuPosition;
    switch (position) {
      case FabMenuPosition.left:
        return FloatingActionButtonLocation.startFloat;
      case FabMenuPosition.right:
        return FloatingActionButtonLocation.endFloat;
      case FabMenuPosition.center:
        return FloatingActionButtonLocation.centerFloat;
      case FabMenuPosition.topLeft:
        return FloatingActionButtonLocation.startTop;
      case FabMenuPosition.topRight:
        return FloatingActionButtonLocation.endTop;
      case FabMenuPosition.topCenter:
        return FloatingActionButtonLocation.centerTop;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateDayMonth =
        "${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}";
    final dateYear = "${today.year}";
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final calendarColor = isDark ? Colors.white : const Color(0xFF4A5085);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await fetchData();
          final data = await fetchContentCards();
          if (mounted) {
            setState(() {
              contentCards = data;
            });
          }
          await _loadFabPosition(); // refresh FAB position on pull-to-refresh
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // SLIDER ÚPLNE OD VRCHU (BEZ SafeArea)
              Container(
                height: 280,
                decoration: const BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: imagePaths.length,
                    onPageChanged: (index) {
                      if (!mounted) return;
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(imagePaths[index], fit: BoxFit.cover),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: Colors.black.withAlpha(128),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    slideTitleKeys[index].tr(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    slideSubtitleKeys[index].tr(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // ZVYŠOK OBSAHU v SafeArea
              SafeArea(
                top:
                    false, // <- dôležité, aby SafeArea nepridal padding hore (keďže slider je už hore)
                child: Column(
                  children: [
                    // Dots indicator
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(imagePaths.length, (index) {
                        final isActive = _currentPage == index;
                        return SizedBox(
                          height: 16,
                          width: 16,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 12 : 8,
                              height: isActive ? 12 : 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? Color(0xFF4A5085)
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    // Quote card
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      width: double.infinity,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  children: [
                                    Text(
                                      quoteText ?? tr('quote_not_available'),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 7),
                                    if (quoteReference != null)
                                      Text(
                                        quoteReference!,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    // Calendar card
                    const SizedBox(height: 8),

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      width: double.infinity,
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: isLoading
                              ? const SizedBox()
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Prvý stĺpec: Ikona
                                    Icon(
                                      Icons.calendar_month,
                                      size: 30,
                                      color: calendarColor,
                                    ),
                                    const SizedBox(width: 10),
                                    // Druhý stĺpec: Dátum v dvoch riadkoch
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          dateDayMonth,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: calendarColor,
                                          ),
                                        ),
                                        Text(
                                          dateYear,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: calendarColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 18),
                                    // Tretí stĺpec: Ostatný text, zaberá zvyšok miesta
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${tr('meniny')}: ${nameDay ?? '-'}",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            liturgicalDay ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            saints ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),

                    // Buttons
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      margin: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                      ),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: const [
                          _RoundedModuleButton(
                            labelKey: 'lectio_divina',
                            icon: Icons.menu_book,
                          ),
                          SizedBox(width: 12),
                          _RoundedModuleButton(
                            labelKey: 'reflections',
                            icon: Icons.lightbulb,
                          ),
                          SizedBox(width: 12),
                          _RoundedModuleButton(
                            labelKey: 'prayers',
                            icon: Icons.favorite,
                          ),
                          SizedBox(width: 12),
                          _RoundedModuleButton(
                            labelKey: 'bible',
                            icon: Icons.book,
                          ),
                          SizedBox(width: 12),
                          _RoundedModuleButton(
                            labelKey: 'news',
                            icon: Icons.campaign,
                          ),
                          SizedBox(width: 12),
                          _RoundedModuleButton(
                            labelKey: 'settings',
                            icon: Icons.settings,
                          ),
                        ],
                      ),
                    ),

                    // Support button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SupportScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          tr('support_full'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Content cards slider
                    if (contentCards.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SizedBox(
                          height: 130,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: contentCards.length,
                            itemBuilder: (context, index) {
                              final card = contentCards[index];
                              final imageUrl = card['image_url'] as String?;
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SliderDetailScreen(data: card),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 130,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x1A000000),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: imageUrl != null && imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.broken_image,
                                                    ),
                                                  ),
                                          loadingBuilder:
                                              (context, child, progress) {
                                                if (progress == null) {
                                                  return child;
                                                }
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              },
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.image,
                                            size: 48,
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: AppFloatingMenu(
        position: fabMenuPosition,
        onTap: (action) async {
          if (action == 'settings') {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(
                  currentPosition: fabMenuPosition,
                  onPositionChanged: (newPos) async {
                    setState(() {
                      fabMenuPosition = newPos;
                    });
                    // Save to SharedPreferences:
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('fab_menu_position', newPos.index);
                  },
                ),
              ),
            );
            // Reload FAB position after settings are changed:
            await _loadFabPosition();
          } else if (action == 'home') {
            Navigator.popUntil(context, (route) => route.isFirst);
          } else if (action == 'lectio') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LectioScreen()),
            );
          } else if (action == 'news') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewsListScreen()),
            );
          } else if (action == 'notes') {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotesListScreen()),
            );
          } else if (action == 'about') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            );
          } else if (action == 'pray_intentions') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IntentionsListScreen()),
            );
          } else if (action == 'pray_submit') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IntentionSubmitScreen()),
            );
          } else if (action == 'support') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SupportScreen()),
            );
          } else if (action == 'auth') {
            final session = Supabase.instance.client.auth.currentSession;
            if (session == null) {
              Navigator.of(context).pushNamed('/auth');
            } else {
              await Supabase.instance.client.auth.signOut();
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('module_not_available', args: [action])),
              ),
            );
          }
          // ďalšie akcie podľa potreby
        },
      ),
      floatingActionButtonLocation: getFabLocation(),
    );
  }
}

class _RoundedModuleButton extends StatelessWidget {
  final String labelKey;
  final IconData icon;

  const _RoundedModuleButton({required this.labelKey, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: ElevatedButton.icon(
        onPressed: () {
          if (labelKey == 'lectio_divina') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LectioScreen()),
            );
          } else if (labelKey == 'news') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewsListScreen()),
            );
          } else if (labelKey == 'about') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutScreen()),
            );
          } else if (labelKey == 'settings') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(
                  currentPosition:
                      (context
                          .findAncestorStateOfType<_HomeScreenState>()
                          ?.fabMenuPosition ??
                      FabMenuPosition.right),
                  onPositionChanged: (pos) async {
                    // Save to SharedPreferences if called from here
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('fab_menu_position', pos.index);
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr('module_not_available', args: [labelKey.tr()]),
                ),
              ),
            );
          }
        },
        icon: Icon(icon, size: 23),
        label: Text(labelKey.tr()),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF4A5085),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
