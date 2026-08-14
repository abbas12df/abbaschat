import 'package:flutter/material.dart';

class AdminPermissionsDialog extends StatefulWidget {
  final String adminName;
  final List<String> currentPermissions;
  final Function(List<String>) onSave;

  const AdminPermissionsDialog({
    super.key,
    required this.adminName,
    required this.currentPermissions,
    required this.onSave,
  });

  @override
  State<AdminPermissionsDialog> createState() => _AdminPermissionsDialogState();
}

class _AdminPermissionsDialogState extends State<AdminPermissionsDialog> {
  late List<String> _selectedPermissions;

  @override
  void initState() {
    super.initState();
    _selectedPermissions = List.from(widget.currentPermissions);
  }

  void _togglePermission(String key) {
    setState(() {
      if (_selectedPermissions.contains(key)) {
        _selectedPermissions.remove(key);
      } else {
        _selectedPermissions.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('صلاحيات المشرف: ${widget.adminName}'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            _buildSwitch('تغيير معلومات المجموعة', 'change_info', Icons.edit),
            _buildSwitch('إضافة أعضاء ودعوات', 'add_members', Icons.person_add),
            _buildSwitch('حذف الأعضاء', 'remove_members', Icons.person_remove),
            _buildSwitch('إدارة المشرفين', 'manage_admins', Icons.security),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_selectedPermissions);
            Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  Widget _buildSwitch(String label, String key, IconData icon) {
    return SwitchListTile(
      title: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        ],
      ),
      value: _selectedPermissions.contains(key),
      onChanged: (val) => _togglePermission(key),
    );
  }
}
