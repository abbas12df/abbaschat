import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../chat/screens/home_screen.dart';

class SetupProfileScreen extends ConsumerStatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  ConsumerState<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Save to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'displayName': name,
          'phoneNumber': user.phoneNumber,
          'photoURL': null, // We will implement image picker later
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
        });

        // Update Auth Profile
        await user.updateDisplayName(name);

        if (mounted) {
          // Navigate to Home and remove all previous routes
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحفظ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar Placeholder
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey.shade200,
              child: Icon(Icons.person, size: 50, color: Colors.grey.shade400),
            ).animate().scale(),
            const SizedBox(height: 16),
            const Text('اختر صورة شخصية').animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                hintText: 'اكتب اسمك هنا',
                prefixIcon: Icon(Icons.person),
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('بدء الاستخدام'),
              ),
            ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}
