import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/ride_list_item.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/push_service.dart';

import 'request_ride_screen.dart';
import 'waiting_for_driver_screen.dart';

/// Home do módulo Passageiro no estilo combinado: "Para onde?", destinos recentes, sugestões e menu inferior.
class PassageiroHomeScreen extends StatefulWidget {
  const PassageiroHomeScreen({super.key});

  @override
  State<PassageiroHomeScreen> createState() => _PassageiroHomeScreenState();
}

class _PassageiroHomeScreenState extends State<PassageiroHomeScreen> {
  int _currentIndex = 0;
  final _api = ApiService();
  RideListItem? _pendingRide;
  bool _pendingLoading = true;
  bool _cancelling = false;
  Timer? _pendingPollTimer;

  static const _pendingStatuses = ['requested', 'accepted', 'driver_arrived', 'in_progress'];

  @override
  void initState() {
    super.initState();
    _loadPendingRide();
    PushService().ensureTokenRegistered(); // Registra FCM para push quando motorista aceita
  }

  @override
  void dispose() {
    _pendingPollTimer?.cancel();
    super.dispose();
  }

  void _startPendingPolling() {
    _pendingPollTimer?.cancel();
    if (_pendingRide == null) return;
    _pendingPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _loadPendingRide(silent: true);
    });
  }

  Future<void> _loadPendingRide({bool silent = false}) async {
    if (!silent) setState(() => _pendingLoading = true);
    try {
      final list = await _api.listRides();
      if (!mounted) return;
      final pending = list.where((r) => _pendingStatuses.contains(r.status)).toList();
      pending.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      setState(() {
        _pendingRide = pending.isNotEmpty ? pending.first : null;
        if (!silent) _pendingLoading = false;
      });
      if (_pendingRide != null) {
        _startPendingPolling();
      } else {
        _pendingPollTimer?.cancel();
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _pendingLoading = false);
    }
  }

  Future<void> _openWaitingScreen() async {
    if (_pendingRide == null) return;
    try {
      final ride = await _api.getRide(_pendingRide!.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WaitingForDriverScreen(
            ride: ride,
            formattedPrice: _pendingRide!.formattedPrice,
          ),
        ),
      ).then((_) => _loadPendingRide());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _cancelPendingRide() async {
    if (_pendingRide == null || _cancelling) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar corrida?'),
        content: const Text(
          'Deseja realmente cancelar esta solicitação? Você poderá solicitar uma nova corrida depois.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sim, cancelar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await _api.cancelRide(_pendingRide!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corrida cancelada.')));
      setState(() => _pendingRide = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  static const _recentDestinations = [
    _DestinationItem('Sqs 303 - Bloco H', 'SHCS SQS 303 - Asa Sul, Brasília - DF', Icons.access_time),
    _DestinationItem('Aeroporto Internacional de Brasília - Presidente Juscelino Kubitschek', 'Lago Sul, Brasília - DF', Icons.flight),
  ];

  static const _sugestoesCards = [
    _SugestaoCard('Viagem', Icons.directions_car),
    _SugestaoCard('Enviar itens', Icons.inventory_2_outlined),
    _SugestaoCard('Reserve', Icons.calendar_today_outlined),
    _SugestaoCard('Teens', Icons.person_outline),
  ];

  void _openRequestRide() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RequestRideScreen()),
    ).then((_) => _loadPendingRide());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadPendingRide,
                color: const Color(0xFF00D95F),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      if (!_pendingLoading && _pendingRide != null) _buildPendingRideBanner(),
                      if (!_pendingLoading && _pendingRide != null) const SizedBox(height: 12),
                      _buildSearchBar(),
                      const SizedBox(height: 24),
                      ..._recentDestinations.map((d) => _buildDestinationTile(d)),
                      const SizedBox(height: 24),
                      _buildSugestoesSection(),
                      const SizedBox(height: 24),
                      _buildMaisFormasCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRideBanner() {
    final r = _pendingRide!;
    final statusLabel = r.status == 'requested'
        ? 'Aguardando motorista aceitar'
        : r.status == 'accepted'
            ? 'Motorista a caminho'
            : r.status == 'driver_arrived'
                ? 'Motorista chegou'
                : 'Viagem em andamento';
    return Material(
      color: const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.amber[700], size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              r.pickupAddress,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              r.destinationAddress,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              r.formattedPrice,
              style: const TextStyle(color: Color(0xFF00D95F), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _cancelling ? null : _cancelPendingRide,
                  icon: _cancelling ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    side: BorderSide(color: Colors.red[400]!),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _openWaitingScreen,
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('Acompanhar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D95F),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          Text(
            'Rumo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: _openRequestRide,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[400], size: 22),
                  const SizedBox(width: 12),
                  Text(
                    'Para onde?',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Agendar viagem em breve')),
            );
          },
          icon: const Icon(Icons.calendar_today, size: 18),
          label: const Text('Mais tarde'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.grey[600]!),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationTile(_DestinationItem d) {
    return InkWell(
      onTap: _openRequestRide,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(d.icon, color: Colors.grey[400], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSugestoesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sugestões',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[500]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: _sugestoesCards.map((s) {
            final isViagem = s.label == 'Viagem';
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      if (isViagem) _openRequestRide();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(
                            s.icon,
                            color: isViagem ? const Color(0xFF00D95F) : Colors.grey[400],
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.label,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMaisFormasCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mais formas de usar o app',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'Em breve',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home, 'Página inicial', 0),
              _navItem(Icons.grid_view_rounded, 'Opções', 1),
              _navItem(Icons.receipt_long_outlined, 'Atividade', 2),
              _navItem(Icons.person_outline, 'Conta', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: selected ? const Color(0xFF00D95F) : Colors.grey[500],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? const Color(0xFF00D95F) : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationItem {
  final String title;
  final String subtitle;
  final IconData icon;
  const _DestinationItem(this.title, this.subtitle, this.icon);
}

class _SugestaoCard {
  final String label;
  final IconData icon;
  const _SugestaoCard(this.label, this.icon);
}
