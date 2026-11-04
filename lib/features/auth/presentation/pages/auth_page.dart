import 'package:allen/features/auth/presentation/pages/login_page.dart';
import 'package:allen/features/auth/presentation/pages/register_page.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool showLoginPage = true;

  void tooglePages() => setState(() => showLoginPage = !showLoginPage);

  @override
  Widget build(BuildContext context) => IndexedStack(
        index: showLoginPage ? 0 : 1,
        children: [
          LoginPage(tooglePages: tooglePages),
          RegisterPage(tooglePages: tooglePages),
        ],
      );
}
