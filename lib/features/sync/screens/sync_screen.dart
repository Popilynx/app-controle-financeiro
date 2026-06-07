import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/theme/app_theme.dart';
import '../services/google_drive_sync_service.dart';
import '../services/update_service.dart';
import '../../import/services/excel_parser_service.dart';
import '../../dashboard/screens/dashboard_screen.dart';

// Provedor que observa o estado do usuário do Google
final googleUserStreamProvider = StreamProvider<GoogleSignInAccount?>((ref) {
  final syncService = ref.watch(googleDriveSyncServiceProvider);
  return syncService.onCurrentUserChanged;
});

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _isSyncing = false;
  bool _isDownloading = false;
  bool _isImporting = false;

  // Realiza a sincronização do banco local para o Drive
  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    try {
      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.syncLocalDataToDrive();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sincronização com o Google Drive concluída! Planilha atualizada.'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha na sincronização: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // Realiza a importação da planilha do Drive para o banco local
  Future<void> _handleDownloadFromDrive() async {
    setState(() => _isDownloading = true);
    try {
      final syncService = ref.read(googleDriveSyncServiceProvider);
      final count = await syncService.syncDriveDataToLocal();
      
      // Invalidar dashboard e provedores de lista para forçar o recarregamento dos dados na tela
      ref.invalidate(dashboardTransactionsProvider);
      ref.invalidate(availableMonthsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importação concluída! $count transações importadas da nuvem com sucesso.'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao importar da nuvem: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  // Realiza a importação da planilha Excel local
  Future<void> _handleImportExcel() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.single.path == null) {
        // Seleção cancelada
        setState(() => _isImporting = false);
        return;
      }

      final filePath = result.files.single.path!;
      final parserService = ref.read(excelParserServiceProvider);
      
      final count = await parserService.parseAndSaveExcel(filePath);

      // Invalidar dashboard para forçar refresh nos dados
      ref.invalidate(dashboardTransactionsProvider);
      ref.invalidate(availableMonthsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importação concluída! $count transações importadas com sucesso.'),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao importar planilha: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // Login com o Google
  Future<void> _handleSignIn() async {
    try {
      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.signIn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de login: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Logout com o Google
  Future<void> _handleSignOut() async {
    try {
      final syncService = ref.read(googleDriveSyncServiceProvider);
      await syncService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logout realizado com sucesso.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao desconectar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleUserAsync = ref.watch(googleUserStreamProvider);
    final currentUser = googleUserAsync.value;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              const Text(
                'Sincronização & Backup',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                'Nuvem & Excel',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),

              // Seção do Google Drive
              const Text(
                'Backup Google Drive',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              _buildGoogleDriveCard(currentUser),
              
              const SizedBox(height: 32),

              // Seção de Importação
              const Text(
                'Importação Local',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              _buildImportCard(),
              
              const SizedBox(height: 32),

              // Seção de Atualização
              const Text(
                'Atualizações do Sistema',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _buildUpdateCard(),

              const SizedBox(height: 32),

              // Bloco Informativo de Automação Diária
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleDriveCard(GoogleSignInAccount? user) {
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.glassBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: AppColors.textSecondary, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sem sincronização ativa',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Conecte sua conta do Google para atualizar sua planilha no Google Drive diariamente.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _handleSignIn,
              icon: const Icon(Icons.login_rounded, size: 20),
              label: const Text('Conectar Conta Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(user.displayName?.substring(0, 1).toUpperCase() ?? 'G', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? 'Conta Google',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_isSyncing || _isDownloading)
            Column(
              children: [
                const LinearProgressIndicator(color: AppColors.accent, backgroundColor: AppColors.surfaceElevated),
                const SizedBox(height: 12),
                Text(
                  _isSyncing 
                      ? 'Enviando transações locais para o Google Sheets...'
                      : 'Baixando transações da planilha do Google Sheets...',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleSync,
                        icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                        label: const Text('Enviar p/ Nuvem'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handleDownloadFromDrive,
                        icon: const Icon(Icons.cloud_download_rounded, size: 20),
                        label: const Text('Puxar da Nuvem'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Desconectar Conta Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppColors.expense,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    side: const BorderSide(color: AppColors.expense, width: 0.8),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildImportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.table_view_rounded, color: AppColors.accent, size: 28),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Importar do Excel (.xlsx)',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Carregue sua planilha local de controle financeiro para ler todas as receitas e despesas automaticamente.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (_isImporting)
            const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Processando dados do Excel...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: _handleImportExcel,
              icon: const Icon(Icons.file_upload_outlined, size: 20),
              label: const Text('Selecionar Planilha Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'A sincronização diária roda automaticamente em segundo plano, atualizando o arquivo no Google Drive uma vez por dia quando houver conexão Wi-Fi.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.glassBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.system_update_rounded, color: AppColors.accent, size: 28),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Atualizações do App',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Verifique se há novas versões do aplicativo de controle financeiro disponíveis no GitHub.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => UpdateService.checkForUpdate(context, showNoUpdateInfo: true),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Verificar Atualizações'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.glassBorder, width: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
