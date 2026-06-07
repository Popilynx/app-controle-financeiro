import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro/main.dart';
import 'package:controle_financeiro/core/database/database_provider.dart';
import 'package:controle_financeiro/core/database/database.dart';

void main() {
  testWidgets('App loads home screen successfully', (WidgetTester tester) async {
    final testDb = AppDatabase.executor(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
        ],
        child: const MyApp(),
      ),
    );

    // Permitir animações e renderizações assíncronas
    await tester.pumpAndSettle();

    // Verificar se a estrutura do MaterialApp está presente
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Limpeza após teste
    await testDb.close();
  });
}
