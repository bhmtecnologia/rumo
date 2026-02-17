import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:rumo_app/core/models/cost_center.dart';
import 'package:rumo_app/core/models/unit.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/utils/download.dart';

import 'package:excel/excel.dart';

/// Relatórios com filtros e exportação CSV, XML e XLS (Fase 5).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ApiService _api = ApiService();
  List<Unit> _units = [];
  List<CostCenter> _costCenters = [];
  DateTime? _from;
  DateTime? _to;
  String? _selectedUnitId;
  String? _selectedCostCenterId;
  String _cadastralType = 'units';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUnits();
    _loadCostCenters();
  }

  Future<void> _loadUnits() async {
    try {
      final list = await _api.listUnits();
      if (mounted) setState(() => _units = list);
    } catch (_) {}
  }

  Future<void> _loadCostCenters() async {
    try {
      final list = await _api.listCostCenters(unitId: _selectedUnitId);
      if (mounted) setState(() => _costCenters = list);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _fetchRides() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getReportsRides(
        from: _from,
        to: _to,
        costCenterId: _selectedCostCenterId,
        unitId: _selectedUnitId,
      );
      if (mounted) {
        setState(() { _loading = false; });
      }
      return list;
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCadastrais() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getReportsCadastrais(_cadastralType);
      if (mounted) {
        setState(() { _loading = false; });
      }
      return list;
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
      return [];
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    if (v is DateTime) return v.toIso8601String();
    return v.toString();
  }

  void _exportRidesCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado para exportar.')));
      return;
    }
    const sep = ';';
    final keys = rows.first.keys.toList();
    final header = keys.join(sep);
    final lines = [header];
    for (final row in rows) {
      lines.add(keys.map((k) => _csvEscape(_fmt(row[k]))).join(sep));
    }
    final content = lines.join('\r\n');
    if (kIsWeb) {
      downloadFile('relatorio_corridas_${DateTime.now().millisecondsSinceEpoch}.csv', content, 'text/csv; charset=utf-8');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportação CSV iniciada.')));
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a versão web para exportar arquivos.')));
      }
    }
  }

  String _csvEscape(String s) {
    if (s.contains(';') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  void _exportRidesXml(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado para exportar.')));
      return;
    }
    final buffer = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<corridas>\n');
    for (final row in rows) {
      buffer.write('  <corrida>\n');
      for (final e in row.entries) {
        final tag = e.key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        buffer.write('    <$tag>${_xmlEscape(_fmt(e.value))}</$tag>\n');
      }
      buffer.write('  </corrida>\n');
    }
    buffer.write('</corridas>');
    if (kIsWeb) {
      downloadFile('relatorio_corridas_${DateTime.now().millisecondsSinceEpoch}.xml', buffer.toString(), 'application/xml');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportação XML iniciada.')));
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a versão web para exportar arquivos.')));
      }
    }
  }

  String _xmlEscape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  void _exportRidesXls(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado para exportar.')));
      return;
    }
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Corridas');
    final sheet = excel['Corridas'];
    final keys = rows.first.keys.toList();
    sheet.appendRow(keys.map((k) => TextCellValue(k)).toList());
    for (final row in rows) {
      sheet.appendRow(keys.map((k) => TextCellValue(_fmt(row[k]))).toList());
    }
    final bytes = excel.encode();
    if (bytes != null && kIsWeb) {
      downloadBytes('relatorio_corridas_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportação XLS iniciada.')));
    } else if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a versão web para exportar arquivos.')));
    }
  }

  void _exportCadastraisCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado para exportar.')));
      return;
    }
    const sep = ';';
    final keys = rows.first.keys.toList();
    final lines = [keys.join(sep)];
    for (final row in rows) {
      lines.add(keys.map((k) => _csvEscape(_fmt(row[k]))).join(sep));
    }
    if (kIsWeb) {
      downloadFile('relatorio_cadastral_${_cadastralType}_${DateTime.now().millisecondsSinceEpoch}.csv', lines.join('\r\n'), 'text/csv; charset=utf-8');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportação CSV iniciada.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a versão web para exportar arquivos.')));
    }
  }

  void _exportCadastraisXml(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado para exportar.')));
      return;
    }
    final root = _cadastralType;
    final buffer = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<$root>\n');
    for (final row in rows) {
      buffer.write('  <item>\n');
      for (final e in row.entries) {
        final tag = e.key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
        buffer.write('    <$tag>${_xmlEscape(_fmt(e.value))}</$tag>\n');
      }
      buffer.write('  </item>\n');
    }
    buffer.write('</$root>');
    if (kIsWeb) {
      downloadFile('relatorio_cadastral_${_cadastralType}_${DateTime.now().millisecondsSinceEpoch}.xml', buffer.toString(), 'application/xml');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportação XML iniciada.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a versão web para exportar arquivos.')));
    }
  }

  void _exportCadastraisXls(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum dado para exportar.')));
      return;
    }
    final excel = Excel.createExcel();
    excel.rename('Sheet1', _cadastralType);
    final sheet = excel[_cadastralType];
    final keys = rows.first.keys.toList();
    sheet.appendRow(keys.map((k) => TextCellValue(k)).toList());
    for (final row in rows) {
      sheet.appendRow(keys.map((k) => TextCellValue(_fmt(row[k]))).toList());
    }
    final bytes = excel.encode();
    if (bytes != null && kIsWeb) {
      downloadBytes('relatorio_cadastral_${_cadastralType}_${DateTime.now().millisecondsSinceEpoch}.xlsx', bytes, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exportação XLS iniciada.')));
    } else if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a versão web para exportar arquivos.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Relatórios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: Colors.red[300])),
              const SizedBox(height: 16),
            ],
            _buildRidesSection(),
            const SizedBox(height: 32),
            _buildCadastraisSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildRidesSection() {
    return Card(
      color: const Color(0xFF2C2C2C),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Relatório de corridas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_from == null ? 'Data início' : DateFormat('dd/MM/yyyy').format(_from!)),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) setState(() => _from = d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_to == null ? 'Data fim' : DateFormat('dd/MM/yyyy').format(_to!)),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: _to ?? DateTime.now(), firstDate: _from ?? DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) setState(() => _to = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              value: _selectedUnitId,
              decoration: InputDecoration(labelText: 'Unidade', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              items: [const DropdownMenuItem(value: null, child: Text('Todas')), ..._units.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name)))],
              onChanged: (v) {
                setState(() {
                  _selectedUnitId = v;
                  _selectedCostCenterId = null;
                  _loadCostCenters();
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: _selectedCostCenterId,
              decoration: InputDecoration(labelText: 'Centro de custo', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              items: [const DropdownMenuItem(value: null, child: Text('Todos')), ..._costCenters.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))],
              onChanged: (v) => setState(() => _selectedCostCenterId = v),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            if (!_loading)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(icon: const Icon(Icons.table_chart), label: const Text('Exportar CSV'), onPressed: () async { final d = await _fetchRides(); _exportRidesCsv(d); }),
                  FilledButton.icon(icon: const Icon(Icons.code), label: const Text('Exportar XML'), onPressed: () async { final d = await _fetchRides(); _exportRidesXml(d); }),
                  FilledButton.icon(icon: const Icon(Icons.grid_on), label: const Text('Exportar XLS'), onPressed: () async { final d = await _fetchRides(); _exportRidesXls(d); }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCadastraisSection() {
    return Card(
      color: const Color(0xFF2C2C2C),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Relatório cadastral', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _cadastralType,
              decoration: InputDecoration(labelText: 'Tipo', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              items: const [
                DropdownMenuItem(value: 'units', child: Text('Units')),
                DropdownMenuItem(value: 'cost_centers', child: Text('Centros de custo')),
                DropdownMenuItem(value: 'users', child: Text('Usuários')),
                DropdownMenuItem(value: 'request_reasons', child: Text('Motivos de solicitação')),
              ],
              onChanged: (v) => setState(() => _cadastralType = v ?? 'units'),
            ),
            const SizedBox(height: 16),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            if (!_loading)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(icon: const Icon(Icons.table_chart), label: const Text('Exportar CSV'), onPressed: () async { final d = await _fetchCadastrais(); _exportCadastraisCsv(d); }),
                  FilledButton.icon(icon: const Icon(Icons.code), label: const Text('Exportar XML'), onPressed: () async { final d = await _fetchCadastrais(); _exportCadastraisXml(d); }),
                  FilledButton.icon(icon: const Icon(Icons.grid_on), label: const Text('Exportar XLS'), onPressed: () async { final d = await _fetchCadastrais(); _exportCadastraisXls(d); }),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
