import 'package:drift/drift.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../transactions/repository/transactions_repository.dart';

class GoogleDriveSyncService {
  final TransactionsRepository _repository;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '89878037656-n3r8p2ojgq4h5686muivurshcui77rv0.apps.googleusercontent.com',
    scopes: [
      drive.DriveApi.driveFileScope,
      sheets.SheetsApi.spreadsheetsScope,
    ],
  );

  GoogleDriveSyncService(this._repository);

  // Provedor para expor o estado do login
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  // Stream de alterações do usuário logado
  Stream<GoogleSignInAccount?> get onCurrentUserChanged => _googleSignIn.onCurrentUserChanged;

  // Realiza o login com o Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) return account;
      return await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('Erro ao realizar Google Sign-In: $e');
      rethrow;
    }
  }

  // Realiza o logout
  Future<void> signOut() async {
    await _googleSignIn.disconnect();
  }

  /// Sincroniza todas as transações locais para uma planilha do Google Sheets no Google Drive.
  Future<void> syncLocalDataToDrive() async {
    // 1. Garantir login
    var account = _googleSignIn.currentUser;
    account ??= await signIn();
    if (account == null) {
      throw Exception('Login do Google é necessário para sincronizar.');
    }

    // 2. Obter cliente HTTP autenticado
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Falha ao autenticar cliente HTTP do Google.');
    }

    final driveApi = drive.DriveApi(client);
    final sheetsApi = sheets.SheetsApi(client);

    // 3. Buscar ou criar a planilha no Drive
    final spreadsheetId = await _getOrCreateSpreadsheet(driveApi, sheetsApi);

    // 4. Buscar todas as transações do banco local
    final allTransactions = await _repository.getAllTransactions();

    // 5. Agrupar transações por mês/ano (ex: "Junho 2026")
    final Map<String, List<Transaction>> groupedTransactions = {};
    for (var tx in allTransactions) {
      groupedTransactions.putIfAbsent(tx.monthYear, () => []).add(tx);
    }

    // Ordenar os meses cronologicamente para criar as abas ordenadas
    final sortedMonths = groupedTransactions.keys.toList();
    
    // 6. Atualizar as abas da planilha
    for (var month in sortedMonths) {
      final txList = groupedTransactions[month]!;
      await _updateSheetForMonth(sheetsApi, spreadsheetId, month, txList);
    }
  }

  /// Busca a planilha no Google Drive e importa os dados para o banco local.
  /// Retorna o número de transações importadas.
  Future<int> syncDriveDataToLocal() async {
    // 1. Garantir login
    var account = _googleSignIn.currentUser;
    account ??= await signIn();
    if (account == null) {
      throw Exception('Login do Google é necessário para importar.');
    }

    // 2. Obter cliente HTTP autenticado
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Falha ao autenticar cliente HTTP do Google.');
    }

    final driveApi = drive.DriveApi(client);
    final sheetsApi = sheets.SheetsApi(client);

    // 3. Buscar todos os arquivos no Drive que contêm 'controle' e 'pessoal' (sem filtro de mimeType rígido para diagnóstico)
    final list = await driveApi.files.list(
      q: "name contains 'controle' and name contains 'pessoal' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name, mimeType)',
    );

    if (list.files == null || list.files!.isEmpty) {
      throw Exception('Nenhuma planilha com as palavras "controle" e "pessoal" foi encontrada no seu Google Drive.');
    }

    // Filtrar apenas planilhas nativas do Google Sheets
    final sheetsFiles = list.files!.where((f) => f.mimeType == 'application/vnd.google-apps.spreadsheet').toList();

    if (sheetsFiles.isEmpty) {
      // Encontrou arquivos, mas são apenas do tipo Excel (.xlsx)
      final excelNames = list.files!.map((f) => f.name).join(', ');
      throw Exception(
        'Planilha encontrada ($excelNames), mas está no formato Excel (.xlsx). '
        'Abra o arquivo no site do Google Drive e clique em: '
        'Arquivo > Salvar como Planilhas Google, depois tente novamente.'
      );
    }

    final spreadsheetId = sheetsFiles.first.id!;

    // 4. Obter informações das abas (sheets)
    final ssInfo = await sheetsApi.spreadsheets.get(spreadsheetId);
    final sheetsList = ssInfo.sheets ?? [];

    final List<TransactionsCompanion> transactionsToInsert = [];

    // 5. Ler dados de cada aba mensal
    for (var sheet in sheetsList) {
      final monthYear = sheet.properties?.title;
      if (monthYear == null) continue;

      // Ler o intervalo das transações (Colunas A a E, a partir da linha 2)
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        "'$monthYear'!A2:E1000",
      );

      final rows = response.values;
      if (rows == null || rows.isEmpty) continue;

      for (var row in rows) {
        // Ignorar linhas sem dados suficientes ou sem data
        if (row.length < 5 || row[0] == null || row[0].toString().trim().isEmpty) {
          continue;
        }

        try {
          final rawDate = row[0];
          final date = _parseDateString(rawDate.toString());
          if (date == null) continue;

          final descVal = row[1]?.toString() ?? 'Sem descrição';
          final catVal = row[2]?.toString() ?? 'Geral';
          final rawTipo = row[3]?.toString().trim() ?? 'Despesa';
          final type = _parseType(rawTipo);
          
          final rawValor = row[4];
          final amount = _parseAmount(rawValor);

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
          debugPrint('Erro ao parsear linha da aba $monthYear: $e');
        }
      }
    }

    if (transactionsToInsert.isNotEmpty) {
      await _repository.addTransactionsBatch(transactionsToInsert);
    }

    return transactionsToInsert.length;
  }

  /// Converte a string de data da planilha em DateTime
  DateTime? _parseDateString(String str) {
    final clean = str.trim();
    if (clean.isEmpty) return null;
    
    final parts = clean.split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        final fullYear = y < 100 ? 2000 + y : y;
        return DateTime(fullYear, m, d);
      }
    }
    return DateTime.tryParse(clean);
  }

  /// Padroniza o tipo da transação para 'Receita' ou 'Despesa'
  String _parseType(String raw) {
    final cleaned = raw.toLowerCase().trim();
    if (cleaned.contains('receita') || cleaned == 'r' || cleaned == 'entrada') {
      return 'Receita';
    }
    return 'Despesa';
  }

  /// Converte o valor bruto da planilha em double
  double _parseAmount(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    
    var str = raw.toString().trim();
    if (str.isEmpty) return 0.0;

    str = str.replaceAll('R\$', '').replaceAll(' ', '');
    if (str.contains(',') && str.contains('.')) {
      str = str.replaceAll('.', '').replaceAll(',', '.');
    } else if (str.contains(',')) {
      str = str.replaceAll(',', '.');
    }
    return double.tryParse(str) ?? 0.0;
  }

  /// Busca uma planilha chamada 'Controle Financeiro Pessoal' ou cria uma nova.
  Future<String> _getOrCreateSpreadsheet(drive.DriveApi driveApi, sheets.SheetsApi sheetsApi) async {
    final list = await driveApi.files.list(
      q: "name contains 'controle' and name contains 'pessoal' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    // Se não existir, cria uma nova
    final spreadsheet = sheets.Spreadsheet(
      properties: sheets.SpreadsheetProperties(
        title: 'Controle Financeiro Pessoal',
      ),
    );

    final created = await sheetsApi.spreadsheets.create(spreadsheet);
    return created.spreadsheetId!;
  }

  /// Cria ou atualiza uma aba mensal com as transações e a área de resumos com fórmulas do Sheets.
  Future<void> _updateSheetForMonth(
    sheets.SheetsApi sheetsApi,
    String spreadsheetId,
    String monthYear,
    List<Transaction> transactions,
  ) async {
    // 1. Obter informações das abas atuais para ver se a aba do mês já existe
    final ssInfo = await sheetsApi.spreadsheets.get(spreadsheetId);
    final sheetsList = ssInfo.sheets ?? [];
    
    sheets.Sheet? targetSheet;
    for (var s in sheetsList) {
      if (s.properties?.title == monthYear) {
        targetSheet = s;
        break;
      }
    }

    if (targetSheet == null) {
      // Criar nova aba se não existir
      final addSheetRequest = sheets.Request(
        addSheet: sheets.AddSheetRequest(
          properties: sheets.SheetProperties(
            title: monthYear,
          ),
        ),
      );

      await sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: [addSheetRequest]),
        spreadsheetId,
      );
    }

    // 2. Limpar a aba antes de escrever os novos dados
    await sheetsApi.spreadsheets.values.clear(
      sheets.ClearValuesRequest(),
      spreadsheetId,
      "'$monthYear'!A1:J1000",
    );

    // 3. Montar a matriz de dados para escrever (Colunas A a E para transações, Coluna G em diante para Resumos)
    final List<List<Object>> rowsData = [];
    
    // Cabeçalho da tabela de transações
    rowsData.add([
      'Data',
      'Descrição',
      'Categoria',
      'Tipo (Receita/Despesa)',
      'Valor (R\$)',
      '', // Coluna F vazia de separação
      'Resumo',
    ]);

    // Ordenar as transações do mês por data decrescente ou crescente
    transactions.sort((a, b) => a.date.compareTo(b.date));

    final df = DateFormat('dd/MM/yyyy');

    // Preencher as linhas. Lembre-se: O Sheets aceita fórmulas no formato de String começadas por '='.
    // Montamos o resumo à direita nas primeiras linhas.
    for (int i = 0; i < transactions.length; i++) {
      final tx = transactions[i];
      final List<Object> row = [
        df.format(tx.date),
        tx.description,
        tx.category,
        tx.type,
        tx.amount,
      ];

      // Adicionar a estrutura de resumo à direita na planilha nas linhas específicas
      // Linha 2 (índice 1 no grid do Sheets, ou seja, linha correspondente à primeira transação)
      if (i == 0) {
        row.addAll(['', 'Total Receitas:', '=SUMIF(D2:D1000; "Receita"; E2:E1000)']);
      } else if (i == 1) {
        row.addAll(['', 'Total Despesas:', '=SUMIF(D2:D1000; "Despesa"; E2:E1000)']);
      } else if (i == 2) {
        row.addAll(['', 'Saldo:', '=H2-H3']); // Total Receitas - Total Despesas
      } else if (i == 7) {
        row.addAll(['', 'Investimentos:', '=SUMIF(C2:C1000; "Investimento"; E2:E1000)']);
      } else if (i == 11) {
        row.addAll(['', 'Saldo Total:', '=H4-H8']); // Saldo - Investimentos
      }

      rowsData.add(row);
    }

    // Se houver poucas transações, garante que a tabela de resumos ainda seja escrita por completo
    if (transactions.length < 12) {
      for (int i = transactions.length; i < 12; i++) {
        final List<Object> row = ['', '', '', '', '']; // Linhas vazias na tabela de transações
        if (i == 0) {
          row.addAll(['', 'Total Receitas:', '=SUMIF(D2:D1000; "Receita"; E2:E1000)']);
        } else if (i == 1) {
          row.addAll(['', 'Total Despesas:', '=SUMIF(D2:D1000; "Despesa"; E2:E1000)']);
        } else if (i == 2) {
          row.addAll(['', 'Saldo:', '=H2-H3']);
        } else if (i == 7) {
          row.addAll(['', 'Investimentos:', '=SUMIF(C2:C1000; "Investimento"; E2:E1000)']);
        } else if (i == 11) {
          row.addAll(['', 'Saldo Total:', '=H4-H8']);
        }
        rowsData.add(row);
      }
    }

    // 4. Enviar os dados para o Google Sheets
    final valueRange = sheets.ValueRange(
      values: rowsData,
      majorDimension: 'ROWS',
    );

    await sheetsApi.spreadsheets.values.update(
      valueRange,
      spreadsheetId,
      "'$monthYear'!A1",
      valueInputOption: 'USER_ENTERED', // Permite que fórmulas começadas com '=' funcionem
    );

    // 5. Aplicar formatação visual (opcional, mas garante um visual limpo se quisermos formatar as colunas)
    // Para simplificar e garantir estabilidade de cota, as fórmulas de USER_ENTERED já cuidam dos valores.
  }
}

final googleDriveSyncServiceProvider = Provider<GoogleDriveSyncService>((ref) {
  final repository = ref.watch(transactionsRepositoryProvider);
  return GoogleDriveSyncService(repository);
});
