import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/ride.dart';
import 'package:rumo_app/core/services/api_service.dart';

class MotoristaActiveRideScreen extends StatefulWidget {
  final Ride ride;
  final VoidCallback? onUpdated;

  const MotoristaActiveRideScreen({super.key, required this.ride, this.onUpdated});

  @override
  State<MotoristaActiveRideScreen> createState() => _MotoristaActiveRideScreenState();
}

class _MotoristaActiveRideScreenState extends State<MotoristaActiveRideScreen> {
  final ApiService _api = ApiService();
  late Ride _ride;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
  }

  Future<void> _refresh() async {
    try {
      final updated = await _api.getRide(_ride.id);
      if (mounted) {
        setState(() => _ride = updated);
        widget.onUpdated?.call();
      }
    } catch (_) {}
  }

  Future<void> _markArrived() async {
    setState(() { _loading = true; _error = null; });
    try {
      final updated = await _api.markRideArrived(_ride.id);
      if (mounted) setState(() { _ride = updated; _loading = false; });
      widget.onUpdated?.call();
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _startRide() async {
    setState(() { _loading = true; _error = null; });
    try {
      final updated = await _api.startRide(_ride.id);
      if (mounted) setState(() { _ride = updated; _loading = false; });
      widget.onUpdated?.call();
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showCompleteDialog() async {
    final priceController = TextEditingController(
      text: (_ride.estimatedPriceCents != null ? _ride.estimatedPriceCents! / 100 : 0).toStringAsFixed(0),
    );
    final kmController = TextEditingController(
      text: _ride.estimatedDistanceKm?.toStringAsFixed(1) ?? '',
    );
    final durationController = TextEditingController(
      text: _ride.estimatedDurationMin?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar corrida'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Informe o valor final da corrida (R\$):'),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Valor (R\$)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kmController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Distância (km)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duração (min)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Finalizar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reais = double.tryParse(priceController.text.replaceFirst(',', '.'));
    if (reais == null || reais < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o valor em reais.'), backgroundColor: Colors.red));
      return;
    }
    final actualPriceCents = (reais * 100).round();
    final actualDistanceKm = double.tryParse(kmController.text.replaceFirst(',', '.'));
    final actualDurationMin = int.tryParse(durationController.text);
    setState(() { _loading = true; _error = null; });
    try {
      await _api.completeRide(
        _ride.id,
        actualPriceCents: actualPriceCents,
        actualDistanceKm: actualDistanceKm,
        actualDurationMin: actualDurationMin,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrida finalizada!')));
        Navigator.of(context).pop();
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRide() async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar corrida?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Motivo (opcional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Não')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      await _api.cancelRide(_ride.id, reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrida cancelada.')));
        Navigator.of(context).pop();
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
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
        title: Text(_statusTitle(_ride.status)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
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
            Card(
              color: const Color(0xFF2C2C2C),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(Icons.radio_button_checked, size: 18, color: Colors.green[400]), const SizedBox(width: 8), Expanded(child: Text(_ride.pickupAddress ?? '—', style: TextStyle(color: Colors.grey[300])))],
                    ),
                    const SizedBox(height: 8),
                    Row(children: [Icon(Icons.place, size: 18, color: Colors.red[400]), const SizedBox(width: 8), Expanded(child: Text(_ride.destinationAddress ?? '—', style: TextStyle(color: Colors.grey[300])))],
                    ),
                    const Divider(height: 24),
                    Text('Valor estimado: ${_ride.formattedPrice ?? "—"}', style: TextStyle(color: Colors.grey[400])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_ride.isAccepted) ...[
              FilledButton.icon(
                icon: const Icon(Icons.location_on),
                label: const Text('Cheguei na origem'),
                onPressed: _loading ? null : _markArrived,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ],
            if (_ride.isDriverArrived) ...[
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar viagem'),
                onPressed: _loading ? null : _startRide,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ],
            if (_ride.isInProgress) ...[
              FilledButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Finalizar corrida'),
                onPressed: _loading ? null : _showCompleteDialog,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.cancel),
              label: const Text('Cancelar corrida'),
              onPressed: _loading ? null : _cancelRide,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
            if (_loading) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'accepted':
        return 'A caminho da origem';
      case 'driver_arrived':
        return 'Chegou na origem';
      case 'in_progress':
        return 'Viagem em andamento';
      default:
        return 'Corrida';
    }
  }
}
