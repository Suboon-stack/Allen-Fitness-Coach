import 'package:allen/features/auth/presentation/components/studio_components.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/pages/password_reset_page.dart';
import 'package:allen/features/auth/presentation/theme/performance_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? tooglePages;
  final VoidCallback? onBack;
  final bool busy;
  final String? error;
  const LoginPage(
      {super.key,
      required this.tooglePages,
      this.onBack,
      this.busy = false,
      this.error});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitted = false;

  void _submit() {
    if (widget.busy) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().login(_email.text, _password.text);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PerformanceScope(
        child: Builder(builder: (context) {
          final theme = Theme.of(context);
          return Scaffold(
            body: SafeArea(
              child: LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxHeight < 600;
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth: StudioSpace.formWidth + 48),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth < 380 ? 20 : 24,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 48,
                              child: Row(children: [
                                const StudioWordmark(),
                                const Spacer(),
                                if (widget.onBack != null)
                                  IconButton(
                                    tooltip: 'Back',
                                    onPressed:
                                        widget.busy ? null : widget.onBack,
                                    icon: const Icon(Icons.arrow_back_rounded),
                                  ),
                              ]),
                            ),
                            SizedBox(height: compact ? 32 : 56),
                            Text('Welcome back.',
                                style: theme.textTheme.headlineMedium),
                            const SizedBox(height: 8),
                            Text('Sign in to continue your journey.',
                                style: theme.textTheme.bodyLarge),
                            const SizedBox(height: 32),
                            AutofillGroup(
                              child: Form(
                                key: _formKey,
                                autovalidateMode: _submitted
                                    ? AutovalidateMode.onUserInteraction
                                    : AutovalidateMode.disabled,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (widget.error != null)
                                      StudioNotice(widget.error!),
                                    StudioField(
                                      inputKey: const Key('login-email'),
                                      controller: _email,
                                      label: 'Email address',
                                      hint: 'you@example.com',
                                      validator: StudioValidation.email,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [
                                        AutofillHints.username
                                      ],
                                      enabled: !widget.busy,
                                    ),
                                    StudioField(
                                      inputKey: const Key('login-password'),
                                      controller: _password,
                                      label: 'Password',
                                      hint: 'Your password',
                                      password: true,
                                      validator: StudioValidation.password,
                                      enabled: !widget.busy,
                                      autofillHints: const [
                                        AutofillHints.password
                                      ],
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) => _submit(),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: widget.busy
                                            ? null
                                            : () => Navigator.of(context).push(
                                                MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        PasswordResetPage(
                                                            initialEmail: _email
                                                                .text
                                                                .trim()))),
                                        child: const Text('Forgot password?'),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      onPressed: widget.busy ? null : _submit,
                                      child: Semantics(
                                        liveRegion: true,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            if (widget.busy) ...[
                                              const SizedBox.square(
                                                  dimension: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2)),
                                              const SizedBox(width: 12),
                                            ],
                                            Flexible(
                                                child: Text(widget.busy
                                                    ? 'Signing in…'
                                                    : 'Sign In')),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        const Text("Don't have an account?"),
                                        TextButton(
                                          onPressed: widget.busy
                                              ? null
                                              : widget.tooglePages,
                                          child: const Text('Sign up'),
                                        ),
                                      ],
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
              }),
            ),
          );
        }),
      );
}
