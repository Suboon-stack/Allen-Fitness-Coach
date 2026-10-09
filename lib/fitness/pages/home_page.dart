import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/pages/chat_page.dart';
import 'package:allen/fitness/pages/meal_planner_page.dart';
import 'package:allen/fitness/pages/profile_page.dart';
import 'package:allen/fitness/pages/progress_page.dart';
import 'package:allen/fitness/pages/settings_page.dart';
import 'package:allen/fitness/pages/workout_page.dart';
import 'package:allen/fitness/pages/about_page.dart';
import 'package:allen/pallete.dart';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/fitness/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:allen/fitness/pages/calorie_scanner_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AiService _aiService = AiService();
  final StorageService _storage = StorageService();

  String _quote = 'Loading your daily motivation...';
  int _workoutCount = 0;
  int _streak = 0;
  double? _currentWeight;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final quote = await _aiService.getDailyQuote();
      final workoutCount = await _storage.getWorkoutCount();
      final streak = await _storage.getStreak();
      final weight = await _storage.getLatestWeight();

      if (!mounted) return;
      setState(() {
        _quote = quote;
        _workoutCount = workoutCount;
        _streak = streak;
        _currentWeight = weight;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quote =
            '"The only bad workout is the one that didn\'t happen." - Unknown';
        _loading = false;
      });
    }
  }

  void _navigate(Widget page) {
    Navigator.pop(context);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthCubit>().currentUser;

    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      drawer: _buildDrawer(user?.email ?? 'Allen User'),
      appBar: AppBar(
        backgroundColor: Pallete.surfaceColor,
        title: const Text(
          'Allen Fitness',
          style: TextStyle(
            color: Pallete.mainFontColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Pallete.borderColor),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Pallete.primaryAccent,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Pallete.primaryAccent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        color: Pallete.subFontColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ready to crush it today?',
                      style: TextStyle(
                        color: Pallete.mainFontColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quote card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Pallete.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Pallete.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.format_quote_rounded,
                                color: Pallete.primaryAccent,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Daily Motivation',
                                style: TextStyle(
                                  color: Pallete.primaryAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _quote,
                            style: const TextStyle(
                              color: Pallete.mainFontColor,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stats row
                    Row(
                      children: [
                        _statCard(
                          '$_workoutCount',
                          'Workouts',
                          Icons.fitness_center_rounded,
                        ),
                        const SizedBox(width: 10),
                        _statCard(
                          _currentWeight != null
                              ? '${_currentWeight!.toStringAsFixed(1)}kg'
                              : '--',
                          'Weight',
                          Icons.monitor_weight_outlined,
                        ),
                        const SizedBox(width: 10),
                        _statCard(
                          '$_streak',
                          'Day streak',
                          Icons.local_fire_department_rounded,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Quick actions
                    const Text(
                      'QUICK START',
                      style: TextStyle(
                        color: Pallete.subFontColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _quickActionCard(
                      icon: Icons.fitness_center_rounded,
                      title: 'Generate Workout',
                      subtitle: 'AI creates your perfect workout',
                      iconBgColor: Colors.orange.withValues(alpha: 0.15),
                      iconColor: Colors.orange,
                      logo: const _LogoWidget(
                        bgColor: Colors.orange,
                        icon: Icons.fitness_center_rounded,
                        emoji: '💪',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (c, a, b) => const WorkoutPage(),
                          transitionsBuilder: (c, a, b, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _quickActionCard(
                      icon: Icons.restaurant_rounded,
                      title: 'Plan My Meals',
                      subtitle: 'AI generates your meal plan',
                      iconBgColor: Colors.green.withValues(alpha: 0.15),
                      iconColor: Colors.green,
                      logo: const _LogoWidget(
                        bgColor: Colors.green,
                        icon: Icons.restaurant_rounded,
                        emoji: '🥗',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (c, a, b) => const MealPlannerPage(),
                          transitionsBuilder: (c, a, b, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _quickActionCard(
                      icon: Icons.document_scanner_rounded,
                      title: 'Scan Food Calories',
                      subtitle: 'AI estimates calories from photo',
                      iconBgColor: Colors.purple.withValues(alpha: 0.15),
                      iconColor: Colors.purple,
                      logo: const _LogoWidget(
                        bgColor: Colors.purple,
                        icon: Icons.document_scanner_rounded,
                        emoji: '📷',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (c, a, b) => const CalorieScannerPage(),
                          transitionsBuilder: (c, a, b, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _quickActionCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Ask AI Coach',
                      subtitle: 'Get fitness advice instantly',
                      iconBgColor: Colors.blue.withValues(alpha: 0.15),
                      iconColor: Colors.blue,
                      logo: const _LogoWidget(
                        bgColor: Colors.blue,
                        icon: Icons.chat_bubble_outline_rounded,
                        emoji: '🤖',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (c, a, b) => const ChatPage(),
                          transitionsBuilder: (c, a, b, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _quickActionCard(
                      icon: Icons.trending_up_rounded,
                      title: 'Log Progress',
                      subtitle: 'Track your weight and workouts',
                      iconBgColor: Colors.teal.withValues(alpha: 0.15),
                      iconColor: Colors.teal,
                      logo: const _LogoWidget(
                        bgColor: Colors.teal,
                        icon: Icons.trending_up_rounded,
                        emoji: '📊',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (c, a, b) => const ProgressPage(),
                          transitionsBuilder: (c, a, b, child) =>
                              FadeTransition(opacity: a, child: child),
                          transitionDuration: const Duration(milliseconds: 200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: Pallete.primaryAccent, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Pallete.mainFontColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Pallete.subFontColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconBgColor,
    Color? iconColor,
    Widget? logo,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Pallete.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Pallete.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBgColor ??
                    Pallete.primaryAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: logo ??
                  Icon(icon,
                      color: iconColor ?? Pallete.primaryAccent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Pallete.mainFontColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Pallete.subFontColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Pallete.subFontColor,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(String email) {
    return Drawer(
      backgroundColor: Pallete.drawerBackground,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              color: Pallete.surfaceColor,
              border: Border(
                bottom: BorderSide(color: Pallete.borderColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Pallete.primaryAccent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Pallete.cardColor,
                    child: Text(
                      email.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Pallete.primaryAccent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  email,
                  style: const TextStyle(
                    color: Pallete.mainFontColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Pallete.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Active',
                      style: TextStyle(
                        color: Pallete.successColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  _drawerItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isActive: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _drawerItem(
                    icon: Icons.fitness_center_rounded,
                    label: 'Workout Generator',
                    onTap: () => _navigate(const WorkoutPage()),
                  ),
                  _drawerItem(
                    icon: Icons.restaurant_rounded,
                    label: 'Meal Planner',
                    onTap: () => _navigate(const MealPlannerPage()),
                  ),
                  _drawerItem(
                    icon: Icons.document_scanner_rounded,
                    label: 'Calorie Scanner',
                    onTap: () => _navigate(const CalorieScannerPage()),
                  ),
                  _drawerItem(
                    icon: Icons.trending_up_rounded,
                    label: 'Progress',
                    onTap: () => _navigate(const ProgressPage()),
                  ),
                  _drawerItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'AI Coach Chat',
                    onTap: () => _navigate(const ChatPage()),
                  ),
                  _drawerItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    onTap: () => _navigate(const ProfilePage()),
                  ),
                  _drawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _navigate(const SettingsPage()),
                  ),
                  _drawerItem(
                    icon: Icons.info_outline_rounded,
                    label: 'About',
                    onTap: () => _navigate(const AboutPage()),
                  ),
                  const Spacer(),
                  const Divider(color: Pallete.borderColor, height: 1),
                  const SizedBox(height: 8),
                  _drawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    iconColor: Pallete.dangerColor,
                    labelColor: Pallete.dangerColor,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<AuthCubit>().logout();
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    Color? iconColor,
    Color? labelColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive ? Pallete.drawerItemActive : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: iconColor ??
                      (isActive ? Pallete.primaryAccent : Pallete.subFontColor),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor ??
                        (isActive
                            ? Pallete.mainFontColor
                            : Pallete.subFontColor),
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Pallete.primaryAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  final Color bgColor;
  final IconData icon;
  final String emoji;

  const _LogoWidget({
    required this.bgColor,
    required this.icon,
    required this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: bgColor, size: 26),
          Positioned(
            right: 2,
            bottom: 2,
            child: Text(emoji, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
