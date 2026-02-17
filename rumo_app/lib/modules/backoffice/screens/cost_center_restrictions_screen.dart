import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/cost_center.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/auth_service.dart';

class CostCenterRestrictionsScreen extends StatefulWidget {
  final String costCenterId;

  const CostCenterRestrictionsScreen({super.key, required this.costCenterId});

  @override
  State<CostCenterRestrictionsScreen> createState() => _CostCenterRestrictionsScreenState();
}

class _CostCenterRestrictionsScreenState extends State<CostCenterRestrictionsScreen> {
  final ApiService _api = ApiService();
  CostCenter? _cc;
  bool _loading = true;
  String? _error;

  bool _blocked = false;
  final _monthlyLimitController = TextEditingController();
  final _maxKmController = TextEditingController();
  final _timeStartController = TextEditingController();
  final _timeEndController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _monthlyLimitController.dispose();
    _maxKmController.dispose();
    _timeStartController.dispose();
    _timeEndController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cc = await _api.getCostCenter(widget.costCenterId);
      if (!mounted) return;
      _blocked = cc.blocked;
      _monthlyLimitController.text = cc.monthlyLimitCents != null ? (cc.monthlyLimitCents! / 100).toStringAsFixed(0) : '';
      _maxKmController.text = cc.maxKm?.toString() ?? '';
      _timeStartController.text = cc.allowedTimeStart ?? '';
      _timeEndController.text = cc.allowedTimeEnd ?? '';
      setState(() { _cc = cc; _loading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _saveRestrictions() async {
    if (_cc == null) return;
    try {
      await _api.updateCostCenter(
        _cc!.id,
        blocked: _blocked,
        monthlyLimitCents: _monthlyLimitController.text.trim().isEmpty
            ? null
            : (double.tryParse(_monthlyLimitController.text.replaceFirst(',', '.')) ?? 0) * 100 ~/ 1,
        maxKm: _maxKmController.text.trim().isEmpty
            ? null
            : double.tryParse(_maxKmController.text.replaceFirst(',', '.')),
        allowedTimeStart: _timeStartController.text.trim().isEmpty ? null : _timeStartController.text.trim(),
        allowedTimeEnd: _timeEndController.text.trim().isEmpty ? null : _timeEndController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restrições salvas.')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddArea() async {
    if (_cc == null) return;
    String type = 'origin';
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final radiusController = TextEditingController(text: '5');
    final labelController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova área permitida'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'origin', child: Text('Origem')),
                    DropdownMenuItem(value: 'destination', child: Text('Destino')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latController,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: lngController,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: radiusController,
                  decoration: const InputDecoration(labelText: 'Raio (km)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: labelController,
                  decoration: const InputDecoration(labelText: 'Rótulo (opcional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Adicionar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final lat = double.tryParse(latController.text.replaceFirst(',', '.'));
    final lng = double.tryParse(lngController.text.replaceFirst(',', '.'));
    final radius = double.tryParse(radiusController.text.replaceFirst(',', '.')) ?? 5.0;
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe latitude e longitude válidos.'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      await _api.addCostCenterArea(
        _cc!.id,
        type: type,
        lat: lat,
        lng: lng,
        radiusKm: radius,
        label: labelController.text.trim().isEmpty ? null : labelController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Área adicionada.')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmRemoveArea(AllowedArea area) async {
    if (_cc == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover área?'),
        content: Text('Remover ${area.label ?? '${area.type} (${area.lat}, ${area.lng})'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Não')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, remover'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.deleteCostCenterArea(_cc!.id, area.id);
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
        title: Text(_cc?.name ?? 'Restrições'),
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
              : _cc == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            color: const Color(0xFF2C2C2C),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Restrições gerais', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  SwitchListTile(
                                    title: const Text('Centro de custo bloqueado', style: TextStyle(color: Colors.white)),
                                    subtitle: Text('Bloqueado: não permite novas corridas.', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                    value: _blocked,
                                    onChanged: AuthService().currentUser?.isGestorCentral == true
                                        ? (v) => setState(() => _blocked = v)
                                        : null,
                                  ),
                                  TextField(
                                    controller: _monthlyLimitController,
                                    decoration: const InputDecoration(
                                      labelText: 'Limite mensal (R\$)',
                                      hintText: 'Ex: 5000',
                                    ),
                                    keyboardType: TextInputType.number,
                                    readOnly: AuthService().currentUser?.isGestorCentral != true,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _maxKmController,
                                    decoration: const InputDecoration(
                                      labelText: 'Distância máxima por corrida (km)',
                                      hintText: 'Ex: 50',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    readOnly: AuthService().currentUser?.isGestorCentral != true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _timeStartController,
                                    decoration: const InputDecoration(
                                      labelText: 'Horário início (HH:mm)',
                                      hintText: 'Ex: 06:00',
                                    ),
                                    readOnly: AuthService().currentUser?.isGestorCentral != true,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _timeEndController,
                                    decoration: const InputDecoration(
                                      labelText: 'Horário fim (HH:mm)',
                                      hintText: 'Ex: 22:00',
                                    ),
                                    readOnly: AuthService().currentUser?.isGestorCentral != true,
                                  ),
                                  if (AuthService().currentUser?.isGestorCentral == true) ...[
                                    const SizedBox(height: 16),
                                    FilledButton(
                                      onPressed: _saveRestrictions,
                                      child: const Text('Salvar restrições'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Áreas permitidas (origem/destino)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              if (AuthService().currentUser?.isGestorCentral == true)
                                TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Adicionar área'),
                                  onPressed: _showAddArea,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_cc!.allowedAreas.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Nenhuma área definida. Sem áreas, origem e destino não são restringidos por zona.',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                            )
                          else
                            ..._cc!.allowedAreas.map((a) => Card(
                                  color: const Color(0xFF2C2C2C),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    title: Text(
                                      a.label ?? '${a.type == 'origin' ? 'Origem' : 'Destino'} (${a.lat.toStringAsFixed(4)}, ${a.lng.toStringAsFixed(4)})',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text('Raio: ${a.radiusKm} km', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                                    trailing: AuthService().currentUser?.isGestorCentral == true
                                        ? IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            onPressed: () => _confirmRemoveArea(a),
                                          )
                                        : null,
                                  ),
                                )),
                        ],
                      ),
                    ),
    );
  }
}
