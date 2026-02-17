import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/cost_center.dart';
import 'package:rumo_app/core/models/user_list_item.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/auth_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiService _api = ApiService();
  List<UserListItem> _list = [];
  List<CostCenter> _costCenters = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCostCenters();
  }

  Future<void> _loadCostCenters() async {
    try {
      final list = await _api.listCostCenters();
      if (mounted) setState(() => _costCenters = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.listUsers();
      if (mounted) setState(() { _list = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showForm([UserListItem? user]) async {
    if (_costCenters.isEmpty) await _loadCostCenters();
    final nameController = TextEditingController(text: user?.name ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    String profile = user?.profile ?? 'usuario';
    List<String> selectedCcIds = List.from(user?.costCenterIds ?? []);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'Novo usuário' : 'Editar usuário'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  autofocus: true,
                ),
                if (user == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Senha (mín. 6)'),
                    obscureText: true,
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: profile,
                  decoration: const InputDecoration(labelText: 'Perfil'),
                  items: const [
                    DropdownMenuItem(value: 'usuario', child: Text('Usuário')),
                    DropdownMenuItem(value: 'gestor_unidade', child: Text('Gestor Unidade')),
                    DropdownMenuItem(value: 'gestor_central', child: Text('Gestor Central')),
                  ],
                  onChanged: (v) => setDialogState(() => profile = v ?? profile),
                ),
                const SizedBox(height: 12),
                const Text('Centros de custo', style: TextStyle(fontSize: 12)),
                ..._costCenters.map((cc) => CheckboxListTile(
                      value: selectedCcIds.contains(cc.id),
                      title: Text(cc.name, style: const TextStyle(fontSize: 14)),
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            selectedCcIds.add(cc.id);
                          } else {
                            selectedCcIds.remove(cc.id);
                          }
                        });
                      },
                    )),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Nova senha (deixe vazio para não alterar)'),
                    obscureText: true,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome é obrigatório')));
      return;
    }
    try {
      if (user == null) {
        final email = emailController.text.trim();
        final password = passwordController.text;
        if (email.isEmpty || password.length < 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('E-mail e senha (mín. 6) são obrigatórios')),
          );
          return;
        }
        await _api.createUser(
          email: email,
          password: password,
          name: name,
          profile: profile,
          costCenterIds: selectedCcIds,
        );
      } else {
        await _api.updateUser(
          user.id,
          name: name,
          profile: profile,
          costCenterIds: selectedCcIds,
          password: passwordController.text.isNotEmpty ? passwordController.text : null,
        );
      }
      if (mounted) _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCentral = AuthService().currentUser?.isGestorCentral == true;
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Usuários'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: TextStyle(color: Colors.red[300]), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
                      ],
                    ),
                  ),
                )
              : _list.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum usuário. Toque em + para criar.',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _list.length,
                      itemBuilder: (context, i) {
                        final u = _list[i];
                        return Card(
                          color: const Color(0xFF2C2C2C),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(u.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              '${u.email} • ${u.profileLabel}',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            trailing: isCentral
                                ? IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showForm(u),
                                  )
                                : null,
                            onTap: isCentral ? () => _showForm(u) : null,
                          ),
                        );
                      },
                    ),
      floatingActionButton: isCentral
          ? FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add))
          : null,
    );
  }
}
