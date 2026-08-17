import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../auth/services/auth_service.dart';
import '../../chat/models/user_model.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../../core/widgets/shimmer_loaders.dart';
import '../../settings/screens/settings_screen.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../../core/security/crypto_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = false;

  Future<void> _updateName(String newName) async {
    if (newName.trim().isEmpty || _currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateUserProfile(uid: _currentUser!.uid, displayName: newName.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم تحديث الاسم')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUsername(String newUsername) async {
    if (newUsername.trim().isEmpty || _currentUser == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateUserProfile(uid: _currentUser!.uid, username: newUsername.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم تحديث اسم المستخدم')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _updateBio(String newBio) async {
    if (_currentUser == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateUserProfile(uid: _currentUser!.uid, bio: newBio.trim());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم تحديث النبذة')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _updateProfileImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 70,
      );
      if (image != null && _currentUser != null) {
        setState(() => _isLoading = true);
        await ref
            .read(chatRepositoryProvider)
            .updateProfilePicture(_currentUser!.uid, File(image.path));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('تم تحديث الصورة')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('خطأ في تحميل الصورة: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getIdentityFingerprint(String? publicKey) {
    if (publicKey == null || publicKey.trim().isEmpty) return 'غير متاح';
    final canonicalKey = publicKey.replaceAll(RegExp(r'\s+'), '');
    var bytes = utf8.encode(canonicalKey);
    var digest = sha256.convert(bytes);
    var hex = digest.toString().toUpperCase().substring(0, 16);
    return '${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
  }

  ImageProvider? _getProfileImageProvider(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) return null;
    try {
      if (photoURL.startsWith('http')) return NetworkImage(photoURL);
      return MemoryImage(base64Decode(photoURL));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const ShimmerLoadingScreen(message: 'جاري تحميل الملف الشخصي...');
    }

    final asyncUser = ref.watch(userProfileProvider(uid));
    
    if (asyncUser.isLoading && _currentUser == null) {
      return const ShimmerLoadingScreen(message: 'جاري تحميل الملف الشخصي...');
    }

    if (asyncUser.hasValue) {
      _currentUser = asyncUser.value;
    }

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('خطأ في تحميل البيانات')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // Avatar Section
              Center(
                child: GestureDetector(
                  onTap: _updateProfileImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Hero(
                        tag: 'profile_pic_${_currentUser!.uid}',
                        child: CircleAvatar(
                          radius: 56, // Reduced from 70
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: _getProfileImageProvider(_currentUser!.photoURL),
                          child: _currentUser!.photoURL == null
                              ? Icon(Icons.person, size: 48, color: theme.iconTheme.color)
                              : null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Name
              Center(
                child: GestureDetector(
                  onTap: () => _showEditDialog('الاسم', _currentUser!.displayName, _updateName),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentUser!.displayName,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.edit, size: 16, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              Center(
                child: Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                ),
              ),

              const SizedBox(height: 40),

              // Info Section
              _buildSectionHeader('المعلومات الشخصية', theme),
              _buildListRow(
                icon: Icons.contacts_outlined,
                title: 'جهات الاتصال',
                subtitle: 'إدارة جهات الاتصال والمجموعات',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContactsScreen()),
                ),
                theme: theme,
              ),
              _buildListRow(
                icon: Icons.alternate_email,
                title: 'اسم المستخدم',
                subtitle: '@${_currentUser!.username ?? "غير محدد"}',
                onTap: () => _showEditDialog('اسم المستخدم', _currentUser!.username ?? '', _updateUsername),
                showEditIcon: true,
                theme: theme,
              ),
              _buildListRow(
                icon: Icons.info_outline,
                title: 'النبذة',
                subtitle: _currentUser!.bio?.isNotEmpty == true ? _currentUser!.bio! : 'رقمي، حسابي، هويتي.',
                onTap: () => _showEditDialog('النبذة', _currentUser!.bio ?? '', _updateBio, maxLines: 3),
                showEditIcon: true,
                theme: theme,
                showDivider: false,
              ),

              const SizedBox(height: 32),

              // Security Section
              _buildSectionHeader('الهوية والأمان', theme),
              _buildIdentityCard(theme),

              const SizedBox(height: 48),

              // Logout
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text(
                  'تسجيل الخروج',
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                ),
                onTap: _confirmLogout,
              ),
              
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'ID: ${_currentUser!.uid.substring(0, 8)}...',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildListRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
    bool showEditIcon = false,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Icon(icon, size: 22, color: theme.iconTheme.color),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showEditIcon)
                  Icon(Icons.edit, size: 16, color: theme.colorScheme.primary)
                else
                  Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(indent: 46, color: theme.dividerColor),
      ],
    );
  }

  Widget _buildIdentityCard(ThemeData theme) {
    return FutureBuilder<String?>(
      future: CryptoService().getPrivateKeyPem().then((_) => CryptoService().getPublicKeyPem()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final publicKey = snapshot.data;
        final fingerprint = _getIdentityFingerprint(publicKey);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.fingerprint, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('البصمة التعريفية', style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                fingerprint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: fingerprint));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('تم نسخ البصمة التعريفية')));
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('نسخ'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditDialog(String label, String initialValue, Function(String) onSave, {int maxLines = 1}) async {
    final controller = TextEditingController(text: initialValue);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل $label'),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSave(controller.text);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) Navigator.of(context).pop();
    }
  }
}
