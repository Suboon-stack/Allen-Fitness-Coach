import 'package:allen/features/auth/presentation/components/studio_components.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback? tooglePages;
  final VoidCallback? onBack;
  final bool busy;
  final String? error;
  const RegisterPage(
      {super.key,
      required this.tooglePages,
      this.onBack,
      this.busy = false,
      this.error});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitted = false;

  void _submit() {
    if (widget.busy) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().register(_name.text, _email.text, _password.text);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StudioAuthLayout(
        eyebrow: 'MAKE YOUR FIRST MOVE',
        title: 'Start with you.',
        description: 'One account for your movement, meals, and AI coach.',
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
                inputKey: const Key('register-name'),
                controller: _name,
                label: 'Your name',
                hint: 'What should we call you?',
                enabled: !widget.busy,
                autofillHints: const [AutofillHints.name],
                keyboardType: TextInputType.name,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name.'
                    : null),
            StudioField(
                inputKey: const Key('register-email'),
                controller: _email,
                label: 'Email address',
                hint: 'you@example.com',
                enabled: !widget.busy,
                validator: StudioValidation.email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email]),
            StudioField(
                inputKey: const Key('register-password'),
                controller: _password,
                label: 'Password',
                hint: 'At least 6 characters',
                password: true,
                enabled: !widget.busy,
                validator: StudioValidation.newPassword,
                autofillHints: const [AutofillHints.newPassword]),
            StudioField(
                inputKey: const Key('register-confirm'),
                controller: _confirm,
                label: 'Confirm password',
                hint: 'Enter your password again',
                password: true,
                enabled: !widget.busy,
                textInputAction: TextInputAction.done,
                validator: (value) => value == null || value.isEmpty
                    ? 'Confirm your password.'
                    : value != _password.text
                        ? 'Your passwords don’t match.'
                        : null,
                onSubmitted: (_) => _submit()),
            const SizedBox(height: 4),
            StudioButton(
                label: 'Create account',
                busyLabel: 'Creating your account…',
                busy: widget.busy,
                onPressed: _submit),
            const SizedBox(height: 24),
            Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Already a member?'),
                  TextButton(
                      onPressed: widget.busy ? null : widget.tooglePages,
                      child: const Text('Sign in')),
                ]),
          ]),
        )),
      );
}
