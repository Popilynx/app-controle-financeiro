import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class UpdateService {
  /// Verifica se há uma nova versão disponível no GitHub.
  /// [showNoUpdateInfo] determina se exibe um SnackBar caso esteja na última versão (útil para checagem manual).
  static Future<void> checkForUpdate(BuildContext context, {bool showNoUpdateInfo = false}) async {
    try {
      // 1. Obter a versão instalada no app
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Consultar a última release no GitHub API
      final url = Uri.parse(
        'https://api.github.com/repos/${AppConstants.githubUser}/${AppConstants.githubRepo}/releases/latest',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        if (showNoUpdateInfo && context.mounted) {
          _showSnackBar(context, 'Não foi possível verificar atualizações no momento.', isError: true);
        }
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['tag_name'] as String? ?? '';
      final releaseNotes = data['body'] as String? ?? 'Nenhuma nota de versão fornecida.';
      final assets = data['assets'] as List<dynamic>? ?? [];

      if (latestVersion.isEmpty) return;

      // 3. Comparar as versões
      final hasUpdate = isNewerVersion(currentVersion, latestVersion);

      if (hasUpdate && context.mounted) {
        // Encontrar a URL de download do APK nos assets da release
        String downloadUrl = '';
        for (var asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'] as String? ?? '';
            break;
          }
        }

        // Se não encontrar o APK diretamente nos assets, usa a URL da release no navegador como fallback
        if (downloadUrl.isEmpty) {
          downloadUrl = data['html_url'] as String? ?? '';
        }

        _showUpdateDialog(context, latestVersion, currentVersion, releaseNotes, downloadUrl);
      } else {
        if (showNoUpdateInfo && context.mounted) {
          _showSnackBar(context, 'Você já está utilizando a última versão disponível ($currentVersion).');
        }
      }
    } catch (e) {
      if (showNoUpdateInfo && context.mounted) {
        _showSnackBar(context, 'Erro ao verificar atualizações: $e', isError: true);
      }
    }
  }

  /// Compara se a versão do GitHub é mais recente que a versão atual do app (SemVer X.Y.Z)
  static bool isNewerVersion(String current, String latest) {
    final cleanCurrent = current.replaceAll('v', '').trim();
    final cleanLatest = latest.replaceAll('v', '').trim();

    final currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (currentParts.length < 3) {
      currentParts.add(0);
    }
    while (latestParts.length < 3) {
      latestParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Exibe um diálogo modal elegante informando da atualização disponível
  static void _showUpdateDialog(
    BuildContext context,
    String latestVersion,
    String currentVersion,
    String releaseNotes,
    String downloadUrl,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder, width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.system_update_rounded, color: AppColors.accent, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nova Versão Disponível!',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Versão $latestVersion (Atual: $currentVersion)',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Novidades desta versão:',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder, width: 0.5),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        releaseNotes,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Mais Tarde', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final uri = Uri.parse(downloadUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Atualizar Agora', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.expense : AppColors.income,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
