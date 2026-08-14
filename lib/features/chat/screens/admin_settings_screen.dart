import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/chat_repository.dart';
import '../models/chat_room.dart';
import 'group_requests_screen.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  final ChatRoom room;

  const AdminSettingsScreen({super.key, required this.room});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  late TextEditingController _handleController;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _handleController = TextEditingController(text: widget.room.groupHandle);
  }

  @override
  void dispose() {
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _saveHandle(String roomId, String currentHandle) async {
    final handle = _handleController.text.trim();
    if (handle == currentHandle) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref.read(chatRepositoryProvider).setGroupHandle(roomId, handle);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث معرف المجموعة بنجاح')),
      );
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePublic(
    String roomId,
    bool currentVal,
    bool newVal,
  ) async {
    // Show confirmation if creating public group
    if (newVal && !currentVal) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تحويل إلى مجموعة عامة؟'),
          content: const Text(
            'ستكون المجموعة مرئية في البحث ويمكن لأي شخص الانضمام إليها.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (confirm != true) return; // User cancelled switch
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .updateGroupInfo(roomId, isPublic: newVal);
      // StreamBuilder will rebuild UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _deleteGroup(String roomId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المجموعة نهائياً؟'),
        content: const Text(
          'سيتم حذف المجموعة وجميع الرسائل لجميع الأعضاء. لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'حذف نهائي',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(chatRepositoryProvider).deleteGroupForEveryone(roomId);
      if (mounted) {
        Navigator.of(context).pop(); // Close settings
        Navigator.of(context).pop(); // Close chat
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // WATCH for real-time updates
    final chatsStream = ref.watch(chatRepositoryProvider).getUserChats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات المجموعة'),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<List<ChatRoom>>(
        stream: chatsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Find our room in the updated list
          ChatRoom? currentRoom;
          try {
            currentRoom = snapshot.data!.firstWhere(
              (r) => r.id == widget.room.id,
            );
          } catch (_) {
            return const Center(child: Text('المجموعة غير موجودة'));
          }
          final room = currentRoom;
          if (room == null) {
            return const Center(child: Text('المجموعة غير موجودة'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Group Identity (Centered & Clean)
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.groups,
                        size: 40,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Handle Editor
                    Container(
                      width: 250,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _handleController,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          errorText: _errorText,
                          hintText: 'معرف المجموعة',
                          prefixText: '@',
                          border: InputBorder.none,
                          suffixIcon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    Icons.check_circle_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  color: Theme.of(context).colorScheme.primary,
                                  onPressed: () => _saveHandle(
                                    room.id,
                                    room.groupHandle ?? '',
                                  ),
                                ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-z0-9_]'),
                          ),
                          LengthLimitingTextInputFormatter(20),
                        ],
                      ),
                    ),
                    if (room.groupHandle != null)
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: '@${room.groupHandle}'),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ المعرف')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('نسخ المعرف'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).disabledColor,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 2. Permissions Section
              _buildSectionHeader(context, 'الأذونات والخصوصية'),
              Card(
                elevation: 0,
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.3),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('مجموعة عامة'),
                      subtitle: const Text('يمكن للجميع العثور على المجموعة'),
                      value: room.isPublic,
                      onChanged: (val) =>
                          _togglePublic(room.id, room.isPublic, val),
                      secondary: const Icon(Icons.public),
                    ),

                    SwitchListTile(
                      title: const Text('النشر للمشرفين فقط'),
                      subtitle: const Text('تقييد إرسال الرسائل على الأعضاء'),
                      value: room.onlyAdminsCanPost,
                      onChanged: (val) async {
                        await ref
                            .read(chatRepositoryProvider)
                            .updateGroupInfo(room.id, onlyAdminsCanPost: val);
                        // StreamBuilder rebuilds UI automatically
                      },
                      secondary: const Icon(Icons.lock_outline),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Requests
              _buildSectionHeader(context, 'الأعضاء'),
              Card(
                child: ListTile(
                  leading: Badge(
                    label: Text('${room.pendingRequests.length}'),
                    isLabelVisible: room.pendingRequests.isNotEmpty,
                    child: Icon(
                      Icons.person_add_alt_1,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  ),
                  title: const Text('طلبات الانضمام'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupRequestsScreen(
                          roomId: room.id,
                          pendingRequests: room.pendingRequests,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              // 4. Danger Zone
              _buildSectionHeader(
                context,
                'منطقة الخطر',
                color: Theme.of(context).colorScheme.error,
              ),
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.errorContainer.withOpacity(0.1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.delete_forever,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'حذف المجموعة نهائياً',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text('سيتم حذف المجموعة لجميع المشاركين'),
                  onTap: () => _deleteGroup(room.id),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        title,
        style: TextStyle(
          color: color ?? Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
