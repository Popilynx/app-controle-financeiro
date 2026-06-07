import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'services/google_drive_sync_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final container = ProviderContainer();
      final syncService = container.read(googleDriveSyncServiceProvider);
      await syncService.syncLocalDataToDrive();
      return true;
    } catch (e) {
      debugPrint('Erro de segundo plano no Workmanager: $e');
      return false;
    }
  });
}
