import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:rumo_app/core/models/ride_list_item.dart';
import 'package:rumo_app/core/services/api_service.dart';

import 'ride_receipt_screen.dart';
import 'waiting_for_driver_screen.dart';

/// Aba Atividade do passageiro – histórico de corridas.
class PassageiroActivityScreen extends StatefulWidget {
  const PassageiroActivityScreen({super.key});

  @override
  State<PassageiroActivityScreen> createState() => _PassageiroActivityScreenState();
}

class _PassageiroActivityScreenState extends State<PassageiroActivityScreen> {
  final _api = ApiService();
  List<RideListItem> _rides = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // 'all' | 'completed' | 'cancelled'

  static const _pendingStatuses = ['requested', 'accepted', 'driver_arrived', 'in_progress'];

  List<RideListItem> get _filteredRides {
    switch (_filter) {
      case 'completed':
        return _rides.where((r) => r.status == 'completed').toList();
      case 'cancelled':
        return _rides.where((r) => r.status == 'cancelled').toList();
      default:
        return _rides;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadRides();
  }

  Future<void> _loadRides() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listRides();
      if (!mounted) return;
      list.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      setState(() {
        _rides = list;
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

  void _openRide(RideListItem r) {
    if (r.status == 'completed') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideReceiptScreen(rideId: r.id),
        ),
      );
    } else if (_pendingStatuses.contains(r.status)) {
      _api.getRide(r.id).then((ride) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WaitingForDriverScreen(
              ride: ride,
              formattedPrice: r.formattedPrice,
            ),
          ),
        ).then((_) => _loadRides());
      }).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Atividade',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (!_loading && _rides.isNotEmpty) ...[
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todas',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Finalizadas',
                        selected: _filter == 'completed',
                        onTap: () => setState(() => _filter = 'completed'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Canceladas',
                        selected: _filter == 'cancelled',
                        onTap: () => setState(() => _filter = 'cancelled'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadRides,
            color: const Color(0xFF00D95F),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorContent()
                    : _rides.isEmpty
                        ? _buildEmptyContent()
                        : _filteredRides.isEmpty
                            ? _buildFilterEmptyContent()
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                itemCount: _filteredRides.length,
                                itemBuilder: (context, index) {
                                  final r = _filteredRides[index];
                                  return _RideCard(ride: r, onTap: () => _openRide(r));
                                },
                              ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Colors.red[300]), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _loadRides,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey[500]),
              const SizedBox(height: 16),
              Text(
                'Nenhuma corrida ainda',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Suas corridas aparecerão aqui',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterEmptyContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.filter_list_off, size: 64, color: Colors.grey[500]),
              const SizedBox(height: 16),
              Text(
                _filter == 'completed'
                    ? 'Nenhuma corrida finalizada'
                    : 'Nenhuma corrida cancelada',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF00D95F).withValues(alpha: 0.2) : const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? const Color(0xFF00D95F) : Colors.grey[400],
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  final RideListItem ride;
  final VoidCallback onTap;

  const _RideCard({required this.ride, required this.onTap});

  String get _statusLabel {
    switch (ride.status) {
      case 'requested':
        return 'Aguardando motorista';
      case 'accepted':
        return 'Motorista a caminho';
      case 'driver_arrived':
        return 'Motorista chegou';
      case 'in_progress':
        return 'Em andamento';
      case 'completed':
        return 'Finalizada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return ride.status;
    }
  }

  Color get _statusColor {
    switch (ride.status) {
      case 'completed':
        return const Color(0xFF00D95F);
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
      case 'driver_arrived':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = ride.createdAt != null
        ? DateFormat('dd/MM/yyyy • HH:mm', 'pt_BR').format(ride.createdAt!)
        : '—';
    final canTap = ['requested', 'accepted', 'driver_arrived', 'in_progress', 'completed'].contains(ride.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: canTap ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel,
                        style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      dateStr,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.radio_button_checked, size: 14, color: Colors.green[400]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ride.pickupAddress,
                        style: TextStyle(color: Colors.grey[300], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.place, size: 14, color: Colors.red[400]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ride.destinationAddress,
                        style: TextStyle(color: Colors.grey[300], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ride.formattedPrice,
                  style: const TextStyle(
                    color: Color(0xFF00D95F),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
