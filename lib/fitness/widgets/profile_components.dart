import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/cubits/auth_cubit.dart';
import '../../features/auth/presentation/cubits/auth_state.dart';
import '../theme/app_theme.dart';
import 'feature_navigation.dart';

AppUser? verifiedAccount(BuildContext context) {
  final auth = context.read<AuthCubit>();
  final state = auth.state;
  if (state is Unauthenticated ||
      state is AuthLoading ||
      state is AuthError && state.sessionUnresolved) {
    return null;
  }
  return auth.currentUser;
}

class AccountBoundary extends StatelessWidget {
  const AccountBoundary({super.key, required this.builder});
  final Widget Function(BuildContext, AppUser) builder;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AuthCubit, AuthState>(builder: (context, state) {
        final auth = context.read<AuthCubit>();
        final user = state is AuthLoading && !state.verifyingSession
            ? auth.currentUser
            : verifiedAccount(context);
        if (user == null) {
          return const AppThemeScope(
              child: Scaffold(
                  body: SafeArea(
                      child: Center(child: Text('Checking your account…')))));
        }
        return AppThemeScope(
            child: KeyedSubtree(
                key: ValueKey(user.uid), child: builder(context, user)));
      });
}

class ProfileScaffold extends StatelessWidget {
  const ProfileScaffold(
      {super.key, required this.title, required this.children, this.actions});
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => AppThemeScope(
      child: Builder(
          builder: (context) => Scaffold(
              appBar: AppBar(title: Text(title), actions: actions),
              bottomNavigationBar:
                  const FeatureNavigation(index: 4, destination: false),
              body: SafeArea(
                  top: false,
                  child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.page),
                      children: [
                        Center(
                            child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                    maxWidth: AppLayout.contentWidth),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: children)))
                      ])))));
}

class ProfileGroup extends StatelessWidget {
  const ProfileGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1)),
          children[i]
        ]
      ]));
}

class ProfileRow extends StatelessWidget {
  const ProfileRow(
      {super.key,
      required this.icon,
      required this.title,
      this.subtitle,
      this.value,
      this.onTap,
      this.trailing});
  final IconData icon;
  final String title;
  final String? subtitle, value;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
      trailing: trailing ??
          (value != null
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Text(value!,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall))
              : onTap != null
                  ? const Icon(Icons.chevron_right)
                  : null));
}

class ProfileSection extends StatelessWidget {
  const ProfileSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium));
}

class ProfileFeedback extends StatelessWidget {
  const ProfileFeedback(this.message, {super.key, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message),
            if (retry != null)
              TextButton(onPressed: retry, child: const Text('Retry'))
          ])));
}
