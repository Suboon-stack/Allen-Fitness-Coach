import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/features/auth/presentation/cubits/auth_state.dart';
import 'package:allen/features/auth/presentation/pages/auth_page.dart';
import 'package:allen/fitness/pages/home_page.dart';
import 'package:allen/pallete.dart';
import 'package:allen/intro/intro_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class IntroGate extends StatefulWidget {
  const IntroGate({super.key});

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool showIntro = true;

  void finishIntro() {
    setState(() {
      showIntro = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showIntro) {
      return IntroPage(onContinue: finishIntro);
    }

    return BlocConsumer<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return const HomePage();
        }
        if (state is Unauthenticated) {
          return const AuthPage();
        }
        return const Scaffold(
          backgroundColor: Pallete.backgroundColor,
          body: Center(
            child: CircularProgressIndicator(
              color: Pallete.primaryAccent,
            ),
          ),
        );
      },
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Pallete.dangerColor,
            ),
          );
        }
      },
    );
  }
}
