import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

class IntentionSubmitScreen extends StatefulWidget {
  final Map<String, dynamic>? existingIntention;

  const IntentionSubmitScreen({super.key, this.existingIntention});

  @override
  State<IntentionSubmitScreen> createState() => _IntentionSubmitScreenState();
}

class _IntentionSubmitScreenState extends State<IntentionSubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _intentionController = TextEditingController();
  bool isPublic = true;
  bool approved = false;
  bool isLoading = false;
  String? userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();

    if (widget.existingIntention != null) {
      _nameController.text = widget.existingIntention!['name'] ?? '';
      _intentionController.text = widget.existingIntention!['intention'] ?? '';
      isPublic = widget.existingIntention!['is_public'] ?? true;
      approved = widget.existingIntention!['approved'] ?? false;
    }
  }

  Future<void> _loadUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final userData = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      setState(() {
        userRole = userData?['role'];
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = {
      'user_id': user.id,
      'name': _nameController.text.trim(),
      'intention': _intentionController.text.trim(),
      'is_public': isPublic,
      'approved': approved,
    };

    final intentionId = widget.existingIntention?['id'];

    if (intentionId != null) {
      await Supabase.instance.client
          .from('intentions')
          .update(data)
          .eq('id', intentionId);
    } else {
      await Supabase.instance.client.from('intentions').insert(data);
    }

    setState(() => isLoading = false);
    if (context.mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('intention_delete_title')),
        content: Text(tr('intention_delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              tr('delete'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.existingIntention != null) {
      await Supabase.instance.client
          .from('intentions')
          .delete()
          .eq('id', widget.existingIntention!['id']);
      if (context.mounted) Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingIntention != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? tr('edit_intention_title') : tr('new_intention_title'),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: tr('delete_intention'),
              onPressed: _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('intention_motivation'),
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: tr('your_name_optional'),
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _intentionController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: tr('intention'),
                      alignLabelWithHint: true,
                      prefixIcon: const Icon(Icons.favorite_outline),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? tr('intention_required')
                        : null,
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    title: Text(tr('publish_intention')),
                    value: isPublic,
                    onChanged: (val) => setState(() => isPublic = val),
                  ),

                  if (userRole == 'admin') ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(tr('approved')),
                      value: approved,
                      onChanged: (val) => setState(() => approved = val),
                    ),
                  ],
                  const SizedBox(height: 24),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isLoading
                          ? const SizedBox(
                              key: ValueKey('loading'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isEditing ? Icons.save : Icons.send,
                              key: ValueKey('icon'),
                            ),
                    ),
                    label: Text(
                      isEditing ? tr('save_changes') : tr('submit_intention'),
                    ),
                    onPressed: isLoading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
