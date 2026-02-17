import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/cost_center.dart';
import 'package:rumo_app/core/models/unit.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/auth_service.dart';

class CostCentersScreen extends StatefulWidget {
  const CostCentersScreen({super.key});

  @override
  State<CostCentersScreen> createState() => _CostCentersScreenState();
}

class _CostCentersScreenState extends State<CostCentersScreen> {
  final ApiService _api = ApiService();
  List<CostCenter> _list = [];
  List<Unit> _units = [];
  String? _filterUnitId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _load();
  }

  Future<void> _loadUnits() async {
    try {
      final list = await _api.listUnits();
      if (mounted) setState(() => _units = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.listCostCenters(unitId: _filterUnitId);
      if (mounted) setState(() { _list = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showForm([CostCenter? cc]) async {
    List<Unit> units = _units;
    if (units.isEmpty) {
      units = await _api.listUnits();
      if (!mounted) return;
      setState(() => _units = units);
    }
    if (units.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crie uma unidade antes de criar centro de custo.')),
      );
      return;
    }
    String? selectedUnitId = cc?.unitId ?? _filterUnitId ?? units.first.id;
    final nameController = TextEditingController(text: cc?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(cc == null ? 'Novo centro de custo' : 'Editar centro de custo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedUnitId,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                  items: units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))).toList(),
                  onChanged: (v) => setDialogState(() => selectedUnitId = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  autofocus: cc == null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted || selectedUnitId == null) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    try {
      if (cc == null) {
        await _api.createCostCenter(selectedUnitId, name);
      } else {
        await _api.updateCostCenter(cc.id, name, unitId: selectedUnitId);
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

  Future<void> _confirmDelete(CostCenter cc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir centro de custo?'),
        content: Text('Excluir "${cc.name}"?'),
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
      await _api.deleteCostCenter(cc.id);
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
        title: const Text('Centros de custo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          if (_units.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String?>(
                value: _filterUnitId,
                decoration: InputDecoration(
                  labelText: 'Unidade',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ..._units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                ],
                onChanged: (v) {
                  setState(() {
                    _filterUnitId = v;
                    _load();
                  });
                },
              ),
            ),
          Expanded(
            child: _loading
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
                              'Nenhum centro de custo. Toque em + para criar.',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _list.length,
                            itemBuilder: (context, i) {
                              final cc = _list[i];
                              return Card(
                                color: const Color(0xFF2C2C2C),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(cc.name, style: const TextStyle(color: Colors.white)),
                                  subtitle: Text(
                                    cc.unitName ?? cc.unitId,
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                  ),
                                  trailing: AuthService().currentUser?.isGestorCentral == true
                                      ? PopupMenuButton<String>(
                                          onSelected: (v) {
                                            if (v == 'edit') _showForm(cc);
                                            if (v == 'delete') _confirmDelete(cc);
                                          },
                                          itemBuilder: (_) => [
                                            const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                            const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                                          ],
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
          ),
        ],
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
