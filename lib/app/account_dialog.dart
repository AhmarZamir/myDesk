import 'package:flutter/material.dart';
import '../services/auth_service.dart';

Future<void> showAccountDialog(BuildContext context) async {
  final auth = AuthService();
  final profile = await auth.fetchProfile();
  if (!context.mounted) return;

  final name = TextEditingController(text: profile?['full_name']?.toString() ?? '');
  bool saving = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocal) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.account_circle_outlined),
          SizedBox(width: 10),
          Text('Your account'),
        ]),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(auth.currentUser?.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: name,
              enabled: !saving,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final email = auth.currentUser?.email;
                      if (email == null) return;
                      try {
                        await auth.requestPasswordReset(email);
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Password reset link sent to your email.')));
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not send reset link: $e')));
                        }
                      }
                    },
              icon: const Icon(Icons.lock_reset),
              label: const Text('Send password reset link'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Close')),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (name.text.trim().length < 2) return;
                    setLocal(() => saving = true);
                    try {
                      await auth.updateProfile(name.text);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
                      }
                    } catch (e) {
                      setLocal(() => saving = false);
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not update profile: $e')));
                      }
                    }
                  },
            child: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    ),
  );

  name.dispose();
}
