import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/features/sync/services/update_service.dart';

void main() {
  group('UpdateService.isNewerVersion Tests', () {
    test('Identifica nova versão patch mais recente', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.1'), true);
      expect(UpdateService.isNewerVersion('1.0.1', '1.0.0'), false);
    });

    test('Identifica nova versão minor mais recente', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.1.0'), true);
      expect(UpdateService.isNewerVersion('1.2.0', '1.1.0'), false);
    });

    test('Identifica nova versão major mais recente', () {
      expect(UpdateService.isNewerVersion('1.9.9', '2.0.0'), true);
      expect(UpdateService.isNewerVersion('2.0.1', '1.9.9'), false);
    });

    test('Lida com versões iguais', () {
      expect(UpdateService.isNewerVersion('1.0.0', '1.0.0'), false);
      expect(UpdateService.isNewerVersion('v1.0.0', '1.0.0'), false);
    });

    test('Limpa caracteres "v" e espaços nas strings', () {
      expect(UpdateService.isNewerVersion('v1.0.0', 'v1.0.1'), true);
      expect(UpdateService.isNewerVersion(' 1.0.0 ', ' v1.0.1'), true);
      expect(UpdateService.isNewerVersion('v2.1.0', ' 2.0.9 '), false);
    });

    test('Lida com strings de versões incompletas de forma robusta', () {
      expect(UpdateService.isNewerVersion('1', '1.0.1'), true);
      expect(UpdateService.isNewerVersion('1.0', '1.0.0'), false);
      expect(UpdateService.isNewerVersion('1.0', '2'), true);
    });
  });
}
