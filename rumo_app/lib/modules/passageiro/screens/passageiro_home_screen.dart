import 'dart:async';

import 'package:flutter/material.dart';

import 'package:rumo_app/core/models/ride_list_item.dart';
import 'package:rumo_app/core/services/api_service.dart';
import 'package:rumo_app/core/services/push_service.dart';

import 'help_screen.dart';
import 'schedule_ride_screen.dart';
import 'passageiro_account_screen.dart';
import 'passageiro_activity_screen.dart';
import 'passageiro_options_screen.dart';
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

      final seenDest = <String>{};
      final seenOrig = <String>{};
      final destinations = <_DestinationItem>[];
      final origins = <_DestinationItem>[];
      for (final r in list) {
        if (destinations.length < 5) {
          final addr = r.destinationAddress;
          if (addr.isNotEmpty && !seenDest.contains(addr)) {
            seenDest.add(addr);
            final title = addr.length > 45 ? '${addr.substring(0, 45)}...' : addr;
            destinations.add(_DestinationItem(
              title,
              addr,
              Icons.history,
              r.destinationLat,
              r.destinationLng,
            ));
          }
        }
        if (origins.length < 5) {
          final addr = r.pickupAddress;
          if (addr.isNotEmpty && !seenOrig.contains(addr)) {
            seenOrig.add(addr);
            final title = addr.length > 45 ? '${addr.substring(0, 45)}...' : addr;
            origins.add(_DestinationItem(
              title,
              addr,
              Icons.trip_origin,
              r.pickupLat,
              r.pickupLng,
            ));
          }
        }
      }
      if (destinations.isEmpty) {
        destinations.addAll(_fallbackDestinations);
      }

      setState(() {
        _pendingRide = pending.isNotEmpty ? pending.first : null;
        _recentDestinations = destinations;
        _recentOrigins = origins;
        if (!silent) _pendingLoading = false;
      });
      if (_pendingRide != null) {
        _startPendingPolling();
      } else {
        _pendingPollTimer?.cancel();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (_recentDestinations.isEmpty) _recentDestinations = List.from(_fallbackDestinations);
          if (!silent) _pendingLoading = false;
        });
      }
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

  List<_DestinationItem> _recentDestinations = List.from(_fallbackDestinations);
  List<_DestinationItem> _recentOrigins = [];
  static const _fallbackDestinations = [
    _DestinationItem('Sqs 303 - Bloco H', 'SHCS SQS 303 - Asa Sul, Brasília - DF', Icons.access_time, null, null),
    _DestinationItem('Aeroporto Internacional de Brasília', 'Lago Sul, Brasília - DF', Icons.flight, null, null),
  ];

  static const _sugestoesCards = [
    _SugestaoCard('Viagem', Icons.directions_car, true),
  ];

  void _openRequestRide({_DestinationItem? destination, _DestinationItem? origin}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestRideScreen(
          initialDestinationAddress: destination?.subtitle,
          initialDestinationLat: destination?.lat,
          initialDestinationLng: destination?.lng,
          initialPickupAddress: origin?.subtitle,
          initialPickupLat: origin?.lat,
          initialPickupLng: origin?.lng,
        ),
      ),
    ).then((_) => _loadPendingRide());
  }

  Widget _buildOriginTile(_DestinationItem d) {
    return InkWell(
      onTap: () => _openRequestRide(origin: d),
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

  Widget _buildHomeContent() {
    return RefreshIndicator(
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
            if (_recentOrigins.isNotEmpty) ...[
              Text(
                'Origens recentes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
              ..._recentOrigins.map((d) => _buildOriginTile(d)),
              const SizedBox(height: 16),
            ],
            Text(
              'Destinos recentes',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            ..._recentDestinations.map((d) => _buildDestinationTile(d)),
            const SizedBox(height: 24),
            _buildSugestoesSection(),
            const SizedBox(height: 24),
            _buildMaisFormasCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_currentIndex == 0) _buildHeader(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  _buildHomeContent(),
                  const PassageiroOptionsScreen(),
                  const PassageiroActivityScreen(),
                  const PassageiroAccountScreen(),
                ],
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
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ScheduleRideScreen()),
            ).then((_) => _loadPendingRide());
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
      onTap: () => _openRequestRide(destination: d),
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
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                    onTap: s.enabled ? () => _openRequestRide() : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(
                            s.icon,
                            color: s.enabled ? const Color(0xFF00D95F) : Colors.grey[400],
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
          'Ajuda',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Material(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HelpScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.help_outline, color: const Color(0xFF00D95F), size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Perguntas frequentes',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tire dúvidas sobre o uso do app',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[500]),
                ],
              ),
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
  final double? lat;
  final double? lng;
  const _DestinationItem(this.title, this.subtitle, this.icon, this.lat, this.lng);
}

class _SugestaoCard {
  final String label;
  final IconData icon;
  final bool enabled;
  const _SugestaoCard(this.label, this.icon, [this.enabled = true]);
}
