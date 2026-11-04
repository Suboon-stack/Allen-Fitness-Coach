import 'package:allen/features/auth/domain/entities/app_user.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {
  final bool verifyingSession;
  AuthLoading({this.verifyingSession = false});
}

class Authenticated extends AuthState {
  final AppUser user;
  Authenticated(this.user);
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  final bool sessionUnresolved;
  AuthError(this.message, {this.sessionUnresolved = false});
}
