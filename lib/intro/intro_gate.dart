import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/components/studio_components.dart';
import 'package:allen/features/auth/presentation/theme/performance_theme.dart';
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
  bool _register = false;

  @override
  void initState() {
    super.initState();
    _hadSession = context.read<AuthCubit>().currentUser != null;
  }

  void _enterAuth({required bool register}) => setState(() {
        _register = register;
        _enteredAuth = true;
      });

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          final cubit = context.read<AuthCubit>();
          if (state is AuthError) {
            if (!state.sessionUnresolved && cubit.currentUser != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
            if (state.sessionUnresolved) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }
          if (state is Unauthenticated && _hadSession) {
            _enteredAuth = true;
            _register = false;
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          if (state is Authenticated || state is Unauthenticated) {
            _hadSession = cubit.currentUser != null;
          }
        },
        builder: (context, state) {
          final cubit = context.read<AuthCubit>();
          if (state is AuthError && state.sessionUnresolved) {
            return StudioAuthLayout(
              eyebrow: 'A MOMENT TO RECONNECT',
              title: 'Let’s reconnect.',
              description:
                  'We couldn’t verify your session. Your saved data has not been changed.',
              child:
                  StudioButton(label: 'Try again', onPressed: cubit.checkAuth),
            );
          }
          if (state is AuthInitial ||
              (state is AuthLoading && state.verifyingSession)) {
            return const PerformanceScope(
                child: Scaffold(
                    body: Center(
                        child: CircularProgressIndicator(
                            semanticsLabel: 'Checking your session'))));
          }
          if (cubit.currentUser != null) {
            return widget.authenticatedBuilder?.call(context) ??
                const HomePage();
          }
          if (!_enteredAuth) {
            return IntroPage(
                onContinue: () => _enterAuth(register: true),
                onSignIn: () => _enterAuth(register: false));
          }
          // Keep this subtree mounted while loading and handling errors so its
          // controllers, validation, and selected form survive failed requests.
          return AuthPage(
              key: const ValueKey('authentication'),
              initialRegister: _register,
              onBack: () => setState(() => _enteredAuth = false));
        },
      );
}
