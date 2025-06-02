import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lectio_screen.dart';
import 'support_screen.dart';
import 'slider_detail_screen.dart';
import 'news_list_screen.dart';
import 'settings_screen.dart';
import 'package:lectio_divina/widgets/app_floating_menu.dart';
import 'package:lectio_divina/shared/fab_menu_position.dart';

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

  final List<String> slideTitles = [
    'Božie slovo',
    'LECTIO',
    'MEDITATIO',
    'ORATIO',
    'KONTEMPLATIO',
  ];

  final List<String> slideSubtitles = [
    'formou Lectio divina',
    'Čítanie vybraného textu ...',
    'Pozvanie zamyslieť sa nad Slovom ...',
    'Modlitba podľa Božieho slova ...',
    'Vnútorný pohľad srdca na Ježiša ...',
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

  @override
  void initState() {
    super.initState();
    _startSliderTimer();
    fetchData();
    fetchContentCards().then((data) {
      if (mounted) {
        setState(() {
          contentCards = data;
        });
      }
    });
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
      final quoteRes = await supabase
          .from('daily_quotes')
          .select()
          .eq('date', today)
          .limit(1)
          .maybeSingle();

      final calendarRes = await supabase
          .from('calendar_info')
          .select()
          .eq('date', today)
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
    final formattedDate =
        "${today.day.toString().padLeft(2, '0')}.${today.month.toString().padLeft(2, '0')}.${today.year}";

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await fetchData();
            final data = await fetchContentCards();
            if (mounted) {
              setState(() {
                contentCards = data;
              });
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // Slider
                Container(
                  height: 250,
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
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
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
                                      slideTitles[index],
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      slideSubtitles[index],
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
                                ? Colors.deepPurple
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
                                  quoteText ?? 'Citát nie je dostupný.',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                if (quoteReference != null)
                                  Text(
                                    quoteReference!,
                                    style: const TextStyle(fontSize: 14),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  size: 40,
                                  color: Colors.deepPurple,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "Meniny má: ${nameDay ?? '-'}",
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
                  margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: const [
                      _RoundedModuleButton(
                        label: 'Lectio divina',
                        icon: Icons.menu_book,
                      ),
                      SizedBox(width: 12),
                      _RoundedModuleButton(
                        label: 'Zamyslenia',
                        icon: Icons.lightbulb,
                      ),
                      SizedBox(width: 12),
                      _RoundedModuleButton(
                        label: 'Modlitby',
                        icon: Icons.favorite,
                      ),
                      SizedBox(width: 12),
                      _RoundedModuleButton(label: 'Biblia', icon: Icons.book),
                      SizedBox(width: 12),
                      _RoundedModuleButton(
                        label: 'Aktuality',
                        icon: Icons.campaign,
                      ),
                      SizedBox(width: 12),
                      _RoundedModuleButton(
                        label: 'Nastavenia',
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
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      '❤️ Podporte fungovanie Lectio divina',
                      style: TextStyle(
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
                                            if (progress == null) return child;
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          },
                                    )
                                  : Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.image, size: 48),
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
                  onPositionChanged: (newPos) {
                    setState(() {
                      fabMenuPosition = newPos;
                    });
                  },
                ),
              ),
            );
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
            // ďalšie akcie podľa potreby
          }
          // Odhlásenie rieši AppFloatingMenu a SessionHandler automaticky
        },
      ),
      floatingActionButtonLocation: getFabLocation(),
    );
  }
}

class _RoundedModuleButton extends StatelessWidget {
  final String label;
  final IconData icon;

  const _RoundedModuleButton({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: ElevatedButton.icon(
        onPressed: () {
          if (label == 'Lectio divina') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LectioScreen()),
            );
          } else if (label == 'Aktuality') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NewsListScreen()),
            );
          } else if (label == 'Nastavenia') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(
                  currentPosition:
                      (context
                          .findAncestorStateOfType<_HomeScreenState>()
                          ?.fabMenuPosition ??
                      FabMenuPosition.right),
                  onPositionChanged: (pos) {
                    // nič, nastavuje sa v HomeScreen
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Modul "$label" zatiaľ nie je dostupný.')),
            );
          }
        },
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
