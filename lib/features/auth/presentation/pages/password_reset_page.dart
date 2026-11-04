import 'package:allen/features/auth/presentation/components/studio_components.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key, this.initialEmail = ''});
  final String initialEmail;
  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  bool _sent = false;
  bool _submitted = false;
  String? _error;

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await context.read<AuthCubit>().forgetPassword(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = result == AuthCubit.passwordResetSuccess;
      _error = _sent ? null : result;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StudioAuthLayout(
        eyebrow: 'LET’S GET YOU BACK IN',
        title: _sent ? 'Check your\ninbox.' : 'A fresh start.',
        description: _sent
            ? 'If an account uses ${_email.text.trim()}, you’ll receive a link to reset your password. Check your spam folder too.'
            : 'Forgot your password? We’ll help you find your way back.',
        onBack: () => Navigator.of(context).pop(),
        child: _sent
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(Icons.mark_email_read_outlined, size: 48)),
                const SizedBox(height: 32),
                StudioButton(
                    label: 'Back to sign in',
                    onPressed: () => Navigator.of(context).pop()),
                const SizedBox(height: 12),
                TextButton(
                    onPressed: () => setState(() {
                          _sent = false;
                          _submitted = false;
                        }),
                    child: const Text('Use a different email')),
              ])
            : Form(
                key: _formKey,
                autovalidateMode: _submitted
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) StudioNotice(_error!),
                      StudioField(
                          inputKey: const Key('reset-email'),
                          controller: _email,
                          label: 'Email address',
                          hint: 'you@example.com',
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          validator: StudioValidation.email,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _send()),
                      const SizedBox(height: 4),
                      StudioButton(
                          label: 'Send reset link',
                          busyLabel: 'Sending your link…',
                          busy: _busy,
                          onPressed: _send),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to sign in')),
                    ]),
              ),
      );
}
