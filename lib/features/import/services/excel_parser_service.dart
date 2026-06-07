import 'dart:io';
import 'package:drift/drift.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../transactions/repository/transactions_repository.dart';

class ExcelParserService {
  final TransactionsRepository _repository;
  ExcelParserService(this._repository);

  /// Lê o arquivo Excel e salva as transações no banco de dados local.
  /// Retorna o número de transações importadas com sucesso.
  Future<int> parseAndSaveExcel(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Arquivo Excel não encontrado no caminho especificado.');
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    
    final List<TransactionsCompanion> transactionsToInsert = [];

    // Iterar por todas as abas (ex: "Junho 2026")
    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      if (sheet.maxRows <= 1) continue;

      // Identificar os índices das colunas de cabeçalho
      int colData = -1;
      int colDesc = -1;
      int colCat = -1;
      int colTipo = -1;
      int colValor = -1;

      // Ler a primeira linha (cabeçalho) para mapear os índices
      final headerRow = sheet.rows.first;
      for (int i = 0; i < headerRow.length; i++) {
        final cellVal = headerRow[i]?.value?.toString().toLowerCase().trim() ?? '';
        if (cellVal.contains('data')) colData = i;
        if (cellVal.contains('descri')) colDesc = i;
        if (cellVal.contains('categor')) colCat = i;
        if (cellVal.contains('tipo')) colTipo = i;
        if (cellVal.contains('valor')) colValor = i;
      }

      // Fallback caso o cabeçalho não bata exatamente, assume colunas A=0, B=1, C=2, D=3, E=4
      if (colData == -1) colData = 0;
      if (colDesc == -1) colDesc = 1;
      if (colCat == -1) colCat = 2;
      if (colTipo == -1) colTipo = 3;
      if (colValor == -1) colValor = 4;

      // Iterar sobre as linhas de dados (a partir da linha 2)
      for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
        final row = sheet.rows[rowIndex];
        
        // Se a linha estiver vazia ou for muito curta, ignora
        if (row.length <= colData || row[colData] == null || row[colData]?.value == null) {
          continue;
        }

        try {
          final rawDate = row[colData]?.value;
          final date = _parseExcelDate(rawDate);
          
          final descVal = row[colDesc]?.value?.toString() ?? 'Sem descrição';
          final catVal = row[colCat]?.value?.toString() ?? 'Geral';
          
          final rawTipo = row[colTipo]?.value?.toString().trim() ?? 'Despesa';
          final type = _parseType(rawTipo);
          
          final rawValor = row[colValor]?.value;
          final double amount = _parseAmount(rawValor);

          if (date == null) continue; // Data é obrigatória

          // Criar nome do mês formatado (ex: "Junho 2026") com base na data da transação ou no nome da aba
          final monthYear = _getMonthYearString(date);

          transactionsToInsert.add(
            TransactionsCompanion(
              date: Value(date),
              description: Value(descVal),
              category: Value(catVal),
              type: Value(type),
              amount: Value(amount),
              monthYear: Value(monthYear),
            ),
          );
        } catch (e) {
          // Log ou ignora linha corrompida
          debugPrint('Erro ao parsear linha $rowIndex da aba $table: $e');
        }
      }
    }

    if (transactionsToInsert.isNotEmpty) {
      await _repository.addTransactionsBatch(transactionsToInsert);
    }

    return transactionsToInsert.length;
  }

  /// Converte o valor bruto da célula de data em DateTime
  DateTime? _parseExcelDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    
    // Tratamento de string
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    // Se for formato de data com barra (DD/MM/AAAA)
    final barParts = str.split('/');
    if (barParts.length == 3) {
      final d = int.tryParse(barParts[0]);
      final m = int.tryParse(barParts[1]);
      final y = int.tryParse(barParts[2]);
      if (d != null && m != null && y != null) {
        // Correção simples se o ano vier abreviado (26 -> 2026)
        final fullYear = y < 100 ? 2000 + y : y;
        return DateTime(fullYear, m, d);
      }
    }

    // Se for formato de data com hífen (AAAA-MM-DD ou DD-MM-AAAA)
    final dashParts = str.split('-');
    if (dashParts.length == 3) {
      if (dashParts[0].length == 4) { // AAAA-MM-DD
        final y = int.tryParse(dashParts[0]);
        final m = int.tryParse(dashParts[1]);
        final d = int.tryParse(dashParts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      } else { // DD-MM-AAAA
        final d = int.tryParse(dashParts[0]);
        final m = int.tryParse(dashParts[1]);
        final y = int.tryParse(dashParts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      }
    }

    // Tentar conversão direta numérica (data serial do Excel)
    final numVal = num.tryParse(str);
    if (numVal != null) {
      // Excel serial date para DateTime
      // 25569 é o deslocamento de dias para a época Unix (1970-01-01)
      final date = DateTime.fromMillisecondsSinceEpoch(
        ((numVal - 25569) * 86400 * 1000).round(),
        isUtc: true,
      );
      return date;
    }

    return DateTime.tryParse(str);
  }

  /// Padroniza o tipo da transação para 'Receita' ou 'Despesa'
  String _parseType(String raw) {
    final cleaned = raw.toLowerCase().trim();
    if (cleaned.contains('receita') || cleaned == 'r' || cleaned == 'entrada') {
      return 'Receita';
    }
    return 'Despesa';
  }

  /// Converte valor bruto do Excel em double
  double _parseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    
    // Tratamento de string
    var str = raw.toString().trim();
    if (str.isEmpty) return 0.0;

    // Remover cifrões e espaços
    str = str.replaceAll('R\$', '').replaceAll(' ', '');
    // Se usar vírgula como decimal (padrão brasileiro), inverte pontos e vírgulas
    if (str.contains(',') && str.contains('.')) {
      str = str.replaceAll('.', '').replaceAll(',', '.');
    } else if (str.contains(',')) {
      str = str.replaceAll(',', '.');
    }

    return double.tryParse(str) ?? 0.0;
  }

  /// Retorna o nome do mês em português formatado (ex: "Junho 2026")
  String _getMonthYearString(DateTime date) {
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

final excelParserServiceProvider = Provider<ExcelParserService>((ref) {
  final repository = ref.watch(transactionsRepositoryProvider);
  return ExcelParserService(repository);
});
