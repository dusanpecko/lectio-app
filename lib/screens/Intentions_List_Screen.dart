import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'intention_submit_screen.dart';

class IntentionsListScreen extends StatefulWidget {
  const IntentionsListScreen({super.key});

  @override
  State<IntentionsListScreen> createState() => _IntentionsListScreenState();
}

class _IntentionsListScreenState extends State<IntentionsListScreen> {
  List<Map<String, dynamic>> intentions = [];
  bool isLoading = false;
  String? role;

  @override
  void initState() {
    super.initState();
    fetchRoleAndIntentions();
  }

  Future<void> fetchRoleAndIntentions() async {
    setState(() => isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final userData = await Supabase.instance.client
        .from('users')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    role = userData?['role'] as String?;

    List<Map<String, dynamic>> res;
    if (role == 'admin') {
      res = List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('intentions')
            .select()
            .order('created_at', ascending: false),
      );
    } else {
      res = List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('intentions')
            .select()
            .eq('is_public', true)
            .eq('approved', true)
            .order('created_at', ascending: false),
      );
    }

    setState(() {
      intentions = res;
      isLoading = false;
    });
  }

  Future<void> approveIntention(int id, bool approved) async {
    await Supabase.instance.client
        .from('intentions')
        .update({'approved': approved})
        .eq('id', id);
    fetchRoleAndIntentions();
  }

  Future<void> onPrayed(int intentionId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final existing = await Supabase.instance.client
        .from('intention_prayers')
        .select()
        .eq('user_id', user.id)
        .eq('intention_id', intentionId)
        .maybeSingle();

    if (existing == null) {
      await Supabase.instance.client.from('intention_prayers').insert({
        'user_id': user.id,
        'intention_id': intentionId,
      });
      fetchRoleAndIntentions();
    }
  }

  Future<void> deleteIntention(int intentionId) async {
    await Supabase.instance.client
        .from('intentions')
        .delete()
        .eq('id', intentionId);
    fetchRoleAndIntentions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('intentions_title'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchRoleAndIntentions,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // Card s obrázkom a textom
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Image.asset(
                              'assets/images/modlitba.jpg',
                              fit: BoxFit.cover,
                              height: 180,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              'intention_intro'.tr(),
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.justify,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Zoznam úmyslov
                    if (intentions.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('no_intentions'.tr())),
                      )
                    else
                      ...intentions.map((item) {
                        final isAuthor =
                            Supabase.instance.client.auth.currentUser?.id ==
                            item['user_id'];
                        return (role == 'admin' || isAuthor)
                            ? Dismissible(
                                key: Key(item['id'].toString()),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('delete_intention'.tr()),
                                      content: Text('delete_confirmation'.tr()),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: Text('cancel'.tr()),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          child: Text('delete'.tr()),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (_) => deleteIntention(item['id']),
                                child: _buildIntentionCard(item, isAuthor),
                              )
                            : _buildIntentionCard(item, isAuthor);
                      }),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const IntentionSubmitScreen(),
            ),
          );
          if (result == true) {
            fetchRoleAndIntentions();
          }
        },
        tooltip: 'add_intention'.tr(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildIntentionCard(Map<String, dynamic> item, bool isAuthor) {
    return Card(
      //margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(item['intention'] ?? ''),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['name'] != null)
              Text(
                'from'.tr(args: [item['name']]),
                style: const TextStyle(fontSize: 12),
              ),
            if (role == 'admin')
              Text(
                'approved'.tr(
                  args: [
                    item['approved'] ? 'approved_yes'.tr() : 'approved_no'.tr(),
                  ],
                ),
                style: TextStyle(
                  fontSize: 12,
                  color: item['approved'] ? Colors.green : Colors.red,
                ),
              ),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: Supabase.instance.client
                  .from('intention_prayers')
                  .select('id')
                  .eq('intention_id', item['id']),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return Text('prayed_count'.tr(args: [count.toString()]));
              },
            ),
            FutureBuilder(
              future: Supabase.instance.client
                  .from('intention_prayers')
                  .select()
                  .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
                  .eq('intention_id', item['id'])
                  .maybeSingle(),
              builder: (context, snapshot) {
                final alreadyPrayed = snapshot.hasData && snapshot.data != null;
                return TextButton.icon(
                  icon: const Icon(Icons.volunteer_activism),
                  label: Text('i_prayed'.tr()),
                  onPressed: alreadyPrayed ? null : () => onPrayed(item['id']),
                );
              },
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAuthor)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.orange),
                tooltip: 'edit'.tr(),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          IntentionSubmitScreen(existingIntention: item),
                    ),
                  );
                  if (result == true) {
                    fetchRoleAndIntentions();
                  }
                },
              ),
            if (role == 'admin') ...[
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                tooltip: 'approve'.tr(),
                onPressed: () => approveIntention(item['id'], true),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'reject'.tr(),
                onPressed: () => approveIntention(item['id'], false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
