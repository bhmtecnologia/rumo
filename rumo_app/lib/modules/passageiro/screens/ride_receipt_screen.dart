import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:rumo_app/core/services/api_service.dart';

/// Tela de recibo da corrida finalizada.
class RideReceiptScreen extends StatefulWidget {
  final String rideId;

  const RideReceiptScreen({super.key, required this.rideId});

  @override
  State<RideReceiptScreen> createState() => _RideReceiptScreenState();
}

class _RideReceiptScreenState extends State<RideReceiptScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _receipt;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final receipt = await _api.getRideReceipt(widget.rideId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
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

  void _shareReceipt() {
    if (_receipt == null) return;
    final r = _receipt!;
    final price = (r['formattedPrice'] ?? '—') as String;
    final pickup = (r['pickupAddress'] ?? '—') as String;
    final dest = (r['destinationAddress'] ?? '—') as String;
    final driver = (r['driverName'] ?? '—') as String;
    final dist = r['actualDistanceKm'] != null
        ? '${(r['actualDistanceKm'] as num).toStringAsFixed(1)} km'
        : '';
    final dur = r['actualDurationMin'] != null ? '${r['actualDurationMin']} min' : '';
    final text = [
      'Recibo Rumo',
      'Valor: $price',
      'Origem: $pickup',
      'Destino: $dest',
      'Motorista: $driver',
      if (dist.isNotEmpty) 'Distância: $dist',
      if (dur.isNotEmpty) 'Duração: $dur',
    ].join('\n');
    Share.share(text, subject: 'Recibo Rumo');
  }

  String _formatDate(dynamic value) {
    if (value == null) return '—';
    final dt = value is DateTime ? value : DateTime.tryParse(value.toString());
    if (dt == null) return '—';
    return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Recibo'),
        actions: [
          if (_receipt != null)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _shareReceipt,
              tooltip: 'Compartilhar',
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Colors.red[300]), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _loadReceipt,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _receipt == null
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2C2C2C),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Valor final',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        (_receipt!['formattedPrice'] ?? '—') as String,
                                        style: const TextStyle(
                                          color: Color(0xFF00D95F),
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_receipt!['actualDistanceKm'] != null) ...[
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    const SizedBox(height: 12),
                                    _ReceiptRow(
                                      label: 'Distância',
                                      value: '${(_receipt!['actualDistanceKm'] as num).toStringAsFixed(1)} km',
                                    ),
                                  ],
                                  if (_receipt!['actualDurationMin'] != null) ...[
                                    const SizedBox(height: 8),
                                    _ReceiptRow(
                                      label: 'Duração',
                                      value: '${_receipt!['actualDurationMin']} min',
                                    ),
                                  ],
                                  if (_receipt!['rating'] != null) ...[
                                    const SizedBox(height: 8),
                                    _ReceiptRow(
                                      label: 'Sua avaliação',
                                      value: '${_receipt!['rating']} estrelas',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildSection('Trajeto', [
                              _buildAddressRow(Icons.radio_button_checked, (_receipt!['pickupAddress'] ?? '—') as String),
                              const SizedBox(height: 8),
                              _buildAddressRow(Icons.place, (_receipt!['destinationAddress'] ?? '—') as String),
                            ]),
                            const SizedBox(height: 20),
                            _buildSection('Motorista', [
                              _ReceiptRow(label: 'Nome', value: (_receipt!['driverName'] ?? '—') as String),
                              if (_receipt!['vehiclePlate'] != null)
                                _ReceiptRow(label: 'Veículo', value: (_receipt!['vehiclePlate']) as String),
                            ]),
                            const SizedBox(height: 20),
                            _buildSection('Horários', [
                              _ReceiptRow(label: 'Início', value: _formatDate(_receipt!['startedAt'])),
                              _ReceiptRow(label: 'Término', value: _formatDate(_receipt!['completedAt'])),
                            ]),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: icon == Icons.place ? Colors.red[400] : Colors.green[400]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[300], fontSize: 14),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
