import 'package:allen/features/auth/presentation/components/studio_components.dart';
import 'package:allen/features/auth/presentation/theme/performance_theme.dart';
import 'package:flutter/material.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key, required this.onContinue, this.onSignIn});
  final VoidCallback onContinue;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) => PerformanceScope(
      child: Builder(
          builder: (context) => Scaffold(
                body: SafeArea(
                    child: LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final hero = Container(
                    decoration: BoxDecoration(
                        color: PerformanceTheme.ink,
                        borderRadius: BorderRadius.circular(28)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                              padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const StudioWordmark(onDark: true),
                                    const SizedBox(height: 24),
                                    const Text('TRAIN WITH INTENT',
                                        style: TextStyle(
                                            color: PerformanceTheme.lime,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2)),
                                    const SizedBox(height: 16),
                                    Text('Your next\nchapter\nstarts here.',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: wide
                                                ? 64
                                                : constraints.maxHeight < 750
                                                    ? 38
                                                    : 44,
                                            fontWeight: FontWeight.w800,
                                            height: 1.03,
                                            letterSpacing: -2)),
                                  ])),
                          SizedBox(
                              height: wide ? 180 : 80,
                              width: double.infinity,
                              child: const MovementArtwork()),
                        ]),
                  );
                  final introduction = ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Find your rhythm.',
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 12),
                            const Text(
                                'Move with a plan. Eat with intention. Get guidance along the way.',
                                style: TextStyle(fontSize: 16, height: 1.6)),
                            const SizedBox(height: 24),
                            const Wrap(spacing: 20, runSpacing: 12, children: [
                              _Pillar(Icons.fitness_center_rounded, 'Workouts'),
                              _Pillar(Icons.restaurant_outlined, 'Nutrition'),
                              _Pillar(Icons.auto_awesome_outlined, 'AI coach'),
                            ]),
                            const SizedBox(height: 32),
                            StudioButton(
                                label: 'Get started', onPressed: onContinue),
                            const SizedBox(height: 12),
                            Center(
                                child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                  const Text('Already a member?'),
                                  TextButton(
                                      onPressed: onSignIn ?? onContinue,
                                      child: const Text('Sign in')),
                                ])),
                          ]));
                  return SingleChildScrollView(
                      child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                        child: Container(
                      constraints: const BoxConstraints(
                          maxWidth: StudioSpace.contentWidth),
                      padding: EdgeInsets.all(wide ? 40 : 16),
                      child: wide
                          ? Row(children: [
                              Expanded(child: hero),
                              const SizedBox(width: 64),
                              Expanded(child: introduction)
                            ])
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                  hero,
                                  Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 32, 12, 12),
                                      child: Align(child: introduction))
                                ]),
                    )),
                  ));
                })),
              )));
}

class _Pillar extends StatelessWidget {
  const _Pillar(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12)),
      ]);
}
