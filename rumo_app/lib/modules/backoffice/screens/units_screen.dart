import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/unit.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/auth_service.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key});

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  final ApiService _api = ApiService();
  List<Unit> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.listUnits();
      if (mounted) setState(() { _list = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showForm([Unit? unit]) async {
    final nameController = TextEditingController(text: unit?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(unit == null ? 'Nova unidade' : 'Editar unidade'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nome'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    try {
      if (unit == null) {
        await _api.createUnit(name);
      } else {
        await _api.updateUnit(unit.id, name);
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

  Future<void> _confirmDelete(Unit unit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir unidade?'),
        content: Text('Excluir "${unit.name}"? Centros de custo vinculados também serão removidos.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Não')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, excluir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteUnit(unit.id);
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
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Units'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
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
                        'Nenhuma unidade. Toque em + para criar.',
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
                              '${u.costCenterCount} centro(s) de custo',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _showForm(u);
                                if (v == 'delete') _confirmDelete(u);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: AuthService().currentUser?.isGestorCentral == true
          ? FloatingActionButton(
              onPressed: () => _showForm(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
