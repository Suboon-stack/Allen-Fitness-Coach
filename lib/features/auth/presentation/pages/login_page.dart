import 'package:allen/features/auth/presentation/components/studio_components.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/pages/password_reset_page.dart';
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
  Widget build(BuildContext context) => StudioAuthLayout(
        eyebrow: 'YOUR SPACE. YOUR PACE.',
        title: 'Good to have\nyou back.',
        description: 'Pick up where you left off. Your next step is waiting.',
        onBack: widget.busy ? null : widget.onBack,
        child: AutofillGroup(
            child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (widget.error != null) StudioNotice(widget.error!),
            StudioField(
                inputKey: const Key('login-email'),
                controller: _email,
                label: 'Email address',
                hint: 'you@example.com',
                validator: StudioValidation.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                enabled: !widget.busy),
            StudioField(
                inputKey: const Key('login-password'),
                controller: _password,
                label: 'Password',
                hint: 'Your password',
                password: true,
                validator: StudioValidation.password,
                enabled: !widget.busy,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit()),
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: widget.busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => PasswordResetPage(
                                    initialEmail: _email.text.trim()))),
                    child: const Text('Forgot password?'))),
            const SizedBox(height: 16),
            StudioButton(
                label: 'Sign in',
                busyLabel: 'Signing in…',
                busy: widget.busy,
                onPressed: _submit),
            const SizedBox(height: 24),
            Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('New to Allen?'),
                  TextButton(
                      onPressed: widget.busy ? null : widget.tooglePages,
                      child: const Text('Create an account')),
                ]),
          ]),
        )),
      );
}
