import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../transactions/repository/transactions_repository.dart';

// Provedor para o mês selecionado no dashboard (ex: "Junho 2026")
final dashboardMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  const months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];
  return '${months[now.month - 1]} ${now.year}';
});

// Provedor que busca as transações do mês selecionado
final dashboardTransactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  final selectedMonth = ref.watch(dashboardMonthProvider);
  return repository.getTransactionsByMonth(selectedMonth);
});

// Provedor que busca todos os meses que possuem dados para o filtro dropdown
final availableMonthsProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(transactionsRepositoryProvider);
  final list = await repository.getAvailableMonths();
  if (list.isEmpty) {
    // Retorna o mês atual como padrão se o banco estiver vazio
    final now = DateTime.now();
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return ['${months[now.month - 1]} ${now.year}'];
  }
  return list;
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(dashboardTransactionsProvider);
    final selectedMonth = ref.watch(dashboardMonthProvider);
    final monthsAsync = ref.watch(availableMonthsProvider);
    final curFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardTransactionsProvider);
            ref.invalidate(availableMonthsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho da Tela com Filtro de Mês
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Controle Financeiro',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Meu Dashboard',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    // Dropdown de meses elegantes
                    monthsAsync.when(
                      data: (months) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.glassBorder, width: 0.5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: months.contains(selectedMonth) ? selectedMonth : months.first,
                            dropdownColor: AppColors.surface,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.accent),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            items: months.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                ref.read(dashboardMonthProvider.notifier).state = newValue;
                              }
                            },
                          ),
                        ),
                      ),
                      loading: () => const SizedBox(width: 80, height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      error: (e, _) => const SizedBox(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Exibição dos Dados do Mês
                transactionsAsync.when(
                  data: (transactions) {
                    // Calcular totais
                    double totalIncome = 0;
                    double totalExpense = 0;
                    double totalInvestments = 0;

                    for (var tx in transactions) {
                      if (tx.type == 'Receita') {
                        totalIncome += tx.amount;
                      } else {
                        totalExpense += tx.amount;
                        if (tx.category.toLowerCase().contains('invest')) {
                          totalInvestments += tx.amount;
                        }
                      }
                    }

                    final double balance = totalIncome - totalExpense;
                    final double netBalance = balance; // Conforme o resumo da planilha

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cartão de Saldo Principal (Glassmorphism)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Color(0xFF312E81)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'SALDO DO MÊS',
                                    style: TextStyle(
                                      color: Color(0xFFC7D2FE),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFC7D2FE)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                curFormat.format(netBalance),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildBalanceRow(
                                      title: 'Receitas',
                                      amount: totalIncome,
                                      icon: Icons.arrow_upward_rounded,
                                      color: AppColors.income,
                                    ),
                                  ),
                                  Container(
                                    height: 30,
                                    width: 1,
                                    color: Colors.white.withValues(alpha: 0.15),
                                  ),
                                  Expanded(
                                    child: _buildBalanceRow(
                                      title: 'Despesas',
                                      amount: totalExpense,
                                      icon: Icons.arrow_downward_rounded,
                                      color: AppColors.expense,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Bloco de Investimentos adicionais se houver
                        if (totalInvestments > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.glassBorder, width: 0.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.trending_up_rounded, color: AppColors.savings),
                                    SizedBox(width: 12),
                                    Text(
                                      'Investimentos do Mês',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  curFormat.format(totalInvestments),
                                  style: const TextStyle(
                                    color: AppColors.savings,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Seção de Gráficos
                        if (transactions.isNotEmpty) ...[
                          const Text(
                            'Distribuição de Gastos',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildChartSection(transactions),
                          const SizedBox(height: 24),
                        ],

                        // Transações recentes
                        const Text(
                          'Transações Recentes',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (transactions.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'Nenhuma transação cadastrada neste mês.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: transactions.length > 5 ? 5 : transactions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final tx = transactions[transactions.length - 1 - index]; // Mostrar mais recentes primeiro
                              return _buildTransactionItem(tx, curFormat);
                            },
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(80),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Erro ao carregar dados: $e',
                        style: const TextStyle(color: AppColors.expense),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceRow({
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    final curFormat = NumberFormat.simpleCurrency(locale: 'pt_BR');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFC7D2FE),
                fontSize: 12,
              ),
            ),
            Text(
              curFormat.format(amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection(List<Transaction> transactions) {
    // Agrupar despesas por categoria
    final Map<String, double> expensesByCategory = {};
    double totalExpenses = 0;

    for (var tx in transactions) {
      if (tx.type == 'Despesa') {
        expensesByCategory.update(tx.category, (val) => val + tx.amount, ifAbsent: () => tx.amount);
        totalExpenses += tx.amount;
      }
    }

    if (totalExpenses == 0) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const Text('Sem despesas neste mês para gerar gráficos.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final colors = [
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
      Colors.teal,
      Colors.deepOrange,
      Colors.purple,
    ];

    int colorIdx = 0;
    final List<PieChartSectionData> sections = [];
    final List<Widget> legends = [];

    expensesByCategory.forEach((category, value) {
      final percentage = (value / totalExpenses) * 100;
      final color = colors[colorIdx % colors.length];
      colorIdx++;

      sections.add(
        PieChartSectionData(
          color: color,
          value: value,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );

      legends.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'R\$ ${value.toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    });

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: legends,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction tx, NumberFormat curFormat) {
    final isIncome = tx.type == 'Receita';
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Row(
        children: [
          // Ícone correspondente à categoria
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
          // Descrição e Categoria
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  tx.category,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Valor e Data
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${curFormat.format(tx.amount)}',
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM').format(tx.date),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
