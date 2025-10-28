import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/speed_dial_fab.dart';
import 'about_screen.dart';
import 'intentions_list_screen.dart';
import 'intro_screen.dart';
import 'lectio_screen.dart';
import 'news_detail_screen.dart';
import 'news_list_screen.dart';
import 'notes_list_screen.dart';
import 'rosary_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Slider properties
  final List<String> imagePaths = [
    'assets/images/slide1.jpg',
    'assets/images/slide2.jpg',
    'assets/images/slide3.jpg',
    'assets/images/slide4.jpg',
    'assets/images/slide5.jpg',
  ];

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

  // Slider control
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // Quote data
  String? quoteText;
  String? quoteReference;
  bool isLoading = true;
  bool _dataLoaded = false;

  // News data
  List<Map<String, dynamic>> newsArticles = [];
  bool isLoadingNews = true;

  @override
  void initState() {
    super.initState();
    _startSliderTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _fetchQuoteData();
      _fetchNewsData();
      _dataLoaded = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // Start automatic slider
  void _startSliderTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
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

  // Fetch daily quote
  Future<void> _fetchQuoteData() async {
    final supabase = Supabase.instance.client;
    final today = DateTime.now().toIso8601String().substring(0, 10);

    try {
      final locale = context.locale.languageCode;
      final quoteRes = await supabase
          .from('daily_quotes')
          .select()
          .eq('date', today)
          .eq('lang', locale)
          .limit(1)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        quoteText = quoteRes?['quote'];
        quoteReference = quoteRes?['reference'];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch news data
  Future<void> _fetchNewsData() async {
    final supabase = Supabase.instance.client;

    try {
      final locale = context.locale.languageCode;
      final now = DateTime.now().toIso8601String();

      print('DEBUG: Home fetching news for lang=$locale, published_at <= $now');

      final newsRes = await supabase
          .from('news')
          .select()
          .eq('lang', locale)
          .lte('published_at', now)
          .order('published_at', ascending: false)
          .limit(5);

      print('DEBUG: Home Supabase response: $newsRes');

      if (!mounted) return;

      setState(() {
        newsArticles = List<Map<String, dynamic>>.from(newsRes);
        isLoadingNews = false;
      });

      print('DEBUG: Home news loaded: ${newsArticles.length} articles');
      if (newsArticles.isNotEmpty) {
        print('DEBUG: Home first article: ${newsArticles[0]['title']}');
      }
    } catch (e) {
      print('ERROR: Home loading news: $e');
      if (!mounted) return;
      setState(() {
        isLoadingNews = false;
      });
    }
  }

  // Handle refresh
  Future<void> _onRefresh() async {
    await Future.wait([_fetchQuoteData(), _fetchNewsData()]);
  }

  // Helper methods
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayName(DateTime date) {
    const dayNames = ['Po', 'Ut', 'St', 'Št', 'Pi', 'So', 'Ne'];
    return dayNames[date.weekday - 1];
  }

  // Show date picker for Lectio
  Future<void> _showDatePickerForLectio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: context.locale,
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: const Color(0xFF4A5085),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _openLectioForDate(picked);
    }
  }

  // Open Lectio for specific date
  void _openLectioForDate(DateTime date) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LectioScreen(selectedDate: date)),
    );
  }

  // Open today's Lectio - hlavná akcia FAB
  void _openTodaysLectio() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LectioScreen(selectedDate: DateTime.now()),
      ),
    );
  }

  // Handle Speed Dial secondary actions
  void _handleSpeedDialAction(String action) {
    if (!mounted) return;

    switch (action) {
      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;

      case 'notes':
        final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

        if (isLoggedIn) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotesListScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('login_required')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        break;

      case 'support':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SupportScreen()),
        );
        break;

      case 'about':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AboutScreen()),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action not handled: $action'),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 15), // Priestor pre FAB
          child: Column(
            children: [
              // Hero Slider Section
              _buildHeroSlider(),

              // Main Content
              SafeArea(
                top: false,
                child: Column(
                  children: [
                    // Slider dots
                    _buildSliderDots(),

                    // Lectio Divina Calendar
                    _buildLectioCalendar(),
                    const SizedBox(height: 8),
                    // Daily quote
                    _buildQuoteCard(),
                    const SizedBox(height: 8),
                    // Navigation buttons
                    _buildNavigationButtons(),
                    const SizedBox(height: 15),
                    // Rosary section
                    _buildRosarySection(),

                    // Support button
                    _buildSupportButton(),

                    // News section
                    _buildNewsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // SpeedDial FAB
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20), // Mierne vyššie
        child: SpeedDialFAB(
          onPrimaryAction: _openTodaysLectio,
          onSecondaryAction: _handleSpeedDialAction,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Build hero slider
  Widget _buildHeroSlider() {
    return Container(
      height: 350,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
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

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),

              // Text overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slideTitleKeys[index].tr(),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        slideSubtitleKeys[index].tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black54,
                            ),
                          ],
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
    );
  }

  // Build slider dots
  Widget _buildSliderDots() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(imagePaths.length, (index) {
          final isActive = _currentPage == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 12 : 8,
            height: isActive ? 12 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? const Color(0xFF4A5085) : Colors.grey.shade400,
            ),
          );
        }),
      ),
    );
  }

  // Build Lectio Divina Calendar
  Widget _buildLectioCalendar() {
    final today = DateTime.now();
    final startDate = today.subtract(const Duration(days: 3));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lectio divina',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF4A5085),
                ),
              ),
              GestureDetector(
                onTap: _showDatePickerForLectio,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A5085).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF4A5085),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Calendar slider
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: 10,
              itemBuilder: (context, index) {
                final date = startDate.add(Duration(days: index));
                final isToday = _isSameDay(date, today);

                return GestureDetector(
                  onTap: () => _openLectioForDate(date),
                  child: Container(
                    width: 70,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFF4A5085)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isToday
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF4A5085,
                                ).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getDayName(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday
                                ? Colors.white70
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Build quote card - kompaktná verzia
  Widget _buildQuoteCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Card(
        elevation: 0, // Vypnuté Card elevation, používame vlastný shadow
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4A5085).withValues(alpha: 0.03),
                const Color(0xFF4A5085).withValues(alpha: 0.01),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: isLoading
                ? const SizedBox(
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Color(0xFF4A5085),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      // Quote icon - menší
                      const Icon(
                        Icons.format_quote,
                        size: 20,
                        color: Color(0xFF4A5085),
                      ),
                      const SizedBox(width: 12),

                      // Quote content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quote text
                            Text(
                              quoteText ?? tr('quote_not_available'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF2D3748),
                                height: 1.4,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            if (quoteReference != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                quoteReference!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A5085),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Build navigation buttons
  Widget _buildNavigationButtons() {
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    return Container(
      height: 60,
      margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ModuleButton(labelKey: 'lectio_divina', icon: Icons.menu_book),
          const SizedBox(width: 12),
          _ModuleButton(labelKey: 'pray_intentions', icon: Icons.favorite),
          const SizedBox(width: 12),
          _ModuleButton(
            labelKey: 'rosary_title',
            icon: Icons.auto_stories_rounded,
          ),
          const SizedBox(width: 12),
          _ModuleButton(labelKey: 'news', icon: Icons.campaign),
          const SizedBox(width: 12),
          if (isLoggedIn) ...[
            _ModuleButton(labelKey: 'notes_title', icon: Icons.notes),
            const SizedBox(width: 12),
          ],
          _ModuleButton(labelKey: 'intro_title', icon: Icons.article),
          const SizedBox(width: 12),
          _ModuleButton(labelKey: 'about.title', icon: Icons.info),
          const SizedBox(width: 12),
          _ModuleButton(labelKey: 'settings', icon: Icons.settings),
        ],
      ),
    );
  }

  // Build support button
  Widget _buildSupportButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SupportScreen()),
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
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // Build Rosary section
  Widget _buildRosarySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 300,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RosaryScreen()),
          );
        },
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                // Background image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/rosary_bg.jpg',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback ak sa obrázok nenačíta
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF4A5085).withValues(alpha: 0.8),
                              const Color(0xFF4A5085),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Gradient overlay pre lepšiu čitateľnosť textu
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                // Bottom content with radius
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_stories_rounded,
                              size: 16,
                              color: Color(0xFF4A5085),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tr('rosary_title'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D3748),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tr('rosary_description'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718096),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build News section
  Widget _buildNewsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('news'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NewsListScreen(),
                    ),
                  );
                },
                child: Text(
                  tr('see_all'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A5085),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // News list
          isLoadingNews
              ? const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF4A5085)),
                  ),
                )
              : newsArticles.isEmpty
              ? Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Text(
                      tr('no_news_available'),
                      style: const TextStyle(
                        color: Color(0xFF718096),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : SizedBox(
                  height: 280,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: newsArticles.length,
                    itemBuilder: (context, index) {
                      final article = newsArticles[index];
                      return Container(
                        width: 300,
                        margin: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    NewsDetailScreen(newsData: article),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Large Image
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                      color: Colors.grey.shade200,
                                    ),
                                    child: Stack(
                                      children: [
                                        // Main image
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            topRight: Radius.circular(16),
                                          ),
                                          child: article['image_url'] != null
                                              ? Image.network(
                                                  article['image_url'],
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) {
                                                        return Container(
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
                                                          color: Colors
                                                              .grey
                                                              .shade200,
                                                          child: const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            color: Colors.grey,
                                                            size: 50,
                                                          ),
                                                        );
                                                      },
                                                )
                                              : Container(
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.article,
                                                    color: Colors.grey,
                                                    size: 50,
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Content section
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title
                                        Expanded(
                                          child: Text(
                                            article['title'] ??
                                                (tr('untitled_article')),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D3748),
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        // "Zobraziť článok" button
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF4A5085,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.arrow_forward,
                                                size: 16,
                                                color: Color(0xFF4A5085),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Zobraziť článok',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF4A5085),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

// Module Button Widget
class _ModuleButton extends StatelessWidget {
  const _ModuleButton({required this.labelKey, required this.icon});

  final String labelKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: ElevatedButton.icon(
        onPressed: () => _handlePress(context),
        icon: Icon(icon, size: 23),
        label: Text(labelKey.tr()),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A5085),
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

  void _handlePress(BuildContext context) {
    switch (labelKey) {
      case 'lectio_divina':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LectioScreen()),
        );
        break;

      case 'pray_intentions':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const IntentionsListScreen()),
        );
        break;

      case 'rosary_title':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RosaryScreen()),
        );
        break;

      case 'news':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NewsListScreen()),
        );
        break;

      case 'notes_title':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotesListScreen()),
        );
        break;

      case 'intro_title':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const IntroScreen()),
        );
        break;

      case 'about.title':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AboutScreen()),
        );
        break;

      case 'settings':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('module_not_available', args: [labelKey.tr()])),
          ),
        );
        break;
    }
  }
}
