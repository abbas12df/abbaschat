import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import '../../../../core/local/local_storage_service.dart';
import '../services/settings_service.dart';

class StorageSettingsScreen extends ConsumerStatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  ConsumerState<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends ConsumerState<StorageSettingsScreen> {
  bool _isLoading = true;
  String _storageUsed = "0 B";
  String _mediaUsed = "0 B";
  String _textUsed = "0 B";
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();
    _calculateStorage();
  }

  Future<void> _calculateStorage() async {
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _storageUsed = "0 B";
          _mediaUsed = "0 B";
          _textUsed = "0 B";
        });
        return;
      }

      final settings = ref.read(settingsServiceProvider);
      await settings.init();
      
      final usage = await settings.calculateStorageUsage(user.uid);
      
      final totalBytes = usage['total'] ?? 0;
      final mediaBytes = usage['media'] ?? 0;
      final textBytes = usage['text'] ?? 0;

      setState(() {
        _storageUsed = _formatBytes(totalBytes);
        _mediaUsed = _formatBytes(mediaBytes);
        _textUsed = _formatBytes(textBytes);
        // Estimate progress (assuming 1GB max for demo)
        _progressValue = (totalBytes / (1024 * 1024 * 1024)).clamp(0.0, 1.0);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _storageUsed = "خطأ في الحساب";
        _mediaUsed = "0 B";
        _textUsed = "0 B";
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _exportConversations(BuildContext context, WidgetRef ref) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      final localStorage = ref.read(localStorageServiceProvider);
      final conversations = await localStorage.getAllConversations(user.uid);

      final exportData = <String, dynamic>{
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'userId': user.uid,
        'conversations': <Map<String, dynamic>>[],
      };

      for (final conv in conversations) {
        final chatId = conv['id'] as String? ?? '';
        if (chatId.isEmpty) continue;

        final messages = await localStorage.getMessages(user.uid, chatId);
        exportData['conversations']!.add({
          'id': chatId,
          'name': conv['name'] ?? conv['groupId'] ?? 'محادثة',
          'messages': messages,
        });
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      if (context.mounted) {
        Navigator.pop(context); // Close loading

        // Share the export
        await Share.share(
          jsonString,
          subject: 'نسخة احتياطية من المحادثات',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصدير المحادثات بنجاح ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التصدير: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('التخزين والبيانات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Storage Graph (Visual)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'المساحة المستخدمة',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 8),
                _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _storageUsed,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _progressValue,
                  backgroundColor: Theme.of(
                    context,
                  ).disabledColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'وسائط: $_mediaUsed',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      'نصوص: $_textUsed',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                if (!_isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('تحديث'),
                      onPressed: _calculateStorage,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: const Text('مسح جميع الرسائل'),
            subtitle: const Text('سيتم حذف السجل المحلي فقط'),
            onTap: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يجب تسجيل الدخول أولاً')),
                );
                return;
              }

              // Show confirmation dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تأكيد الحذف'),
                  content: const Text(
                    'هل أنت متأكد من حذف جميع الرسائل المحلية؟\nهذا الإجراء لا يمكن التراجع عنه.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  final localStorage = ref.read(localStorageServiceProvider);
                  await localStorage.clearAllMessages(user.uid);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم حذف جميع الرسائل بنجاح ✅'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ في الحذف: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('تصدير المحادثات'),
            subtitle: const Text('حفظ نسخة احتياطية من رسائلك'),
            onTap: () => _exportConversations(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('مسح الملفات المؤقتة'),
            subtitle: const Text('تحرير مساحة التخزين من الملفات المؤقتة'),
            onTap: () async {
              try {
                int totalFreed = 0;
                final tempDir = await getTemporaryDirectory();
                if (await tempDir.exists()) {
                  final entities = tempDir.listSync(recursive: true);
                  for (final entity in entities) {
                    if (entity is File) {
                      try {
                        final len = await entity.length();
                        await entity.delete();
                        totalFreed += len;
                      } catch (_) {
                        // Skip if file locked
                      }
                    }
                  }
                }

                if (context.mounted) {
                  final freedText = _formatBytes(totalFreed);
                  final msg = totalFreed > 0
                      ? 'تم تحرير $freedText من الملفات المؤقتة بنجاح ✅'
                      : 'لا توجد ملفات مؤقتة للمسح حالياً ✅';

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _calculateStorage();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ أثناء مسح الكاش: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_sweep,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'حذف المحادثات القديمة',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            subtitle: const Text('حذف المحادثات الأقدم من 30 يوماً'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف المحادثات القديمة؟'),
                  content: const Text(
                    'سيتم حذف جميع المحادثات الأقدم من 30 يوماً.\nهذا الإجراء لا يمكن التراجع عنه.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('إلغاء'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );

                  final localStorage = ref.read(localStorageServiceProvider);
                  final conversations =
                      await localStorage.getAllConversations(user.uid);

                  final now = DateTime.now();
                  int deletedCount = 0;

                  for (final conv in conversations) {
                    final lastMessageTime = conv['lastMessageTime'] as int?;
                    if (lastMessageTime != null) {
                      final lastMessageDate =
                          DateTime.fromMillisecondsSinceEpoch(lastMessageTime);
                      final daysDiff = now.difference(lastMessageDate).inDays;

                      if (daysDiff > 30) {
                        await localStorage.deleteConversation(
                          user.uid,
                          conv['id'] as String,
                        );
                        deletedCount++;
                      }
                    }
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          deletedCount > 0
                              ? 'تم حذف $deletedCount محادثة قديمة ✅'
                              : 'لا توجد محادثات قديمة للحذف',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _calculateStorage();
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ في الحذف: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
