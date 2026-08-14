import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import '../repositories/contact_repository.dart';
import '../../chat/models/user_model.dart';

class EditContactScreen extends ConsumerStatefulWidget {
  final Contact? contact; // If editing existing
  final UserModel? userToAdd; // If adding new

  const EditContactScreen({super.key, this.contact, this.userToAdd});

  @override
  ConsumerState<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends ConsumerState<EditContactScreen> {
  final _aliasController = TextEditingController();
  final _groupController = TextEditingController();

  late UserModel _targetUser;

  @override
  void initState() {
    super.initState();
    if (widget.contact != null) {
      _targetUser = widget.contact!.user;
      _aliasController.text = widget.contact!.alias ?? '';
      _groupController.text = widget.contact!.group ?? '';
    } else {
      _targetUser = widget.userToAdd!;
      _aliasController.text =
          _targetUser.displayName; // Default to display name
    }
  }

  Future<void> _save() async {
    final alias = _aliasController.text.trim().isEmpty
        ? null
        : _aliasController.text.trim();
    final group = _groupController.text.trim().isEmpty
        ? null
        : _groupController.text.trim();

    try {
      if (widget.contact != null) {
        // Update existing
        await ref
            .read(contactRepositoryProvider)
            .updateContact(_targetUser.uid, alias: alias, group: group);
      } else {
        // Add new
        await ref
            .read(contactRepositoryProvider)
            .addContact(_targetUser.uid, alias: alias, group: group);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.contact != null ? 'تعديل جهة الاتصال' : 'حفظ جهة الاتصال',
        ),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('حفظ'),
            style: TextButton.styleFrom(
              foregroundColor: theme.primaryColor,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Profile Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _getImageProvider(_targetUser.photoURL),
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    child: _targetUser.photoURL == null
                        ? Text(
                            _targetUser.displayName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _targetUser.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_targetUser.username != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '@${_targetUser.username}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'الاسم الأصلي: ${_targetUser.displayName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(),

            const SizedBox(height: 32),

            // Form Fields
            TextField(
              controller: _aliasController,
              decoration: InputDecoration(
                labelText: 'الاسم المخصص (Alias)',
                helperText: 'اسم يظهر لك فقط بدلاً من الاسم الأصلي',
                prefixIcon: const Icon(Icons.edit),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.cardColor,
              ),
            ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1),
            const SizedBox(height: 20),
            TextField(
              controller: _groupController,
              decoration: InputDecoration(
                labelText: 'المجموعة (اختياري)',
                helperText: 'مثال: العائلة، العمل، الأصدقاء',
                prefixIcon: const Icon(Icons.group_work),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.cardColor,
              ),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1),

            const SizedBox(height: 32),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.primaryColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الاسم المخصص والمجموعة محفوظة محلياً على جهازك فقط',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  ImageProvider? _getImageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      if (url.startsWith('http')) {
        return NetworkImage(url);
      } else {
        return MemoryImage(base64Decode(url));
      }
    } catch (e) {
      return null;
    }
  }
}
