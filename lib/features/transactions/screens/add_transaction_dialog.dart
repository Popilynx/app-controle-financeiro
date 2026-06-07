import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../repository/transactions_repository.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class AddTransactionDialog extends ConsumerStatefulWidget {
  const AddTransactionDialog({super.key});

  @override
  ConsumerState<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  
  String _type = 'Despesa'; // Padrão
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() {
        _selectedDate = pickedDate;
      });
    });
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;

    final enteredDescription = _descriptionController.text.trim();
    final enteredAmount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final enteredCategory = _categoryController.text.trim().isEmpty 
        ? (_type == 'Receita' ? 'Salário' : 'Outros')
        : _categoryController.text.trim();

    // Formatar mês/ano do Drift (ex: "Junho 2026")
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final monthYear = '${months[_selectedDate.month - 1]} ${_selectedDate.year}';

    final repository = ref.read(transactionsRepositoryProvider);
    
    await repository.addTransaction(
      TransactionsCompanion(
        date: drift.Value(_selectedDate),
        description: drift.Value(enteredDescription),
        category: drift.Value(enteredCategory),
        type: drift.Value(_type),
        amount: drift.Value(enteredAmount),
        monthYear: drift.Value(monthYear),
      ),
    );

    // Invalidar os provedores para forçar a atualização imediata da tela
    ref.invalidate(dashboardTransactionsProvider);
    ref.invalidate(availableMonthsProvider);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transação adicionada com sucesso!'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nova Transação',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Seleção de Tipo (Receita / Despesa)
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = 'Despesa'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _type == 'Despesa' 
                                ? AppColors.expense.withValues(alpha: 0.15) 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _type == 'Despesa' ? AppColors.expense : AppColors.glassBorder,
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Despesa',
                              style: TextStyle(
                                color: AppColors.expense,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = 'Receita'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _type == 'Receita' 
                                ? AppColors.income.withValues(alpha: 0.15) 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _type == 'Receita' ? AppColors.income : AppColors.glassBorder,
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Receita',
                              style: TextStyle(
                                color: AppColors.income,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Campo Valor
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    prefixIcon: Icon(Icons.attach_money_rounded, color: AppColors.textSecondary),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira o valor';
                    }
                    if (double.tryParse(value.replaceAll(',', '.')) == null) {
                      return 'Insira um valor numérico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Descrição
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    prefixIcon: Icon(Icons.description_rounded, color: AppColors.textSecondary),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira uma descrição';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Categoria
                TextFormField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Categoria (ex: Alimentação, Lazer)',
                    prefixIcon: Icon(Icons.category_rounded, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),

                // Seletor de Data
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('dd/MM/yyyy').format(_selectedDate),
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: _presentDatePicker,
                        child: const Text('Selecionar', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Botão de Enviar
                ElevatedButton(
                  onPressed: _submitData,
                  child: const Text('Salvar Transação'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
