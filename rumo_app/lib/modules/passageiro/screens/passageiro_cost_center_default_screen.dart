import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/cost_center.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/auth_service.dart';
import 'package:rumo_app/core/services/passenger_preferences_service.dart';

/// Seleção de centro de custo padrão para o passageiro.
class PassageiroCostCenterDefaultScreen extends StatefulWidget {
  const PassageiroCostCenterDefaultScreen({super.key});

  @override
  State<PassageiroCostCenterDefaultScreen> createState() => _PassageiroCostCenterDefaultScreenState();
}

class _PassageiroCostCenterDefaultScreenState extends State<PassageiroCostCenterDefaultScreen> {
  final _api = ApiService();
  final _prefs = PassengerPreferencesService();
  List<CostCenter> _centers = [];
  String? _selectedId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ids = AuthService().currentUser?.costCenterIds ?? [];
      final defaultId = await _prefs.getDefaultCostCenterId();
      if (ids.isEmpty) {
        if (mounted) setState(() { _loading = false; return; });
        return;
      }
      final list = await _api.listCostCenters();
      if (!mounted) return;
      final filtered = list.where((c) => ids.contains(c.id)).toList();
      setState(() {
        _centers = filtered;
        _selectedId = defaultId ?? (filtered.isNotEmpty ? filtered.first.id : null);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _save(String? id) async {
    await _prefs.setDefaultCostCenterId(id);
    if (mounted) {
      setState(() => _selectedId = id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Centro de custo padrão salvo.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Centro de custo padrão'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _centers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_center_outlined, size: 64, color: Colors.grey[500]),
                        const SizedBox(height: 16),
                        Text(
                          _error ?? 'Você possui apenas um centro de custo ou nenhum vinculado.',
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Escolha o centro de custo que será usado por padrão ao solicitar corridas.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ..._centers.map((c) => _CenterTile(
                          center: c,
                          selected: _selectedId == c.id,
                          onTap: () => _save(c.id),
                        )),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => _save(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[400],
                        side: BorderSide(color: Colors.grey[600]!),
                      ),
                      child: const Text('Nenhum (escolher sempre)'),
                    ),
                  ],
                ),
    );
  }
}

class _CenterTile extends StatelessWidget {
  final CostCenter center;
  final bool selected;
  final VoidCallback onTap;

  const _CenterTile({required this.center, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? const Color(0xFF00D95F) : Colors.grey[500],
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        center.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (center.unitName != null && center.unitName!.isNotEmpty)
                        Text(
                          center.unitName!,
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
