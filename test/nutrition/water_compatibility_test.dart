import 'package:allen/fitness/repositories/progress_repository.dart';
import 'package:allen/fitness/services/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'Existing sequential water writes survive reload and share the Home data source',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repo = ProgressRepository();
    await repo.addWaterIntake('member', 100);
    await repo.addWaterIntake('member', 250);
    await (await SharedPreferences.getInstance()).reload();
    expect(await repo.getTodayWaterIntake('member'), 350);
    expect(await LocalStorageService().getTodayWater(), 350);
    // Current date-only storage is shared: no account-isolation claim is made.
    expect(await repo.getTodayWaterIntake('another'), 350);
  });
}
