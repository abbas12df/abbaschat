import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart'; // For fingerprinting
import '../../auth/services/auth_service.dart';
import '../../chat/models/user_model.dart';
import '../../chat/repositories/chat_repository.dart';
import '../../../core/widgets/shimmer_loaders.dart';
import '../../settings/screens/settings_screen.dart';
import '../../contacts/screens/contacts_screen.dart'; // Added
// Removed unused imports

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _updateName(String newName) async {
    if (newName.trim().isEmpty || _currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateUserProfile(
            uid: _currentUser!.uid,
            displayName: newName.trim(),
          );

      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث الاسم')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateUsername(String newUsername) async {
    if (newUsername.trim().isEmpty || _currentUser == null) return;
    // Basic validation could be added here
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateUserProfile(
            uid: _currentUser!.uid,
            username: newUsername.trim(),
          );

      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث اسم المستخدم')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _updateBio(String newBio) async {
    if (_currentUser == null) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .updateUserProfile(uid: _currentUser!.uid, bio: newBio.trim());

      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث النبذة')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
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

        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم تحديث الصورة')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل الصورة: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Privacy Updates ---

  // --- Privacy Updates Removed (Migrated to PrivacySettingsScreen) ---

  String _getIdentityFingerprint(String uid) {
    // Generate a visual "Safety Number" from UID
    var bytes = utf8.encode(uid);
    var digest = sha256.convert(bytes);
    var hex = digest.toString().toUpperCase().substring(
      0,
      16,
    ); // First 16 chars
    // Format as XXXX-XXXX-XXXX-XXXX
    return '${hex.substring(0, 4)}-${hex.substring(4, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const ShimmerLoadingScreen(message: 'جاري تحميل الملف الشخصي...');
    }

    return Builder(
      builder: (context) {
        final asyncUser = ref.watch(userProfileProvider(uid));

        if (asyncUser.isLoading && _currentUser == null) {
          return const ShimmerLoadingScreen(
            message: 'جاري تحميل الملف الشخصي...',
          );
        }

        if (asyncUser.hasValue) {
          _currentUser = asyncUser.value;
        }

        if (_currentUser == null) {
          return const Scaffold(
            body: Center(child: Text("خطأ في تحميل البيانات")),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: CustomScrollView(
            slivers: [
              // 1. Sliver App Bar with Hero Profile Image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Loading Overlay
                      if (_isLoading) const LinearProgressIndicator(),
                      // Blurred Background or Gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.primaryColor.withOpacity(0.1),
                              theme.scaffoldBackgroundColor,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Center(
                        child: GestureDetector(
                          onTap: () => _updateProfileImage(), // Tap to edit
                          child: Hero(
                            tag: 'profile_pic_${_currentUser!.uid}',
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.primaryColor,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 70,
                                backgroundImage: _getProfileImageProvider(
                                  _currentUser!.photoURL,
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceVariant,
                                child: _currentUser!.photoURL == null
                                    ? Icon(
                                        Icons.person,
                                        size: 70,
                                        color:
                                            Theme.of(context).iconTheme.color ??
                                            Colors.grey,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ).animate().scale(
                        curve: Curves.easeOutBack,
                        duration: 600.ms,
                      ),

                      // Edit Icon Overlay
                      Positioned(
                        bottom: 60,
                        right: MediaQuery.of(context).size.width / 2 - 70,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.cardColor,
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              size: 18,
                              color: theme.primaryColor,
                            ),
                            onPressed: _updateProfileImage,
                            padding: EdgeInsets.zero,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // 2. Info Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Name (Editable)
                      GestureDetector(
                        onTap: () => _showEditDialog(
                          context,
                          'الاسم',
                          _currentUser!.displayName,
                          _updateName,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentUser!.displayName,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.edit,
                              size: 16,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white70
                                  : theme.iconTheme.color,
                            ),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: 0.5, end: 0),

                      const SizedBox(height: 32),

                      // --- Info Section ---
                      _buildSectionHeader('المعلومات الشخصية'),
                      _buildProfileOption(
                        context,
                        icon: Icons.contacts,
                        title: 'جهات الاتصال',
                        subtitle: 'إدارة جهات الاتصال والمجموعات',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildInfoTile(
                        icon: Icons.alternate_email,
                        title: 'اسم المستخدم',
                        value: '@${_currentUser!.username ?? "غير محدد"}',
                        onTap: () => _showEditDialog(
                          context,
                          'اسم المستخدم',
                          _currentUser!.username ?? '',
                          _updateUsername,
                        ),
                      ),
                      _buildInfoTile(
                        icon: Icons.info_outline,
                        title: 'نبذة',
                        value: _currentUser!.bio?.isNotEmpty == true
                            ? _currentUser!.bio!
                            : 'رقمي، حسابي، هويتي.',
                        onTap: () => _showEditDialog(
                          context,
                          'النبذة',
                          _currentUser!.bio ?? '',
                          _updateBio,
                          maxLines: 3,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // --- Identity & Security Section ---
                      _buildSectionHeader('الهوية والأمان'),
                      _buildIdentityCard(theme, _currentUser!.uid),

                      const SizedBox(height: 24),

                      // Privacy Settings moved to dedicated screen
                      const SizedBox(height: 40),

                      // --- Logout Section ---
                      Card(
                            elevation: 0,
                            color: theme.colorScheme.errorContainer.withOpacity(
                              0.1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: theme.colorScheme.error.withOpacity(0.2),
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.logout,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              title: Text(
                                'تسجيل الخروج',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: _confirmLogout,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 400.ms)
                          .slideY(begin: 0.5, end: 0),

                      const SizedBox(height: 40),

                      // Footer
                      Text(
                        'Secure ID: ${_currentUser!.uid.substring(0, 8)}...',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Widgets ---

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideX();
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).iconTheme.color),
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
        subtitle: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Icon(
          Icons.edit,
          size: 16,
          color: Theme.of(context).iconTheme.color,
        ),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ).animate().fadeIn(delay: 250.ms);
  }

  // ignore: unused_element
  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).iconTheme.color),
        title: Text(title),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        onTap: onTap,
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).iconTheme.color,
        ),
      ),
    );
  }

  Widget _buildIdentityCard(ThemeData theme, String uid) {
    final fingerprint = _getIdentityFingerprint(uid);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.surfaceVariant,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.fingerprint, color: Theme.of(context).iconTheme.color),
              SizedBox(width: 8),
              Text(
                'البصمة التعريفية',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Icon(
                Icons.shield_outlined,
                color: Theme.of(context).iconTheme.color,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              fingerprint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Courier', // Monospace for keys
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: fingerprint));
                  HapticFeedback.lightImpact(); // Feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ البصمة التعريفية')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('نسخ'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.2, end: 0);
  }

  Future<void> _showEditDialog(
    BuildContext context,
    String label,
    String initialValue,
    Function(String) onSave, {
    int maxLines = 1,
  }) async {
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

  ImageProvider? _getProfileImageProvider(String? photoURL) {
    if (photoURL == null || photoURL.isEmpty) return null;
    try {
      if (photoURL.startsWith('http')) {
        return NetworkImage(photoURL);
      } else {
        return MemoryImage(base64Decode(photoURL));
      }
    } catch (e) {
      return null;
    }
  }
}
