import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

class TransactionsRepository {
  final AppDatabase _db;
  TransactionsRepository(this._db);

  Future<List<Transaction>> getAllTransactions() => _db.allTransactions;

  Future<List<Transaction>> getTransactionsByMonth(String monthYear) => _db.getTransactionsByMonth(monthYear);

  Future<List<String>> getAvailableMonths() => _db.getAvailableMonths();

  Future<int> addTransaction(TransactionsCompanion entry) => _db.insertTransaction(entry);

  Future<void> addTransactionsBatch(List<TransactionsCompanion> entries) => _db.insertTransactionsBatch(entries);

  Future<bool> updateTransaction(Transaction entry) => _db.updateTransaction(entry);

  Future<int> deleteTransaction(Transaction entry) => _db.deleteTransaction(entry);

  Future<void> clearAll() => _db.clearDatabase();
}

final transactionsRepositoryProvider = Provider<TransactionsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionsRepository(db);
});
