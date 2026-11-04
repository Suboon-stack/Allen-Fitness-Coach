import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:allen/features/auth/presentation/pages/auth_page.dart';
import 'package:allen/fitness/pages/home_page.dart';
import 'package:allen/intro/intro_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class IntroGate extends StatefulWidget {
  const IntroGate({super.key, this.authenticatedBuilder});

  /// Allows the session gate to be tested without constructing fitness services.
  final WidgetBuilder? authenticatedBuilder;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool _enteredAuth = false;
  bool _hadSession = false;

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          final cubit = context.read<AuthCubit>();
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            if (state.sessionUnresolved) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
          if (state is Unauthenticated && _hadSession) {
            _enteredAuth = true;
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          if (state is Authenticated || state is Unauthenticated) {
            _hadSession = cubit.currentUser != null;
          }
        },
        builder: (context, state) {
          final cubit = context.read<AuthCubit>();
          if (state is AuthError && state.sessionUnresolved) {
            return Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('We couldn’t verify your session.'),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: cubit.checkAuth,
                          child: const Text('Try again')),
                    ]),
                  ),
                ),
              ),
            );
          }
          if (cubit.currentUser != null) {
            return widget.authenticatedBuilder?.call(context) ??
                const HomePage();
          }
          if (!_enteredAuth && (state is AuthInitial || state is AuthLoading)) {
            return const Scaffold(
                body: Center(
                    child: CircularProgressIndicator(
                        semanticsLabel: 'Checking your session')));
          }
          if (!_enteredAuth) {
            return IntroPage(
                onContinue: () => setState(() => _enteredAuth = true));
          }
          // Keep this subtree mounted while loading and handling errors so its
          // controllers, validation, and selected form survive failed requests.
          return const AuthPage();
        },
      );
}
