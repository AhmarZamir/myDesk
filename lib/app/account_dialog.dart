import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

Future<void> showAccountDialog(BuildContext context) async {
  final auth = AuthService();
  var profile = await auth.fetchProfile();
  if (!context.mounted) return;

  final name = TextEditingController(text: profile?['full_name']?.toString() ?? '');
  bool saving = false;
  String? avatarUrl = profile?['avatar_url']?.toString();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setLocal) => AlertDialog(
        title: const Text('Your profile'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: avatarUrl?.isNotEmpty == true ? NetworkImage(avatarUrl!) : null,
                      child: avatarUrl?.isNotEmpty == true ? null : const Icon(Icons.person, size: 46),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: IconButton.filled(
                        tooltip: 'Change profile picture',
                        onPressed: saving
                            ? null
                            : () async {
                                final picked = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                                  withData: true,
                                );
                                if (picked == null || picked.files.single.bytes == null) return;
                                setLocal(() => saving = true);
                                try {
                                  avatarUrl = await auth.uploadAvatar(
                                    bytes: picked.files.single.bytes!,
                                    fileName: picked.files.single.name,
                                  );
                                  profile = await auth.fetchProfile();
                                  setLocal(() => saving = false);
                                } catch (e) {
                                  setLocal(() => saving = false);
                                  if (dialogContext.mounted) {
                                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Could not upload photo: $e')));
                                  }
                                }
                              },
                        icon: const Icon(Icons.camera_alt_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(auth.currentUser?.email ?? '', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
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
