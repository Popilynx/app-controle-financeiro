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
    // Ordenação simples (idealmente converteríamos para data para ordenar de fato, mas para simplificar mantemos a ordem de cadastro)
    
    // 6. Atualizar as abas da planilha
    for (var month in sortedMonths) {
      final txList = groupedTransactions[month]!;
      await _updateSheetForMonth(sheetsApi, spreadsheetId, month, txList);
    }
  }

  /// Busca uma planilha chamada 'Controle Financeiro Pessoal' ou cria uma nova.
  Future<String> _getOrCreateSpreadsheet(drive.DriveApi driveApi, sheets.SheetsApi sheetsApi) async {
    final list = await driveApi.files.list(
      q: "name = 'Controle Financeiro Pessoal' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
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
