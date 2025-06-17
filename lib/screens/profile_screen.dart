import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  String? _role;
  String? _avatarUrl;
  DateTime? _registeredAt;
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final user = supabase.auth.currentUser;
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    fetchFullName();
    fetchRole();
    fetchRegisteredAt();
  }

  Future<void> fetchFullName() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('users')
        .select('full_name, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    if (data != null) {
      setState(() {
        _nameCtrl.text = data['full_name'] ?? '';
        _avatarUrl = data['avatar_url'];
      });
    }
  }

  Future<void> fetchRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    setState(() {
      _role = data?['role'] ?? 'user';
    });
  }

  Future<void> fetchRegisteredAt() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final data = await supabase
        .from('users')
        .select('created_at')
        .eq('id', user.id)
        .maybeSingle();
    if (data != null && data['created_at'] != null) {
      setState(() {
        _registeredAt = DateTime.parse(data['created_at']);
      });
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      await supabase
          .from('users')
          .update({'full_name': _nameCtrl.text.trim()})
          .eq('id', user.id);
      await supabase.auth.updateUser(
        UserAttributes(email: _emailCtrl.text.trim()),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('profile.snackbar.saved'.tr())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'profile.snackbar.save_failed'.tr(args: [e.toString()]),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> changePassword() async {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? error;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('profile.password2.title'.tr()),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'profile.password2.current'.tr(),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'profile.password2.current_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'profile.password2.new'.tr(),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) {
                          return 'profile.password2.min_length'.tr();
                        }
                        if (v == currentPassCtrl.text) {
                          return 'profile.password2.same_as_current'.tr();
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'profile.password2.confirm'.tr(),
                      ),
                      validator: (v) => v != newPassCtrl.text
                          ? 'profile.password2.not_match'.tr()
                          : null,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: Text(
                    'profile.button.cancel'.tr(),
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => isLoading = true);
                          try {
                            final email = supabase.auth.currentUser?.email;
                            if (email == null) throw Exception('Chýba email');
                            final signInResp = await supabase.auth
                                .signInWithPassword(
                                  email: email,
                                  password: currentPassCtrl.text,
                                );
                            if (signInResp.user == null) {
                              setState(() {
                                error = 'profile.password2.incorrect_current'
                                    .tr();
                                isLoading = false;
                              });
                              return;
                            }
                            await supabase.auth.updateUser(
                              UserAttributes(password: newPassCtrl.text),
                            );
                            if (mounted) Navigator.of(context).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'profile.password2.changed'.tr(),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              error = 'profile.snackbar.error'.tr(
                                args: [e.toString()],
                              );
                              isLoading = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('profile.button.save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> showAvatarPicker() async {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_camera,
                color: theme.colorScheme.primary,
              ),
              title: Text('profile.avatar.camera'.tr()),
              onTap: () {
                Navigator.pop(context);
                changeAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: theme.colorScheme.primary,
              ),
              title: Text('profile.avatar.gallery'.tr()),
              onTap: () {
                Navigator.pop(context);
                changeAvatar(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> changeAvatar(ImageSource source) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await picked.readAsBytes();
      img.Image? original = img.decodeImage(bytes);
      if (original == null) throw Exception('Neplatný obrázok');

      img.Image thumbnail = img.copyResizeCropSquare(original, size: 400);

      Uint8List jpg = Uint8List.fromList(img.encodeJpg(thumbnail, quality: 75));

      final fileExt = 'jpg';
      final filePath =
          'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            jpg,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final avatarUrl = supabase.storage.from('avatars').getPublicUrl(filePath);

      await supabase
          .from('users')
          .update({'avatar_url': avatarUrl})
          .eq('id', user.id);

      setState(() {
        _avatarUrl = avatarUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('profile.avatar.changed'.tr())));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.avatar.error'.tr(args: [e.toString()])),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('profile.title'.tr()),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'profile.button.logout'.tr(),
            onPressed: signOut,
          ),
        ],
      ),
      body: user == null
          ? Center(child: Text("profile.not_logged".tr()))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _isUploading ? null : showAvatarPicker,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            backgroundImage:
                                (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                ? NetworkImage(_avatarUrl!)
                                : null,
                            child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                                ? Icon(
                                    Icons.person,
                                    size: 48,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                          ),
                          if (_isUploading)
                            const SizedBox(
                              width: 84,
                              height: 84,
                              child: CircularProgressIndicator(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _isUploading ? null : showAvatarPicker,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                      child: Text('profile.avatar.change'.tr()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'profile.field.fullname'.tr(),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'profile.field.fullname_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      leading: Icon(
                        Icons.email,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text('profile.field.email'.tr()),
                      subtitle: Text(_emailCtrl.text),
                    ),
                    const SizedBox(height: 14),
                    if (_registeredAt != null) ...[
                      ListTile(
                        leading: Icon(
                          Icons.event,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text('profile.field.registered_at'.tr()),
                        subtitle: Text(
                          '${_registeredAt!.day.toString().padLeft(2, '0')}.'
                          '${_registeredAt!.month.toString().padLeft(2, '0')}.'
                          '${_registeredAt!.year}',
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    ListTile(
                      leading: Icon(
                        Icons.verified_user,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text('profile.field.role'.tr()),
                      subtitle: Text(
                        _role ?? 'profile.field.role_loading'.tr(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: changePassword,
                      icon: Icon(
                        Icons.lock_reset,
                        color: theme.colorScheme.primary,
                      ),
                      label: Text('profile.button.change_password'.tr()),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.colorScheme.primary),
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text('profile.button.save_changes'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
