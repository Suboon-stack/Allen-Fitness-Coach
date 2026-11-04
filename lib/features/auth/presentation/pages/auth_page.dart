import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:allen/features/auth/presentation/pages/login_page.dart';
import 'package:allen/features/auth/presentation/pages/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.initialRegister = false, this.onBack});
  final bool initialRegister;
  final VoidCallback? onBack;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late bool _showLogin = !widget.initialRegister;
  String? _error;

  void _toggle() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showLogin = !_showLogin;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) setState(() => _error = state.message);
          if (state is AuthLoading) setState(() => _error = null);
        },
        builder: (context, state) {
          final busy = state is AuthLoading;
          return PopScope(
            canPop: widget.onBack == null,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !busy) widget.onBack?.call();
            },
            child: IndexedStack(index: _showLogin ? 0 : 1, children: [
              LoginPage(
                  tooglePages: _toggle,
                  onBack: widget.onBack,
                  busy: busy,
                  error: _error),
              RegisterPage(
                  tooglePages: _toggle,
                  onBack: widget.onBack,
                  busy: busy,
                  error: _error),
            ]),
          );
        },
      );
}
