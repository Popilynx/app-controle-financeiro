import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../repository/transactions_repository.dart';
import 'add_transaction_dialog.dart';

// Provedores para os filtros de busca e tipo na listagem de transações
final transactionsSearchProvider = StateProvider<String>((ref) => '');
final transactionsTypeFilterProvider = StateProvider<String>((ref) => 'Todos'); // 'Todos', 'Receita', 'Despesa'

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(dashboardTransactionsProvider);
    final search = ref.watch(transactionsSearchProvider);
    final typeFilter = ref.watch(transactionsTypeFilterProvider);
    final curFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho da listagem
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Histórico Financeiro',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Transações',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),

            // Barra de Busca e Filtros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Campo de Busca
                  TextField(
                    onChanged: (val) => ref.read(transactionsSearchProvider.notifier).state = val,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por descrição ou categoria...',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      fillColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filtros de Tipo
                  Row(
                    children: [
                      _buildFilterChip(ref, 'Todos', typeFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip(ref, 'Receita', typeFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip(ref, 'Despesa', typeFilter),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lista de Transações com Filtragem Reativa Local
            Expanded(
              child: transactionsAsync.when(
                data: (transactions) {
                  // Filtrar localmente baseado nas preferências selecionadas
                  final filtered = transactions.where((tx) {
                    final matchesSearch = tx.description.toLowerCase().contains(search.toLowerCase()) ||
                        tx.category.toLowerCase().contains(search.toLowerCase());
                    final matchesType = typeFilter == 'Todos' || tx.type == typeFilter;
                    return matchesSearch && matchesType;
                  }).toList();

                  // Exibir do mais recente para o mais antigo
                  final sorted = filtered.reversed.toList();

                  if (sorted.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nenhuma transação encontrada.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final tx = sorted[index];
                      return _buildDismissibleTransaction(context, ref, tx, curFormat);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Erro ao carregar transações: $e',
                    style: const TextStyle(color: AppColors.expense),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddTransactionDialog(),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, String currentSelection) {
    final isSelected = currentSelection == label;
    return GestureDetector(
      onTap: () => ref.read(transactionsTypeFilterProvider.notifier).state = label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.glassBorder,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDismissibleTransaction(
    BuildContext context,
    WidgetRef ref,
    Transaction tx,
    NumberFormat curFormat,
  ) {
    final isIncome = tx.type == 'Receita';
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '-';

    return Dismissible(
      key: Key(tx.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir Transação'),
            content: const Text('Tem certeza de que deseja excluir permanentemente esta transação do histórico?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Excluir', style: TextStyle(color: AppColors.expense, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final repository = ref.read(transactionsRepositoryProvider);
        await repository.deleteTransaction(tx);
        
        // Atualiza a listagem e os resumos
        ref.invalidate(dashboardTransactionsProvider);
        ref.invalidate(availableMonthsProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transação excluída com sucesso!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isIncome ? AppColors.income.withValues(alpha: 0.1) : AppColors.expense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: amountColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx.category,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign${curFormat.format(tx.amount)}',
                  style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(tx.date),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
