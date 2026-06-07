import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text()();
  TextColumn get category => text()();
  TextColumn get type => text()(); // 'Receita' ou 'Despesa'
  RealColumn get amount => real()();
  TextColumn get monthYear => text()(); // Formato: "Junho 2026", "Julho 2026", etc. (conforme abas do Excel)
}

@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.executor(super.e);

  @override
  int get schemaVersion => 1;

  // Obter todas as transações
  Future<List<Transaction>> get allTransactions => select(transactions).get();

  // Obter transações por mês/ano (ex: "Junho 2026")
  Future<List<Transaction>> getTransactionsByMonth(String monthYearStr) {
    return (select(transactions)..where((t) => t.monthYear.equals(monthYearStr))).get();
  }

  // Obter lista única de todos os meses disponíveis
  Future<List<String>> getAvailableMonths() async {
    final query = selectOnly(transactions, distinct: true)..addColumns([transactions.monthYear]);
    final result = await query.map((row) => row.read(transactions.monthYear)).get();
    return result.whereType<String>().toList();
  }

  // Inserir transação
  Future<int> insertTransaction(TransactionsCompanion entry) => into(transactions).insert(entry);

  // Inserir transações em lote (batch) para importação rápida do Excel
  Future<void> insertTransactionsBatch(List<TransactionsCompanion> entries) async {
    await batch((batch) {
      batch.insertAll(transactions, entries, mode: InsertMode.insertOrReplace);
    });
  }

  // Atualizar transação
  Future<bool> updateTransaction(Transaction entry) => update(transactions).replace(entry);

  // Excluir transação
  Future<int> deleteTransaction(Transaction entry) => delete(transactions).delete(entry);

  // Limpar todas as transações
  Future<void> clearDatabase() async {
    await delete(transactions).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'controle_financeiro.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
