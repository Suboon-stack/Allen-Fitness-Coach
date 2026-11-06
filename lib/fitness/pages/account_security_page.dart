import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/cubits/auth_cubit.dart';
import '../../features/auth/presentation/cubits/auth_state.dart';
import '../widgets/profile_components.dart';

class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});
  @override
  Widget build(BuildContext context) =>
      AccountBoundary(builder: (context, user) => _AccountSecurity(user: user));
}

class _AccountSecurity extends StatefulWidget {
  const _AccountSecurity({required this.user});
  final AppUser user;
  @override
  State<_AccountSecurity> createState() => _AccountSecurityState();
}

class _AccountSecurityState extends State<_AccountSecurity> {
  bool _resetting = false;
  String? _message;
  Future<void> _reset() async {
    if (_resetting || verifiedAccount(context)?.uid != widget.user.uid) return;
    setState(() {
      _resetting = true;
      _message = null;
    });
    String result;
    try {
      result = await context
          .read<AuthCubit>()
          .forgetPassword(widget.user.email)
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      result = 'The reset email request took too long. Please try again.';
    }
    if (!mounted || verifiedAccount(context)?.uid != widget.user.uid) return;
    setState(() {
      _resetting = false;
      _message = result == AuthCubit.passwordResetSuccess
          ? 'If this account is eligible, a password-reset link has been sent. Check your inbox and spam folder.'
          : result;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Delete Account'),
                content: const Text(
                    'This deletes your Firebase sign-in account. Existing local fitness records are not erased. This cannot be undone. You may need to sign in again first.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete account'))
                ]));
    if (mounted &&
        confirmed == true &&
        verifiedAccount(context)?.uid == widget.user.uid) {
      await context.read<AuthCubit>().deleteAccount();
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthError && !state.sessionUnresolved && mounted) {
          setState(() => _message = state.message);
        }
      },
      child: ProfileScaffold(title: 'Account & Security', children: [
        if (context.watch<AuthCubit>().state is AuthLoading)
          const LinearProgressIndicator(
              semanticsLabel: 'Updating account session'),
        const SizedBox(height: 8),
        const ProfileGroup(children: [
          ProfileRow(
              icon: Icons.manage_accounts_outlined,
              title: 'Manage your account',
              subtitle:
                  'View your sign-in email, reset your password or sign out.')
        ]),
        const ProfileSection('Account'),
        ProfileGroup(children: [
          ProfileRow(
              icon: Icons.mail_outline,
              title: 'Email',
              subtitle: widget.user.email),
          ProfileRow(
              icon: Icons.lock_reset,
              title: 'Reset password',
              subtitle: 'Send a Firebase password-reset email',
              onTap: _resetting || verifiedAccount(context) == null
                  ? null
                  : _reset,
              trailing: _resetting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null),
        ]),
        if (_message != null) ProfileFeedback(_message!),
        const ProfileSection('Account access'),
        ProfileGroup(children: [
          ProfileRow(
              icon: Icons.logout,
              title: 'Sign out',
              onTap: _resetting || verifiedAccount(context) == null
                  ? null
                  : () => context.read<AuthCubit>().logout())
        ]),
        const SizedBox(height: 16),
        const Text(
            'Multi-factor authentication and active-device management are not implemented in Allen.'),
        const SizedBox(height: 24),
        ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Existing account deletion'),
            children: [
              const Text(
                  'The existing Firebase account-deletion operation is unchanged. It does not remove fitness data stored locally. A redesigned data-deletion flow is deferred.'),
              TextButton(
                  onPressed: _resetting || verifiedAccount(context) == null
                      ? null
                      : _delete,
                  child: const Text('Delete Account')),
            ]),
      ]));
}
