import 'dart:async';
import 'package:allen/features/auth/data/user_repository.dart';
import 'package:allen/features/auth/domain/entities/app_user.dart';
import 'package:allen/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:allen/fitness/models/user_profile_model.dart';
import 'package:allen/fitness/pages/profile_page.dart';
import 'package:allen/fitness/pages/account_security_page.dart';
import 'package:allen/fitness/pages/settings_page.dart';
import 'package:allen/fitness/pages/data_privacy_page.dart';
import 'package:allen/fitness/pages/workout_page.dart';
import 'package:allen/fitness/pages/progress_page.dart';
import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:allen/fitness/services/notification_service.dart';
import 'package:allen/fitness/theme/app_theme.dart';
import 'package:allen/fitness/widgets/feature_navigation.dart';
import 'package:allen/fitness/widgets/profile_edit_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/fake_auth_repo.dart';
import 'profile_repository_test.dart' show profile;

class ControlledProfiles extends UserRepository {
  final reads = <String, Completer<UserProfile?>>{};
  bool fail = false;
  @override
  Future<UserProfile?> getUserProfile(String uid) {
    if (fail) return Future.error(StateError('private-detail-secret'));
    return (reads[uid] ??= Completer<UserProfile?>()).future;
  }
}

class SettingsNotifications extends NotificationService {
  SettingsNotifications() : super.withPlugin(FlutterLocalNotificationsPlugin());
  NotificationPermission status = NotificationPermission.denied;
  int requests = 0, tests = 0;
  Completer<bool>? pending;
  bool fail = false;
  @override
  Future<NotificationPermission> permissionStatus() async {
    if (fail) throw StateError('private-notification-error');
    return status;
  }

  @override
  Future<NotificationPermission> requestPermission() async {
    requests++;
    return status = NotificationPermission.allowed;
  }

  @override
  Future<bool> sendTestNotification() async {
    tests++;
    return pending != null ? await pending!.future : true;
  }
}

void main() {
  late FakeAuthRepo authRepo;
  late AuthCubit auth;
  late UserRepository profiles;
  late ProgressRepository progress;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    authRepo = FakeAuthRepo()
      ..user =
          AppUser(uid: 'a', email: 'a@example.com', displayName: 'Alex Allen');
    auth = AuthCubit(authRepo: authRepo);
    await auth.checkAuth();
    profiles = UserRepository(authenticatedUser: () => auth.currentUser?.uid);
    progress =
        ProgressRepository(authenticatedUser: () => auth.currentUser?.uid);
  });
  tearDown(() async => auth.close());
  Future<void> pump(WidgetTester t, Widget page,
      {double scale = 1,
      Size size = const Size(390, 844),
      double keyboard = 0}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            theme: AppTheme.midnightTheme,
            home: MediaQuery(
                data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                    viewInsets: EdgeInsets.only(bottom: keyboard)),
                child: page))));
    await t.pump();
  }

  Future<void> reveal(WidgetTester t, Finder finder) async {
    await t.ensureVisible(finder);
    await t.pumpAndSettle();
  }

  ProfilePage overview({UserRepository? repo}) =>
      ProfilePage(repository: repo ?? profiles, progressRepository: progress);
  testWidgets(
      'Empty profile uses real identity without invented goal or weight',
      (t) async {
    await pump(t, overview());
    await t.pumpAndSettle();
    expect(find.text('Alex Allen'), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.text('Add a goal in personal details'), findsOneWidget);
    expect(find.text('Maintain Weight'), findsNothing);
    expect(find.text('75.0'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(t.takeException(), isNull);
  });
  testWidgets('Owned statistics and saved profile replace mockup values',
      (t) async {
    await profiles.createUserProfile(profile('a', name: 'Actual Name'));
    final now =
        DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String();
    await LocalStorageService().saveWorkouts([
      {
        'id': 'mine',
        'userId': 'a',
        'name': 'Session',
        'date': now,
        'durationMinutes': 30,
        'completed': true
      },
      {
        'id': 'foreign',
        'userId': 'b',
        'name': 'Private',
        'date': now,
        'durationMinutes': 30,
        'completed': true
      }
    ]);
    await LocalStorageService().saveWeights([
      {
        'id': 'weight',
        'userId': 'a',
        'weight': 72.4,
        'date': now,
        'createdAt': now
      },
      {
        'id': 'other',
        'userId': 'b',
        'weight': 999,
        'date': now,
        'createdAt': now
      }
    ]);
    await pump(t, overview());
    await t.pumpAndSettle();
    expect(find.text('Actual Name'), findsOneWidget);
    expect(find.text('72.4'), findsOneWidget);
    expect(find.text('999.0'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Workouts: 1')), findsOneWidget);
  });
  testWidgets('Loading and sanitized error states permit retry', (t) async {
    final controlled = ControlledProfiles();
    await pump(t, overview(repo: controlled));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    controlled.reads['a']!.completeError(StateError('private-detail-secret'));
    await t.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('private-detail-secret'), findsNothing);
    controlled.reads['a'] = Completer<UserProfile?>()
      ..complete(profile('a', name: 'Recovered'));
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('Recovered'), findsOneWidget);
  });
  testWidgets('Account switch discards stale profile and adopts new identity',
      (t) async {
    final controlled = ControlledProfiles();
    await pump(t, overview(repo: controlled));
    authRepo.user =
        AppUser(uid: 'b', email: 'b@example.com', displayName: 'Beta');
    await auth.checkAuth();
    await t.pump();
    await t.pump();
    controlled.reads['b']!.complete(profile('b', name: 'Beta saved'));
    controlled.reads['a']!.complete(profile('a', name: 'Old private name'));
    await t.pumpAndSettle();
    expect(find.text('Beta saved'), findsOneWidget);
    expect(find.textContaining('Old private name'), findsNothing);
    expect(find.text('a@example.com'), findsNothing);
  });
  testWidgets('Leaving during a read safely ignores its response', (t) async {
    final controlled = ControlledProfiles();
    await pump(t, overview(repo: controlled));
    await t.pumpWidget(const SizedBox());
    controlled.reads['a']!.complete(profile('a'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('Details editor validates and saves account-owned profile',
      (t) async {
    await pump(t, overview());
    await t.pumpAndSettle();
    await t.tap(find.text('Edit personal details'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Updated name');
    await t.enterText(find.widgetWithText(TextFormField, 'Age'), '-4');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await reveal(t, find.widgetWithText(FilledButton, 'Save details'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save details'));
    await t.pumpAndSettle();
    expect(find.textContaining('Enter a value above 0'), findsOneWidget);
    await reveal(t, find.widgetWithText(TextFormField, 'Age'));
    await t.enterText(find.widgetWithText(TextFormField, 'Age'), '29');
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await reveal(t, find.widgetWithText(FilledButton, 'Save details'));
    await t.pumpAndSettle();
    await t.tap(find.text('Save details'));
    await t.pumpAndSettle();
    expect((await profiles.getUserProfile('a'))!.name, 'Updated name');
    expect(find.text('Updated name'), findsOneWidget);
  });
  testWidgets(
      'Account change closes an open editor without saving to next account',
      (t) async {
    await pump(t, overview());
    await t.pumpAndSettle();
    await t.tap(find.text('Edit personal details'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextFormField, 'Name'), 'Unsubmitted');
    authRepo.user = AppUser(uid: 'b', email: 'b@example.com');
    await auth.checkAuth();
    await t.pumpAndSettle();
    expect(find.byType(ProfileEditor), findsNothing);
    expect(await profiles.getUserProfile('b'), isNull);
    expect(t.takeException(), isNull);
  });
  testWidgets('Reset email is explicit and duplicate requests are blocked',
      (t) async {
    authRepo.pendingReset = Completer<String>();
    await pump(t, const AccountSecurityPage());
    await t.pumpAndSettle();
    await t.tap(find.text('Reset password'));
    await t.pump();
    await t.tap(find.text('Reset password'));
    expect(authRepo.resetCalls, 1);
    expect(authRepo.submittedEmail, 'a@example.com');
    authRepo.pendingReset!.complete(AuthCubit.passwordResetSuccess);
    await t.pumpAndSettle();
    expect(find.textContaining('a password-reset link has been sent'),
        findsOneWidget);
  });
  testWidgets('Failed sign-out retains real session and shows safe failure',
      (t) async {
    authRepo.actionError = StateError('private-auth-error');
    await pump(t, const AccountSecurityPage());
    await t.pumpAndSettle();
    await t.tap(find.text('Sign out'));
    await t.pumpAndSettle();
    expect(auth.currentUser?.uid, 'a');
    expect(find.text('We couldn’t complete that request. Please try again.'),
        findsOneWidget);
    expect(find.textContaining('private-auth-error'), findsNothing);
  });
  testWidgets(
      'Account change and disposal discard a pending password-reset result',
      (t) async {
    authRepo.pendingReset = Completer<String>();
    await pump(t, const AccountSecurityPage());
    await t.pumpAndSettle();
    await t.tap(find.text('Reset password'));
    await t.pump();
    authRepo.user = AppUser(uid: 'b', email: 'b@example.com');
    await auth.checkAuth();
    await t.pumpAndSettle();
    authRepo.pendingReset!.complete(AuthCubit.passwordResetSuccess);
    await t.pumpAndSettle();
    expect(find.text('b@example.com'), findsOneWidget);
    expect(find.textContaining('a password-reset link has been sent'),
        findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('Reopening Settings reads notification permission again',
      (t) async {
    final notifications = SettingsNotifications();
    await pump(t, SettingsPage(notifications: notifications));
    await t.pumpAndSettle();
    await reveal(t, find.text('Allow notifications'));
    await t.tap(find.text('Allow notifications'));
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
    await pump(t, SettingsPage(notifications: notifications));
    await t.pumpAndSettle();
    expect(find.text('Allowed by Android'), findsOneWidget);
    expect(find.text('Electric Blue'), findsOneWidget);
  });
  testWidgets('Successful sign-out removes personal account content',
      (t) async {
    await pump(t, const AccountSecurityPage());
    await t.pumpAndSettle();
    await t.tap(find.text('Sign out'));
    await t.pumpAndSettle();
    expect(auth.currentUser, isNull);
    expect(find.text('a@example.com'), findsNothing);
  });
  testWidgets(
      'Notification permission and explicit test are honest and guarded',
      (t) async {
    final notifications = SettingsNotifications()..pending = Completer<bool>();
    await pump(t, SettingsPage(notifications: notifications));
    await t.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    await reveal(t, find.text('Allow notifications'));
    await t.tap(find.text('Allow notifications'));
    await t.pumpAndSettle();
    expect(notifications.requests, 1);
    await reveal(t, find.text('Send test notification'));
    await t.tap(find.text('Send test notification'));
    await t.pump();
    await t.tap(find.text('Send test notification'));
    expect(notifications.tests, 1);
    notifications.pending!.complete(true);
    await t.pumpAndSettle();
    expect(find.textContaining('Test notification sent.'), findsOneWidget);
  });
  testWidgets('Notification failures are sanitized and status refresh retries',
      (t) async {
    final notifications = SettingsNotifications()..fail = true;
    await pump(t, SettingsPage(notifications: notifications));
    await t.pumpAndSettle();
    expect(find.textContaining('private-notification-error'), findsNothing);
    expect(find.textContaining('couldn’t be checked'), findsOneWidget);
    notifications.fail = false;
    await t.tap(find.byTooltip('Refresh notification status'));
    await t.pumpAndSettle();
    expect(find.text('Not allowed by Android'), findsOneWidget);
  });
  testWidgets(
      'Five-tab navigation reuses existing routes and preserves workout tab',
      (t) async {
    await pump(
        t,
        const Scaffold(
            body: Text('Root Home'),
            bottomNavigationBar: FeatureNavigation(index: 0)));
    await t.pumpAndSettle();
    await t.tap(find.text('Workout'));
    await t.pumpAndSettle();
    await t.tap(find.text('Saved'));
    await t.pumpAndSettle();
    await t.tap(find.text('Progress'));
    await t.pumpAndSettle();
    expect(find.byType(ProgressPage), findsOneWidget);
    await t.tap(find.text('Workout'));
    await t.pumpAndSettle();
    expect(find.byType(ProgressPage), findsNothing);
    expect(t.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    await t.tap(find.text('Home'));
    await t.pumpAndSettle();
    expect(find.text('Root Home'), findsOneWidget);
    expect(find.byType(WorkoutPage), findsNothing);
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 400)
  ]) {
    testWidgets('Profile, Settings and Security fit $size at 200% text',
        (t) async {
      for (final page in [
        overview(),
        SettingsPage(notifications: SettingsNotifications()),
        const AccountSecurityPage(),
        DataPrivacyPage(repository: profiles)
      ]) {
        await pump(t, page, scale: 2, size: size);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    });
  }
  testWidgets('Editor remains scrollable above keyboard and Android insets',
      (t) async {
    await pump(t, ProfileEditor(user: auth.currentUser!, repository: profiles),
        size: const Size(320, 568), scale: 2, keyboard: 240);
    await t.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
    await reveal(t, find.widgetWithText(FilledButton, 'Save details'));
    await t.pumpAndSettle();
    expect(find.text('Save details').hitTestable(), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
