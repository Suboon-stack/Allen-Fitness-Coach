import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/workout_page.dart';
import '../pages/meal_planner_page.dart';
import '../pages/progress_page.dart';
import '../pages/profile_page.dart';

/// Reuses existing routes. Returning to a destination already on the stack
/// restores that route's state; no duplicate instance is pushed in that case.
class FeatureNavigation extends StatefulWidget {
  const FeatureNavigation(
      {super.key, required this.index, this.destination = true, this.onReturn});
  final int index;
  final bool destination;
  final VoidCallback? onReturn;
  @override
  State<FeatureNavigation> createState() => _FeatureNavigationState();
}

class _FeatureNavigationState extends State<FeatureNavigation> {
  static final _routes = <NavigatorState, Map<int, Route<dynamic>>>{};
  NavigatorState? _navigator;
  Route<dynamic>? _route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.destination) return;
    _navigator = Navigator.of(context);
    _route = ModalRoute.of(context);
    if (_route != null) (_routes[_navigator!] ??= {})[widget.index] = _route!;
  }

  @override
  void dispose() {
    final routes = _routes[_navigator];
    if (routes?[widget.index] == _route) routes?.remove(widget.index);
    if (routes?.isEmpty ?? false) _routes.remove(_navigator);
    super.dispose();
  }

  Future<void> _select(int index) async {
    final nav = Navigator.of(context);
    final existing = _routes[nav]?[index];
    if (existing != null && existing.isActive) {
      nav.popUntil((r) => r == existing);
      return;
    }
    final pages = <Widget>[
      const HomePage(),
      const WorkoutPage(),
      const MealPlannerPage(),
      const ProgressPage(),
      const ProfilePage()
    ];
    await nav.push(MaterialPageRoute<void>(
        settings: RouteSettings(name: '/allen/$index'),
        builder: (_) => pages[index]));
    if (mounted) widget.onReturn?.call();
  }

  @override
  Widget build(BuildContext context) => NavigationBar(
          height: 72,
          selectedIndex: widget.index,
          labelBehavior: MediaQuery.textScalerOf(context).scale(12) > 18
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: _select,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.fitness_center), label: 'Workout'),
            NavigationDestination(
                icon: Icon(Icons.restaurant_outlined), label: 'Nutrition'),
            NavigationDestination(
                icon: Icon(Icons.insights_outlined), label: 'Progress'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile'),
          ]);
}
