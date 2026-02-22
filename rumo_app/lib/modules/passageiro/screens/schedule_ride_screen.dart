import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:rumo_app/modules/passageiro/screens/request_ride_screen.dart';

/// Tela para agendar viagem (data e hora). Abre RequestRideScreen com data/hora selecionada.
class ScheduleRideScreen extends StatefulWidget {
  const ScheduleRideScreen({super.key});

  @override
  State<ScheduleRideScreen> createState() => _ScheduleRideScreenState();
}

class _ScheduleRideScreenState extends State<ScheduleRideScreen> {
  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTime;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(hours: 1));
    _scheduledDate = tomorrow;
    _scheduledTime = TimeOfDay(hour: tomorrow.hour, minute: tomorrow.minute);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() => _scheduledDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      ));
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _scheduledTime = picked;
        _scheduledDate = DateTime(
          _scheduledDate.year,
          _scheduledDate.month,
          _scheduledDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _continue() {
    final dt = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );
    if (dt.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agende pelo menos 30 minutos à frente.')),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RequestRideScreen(scheduledAt: dt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMM', 'pt_BR').format(_scheduledDate);
    final timeStr = _scheduledTime.format(context);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Agendar viagem'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Quando você precisa da corrida?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 24),
              Material(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: const Color(0xFF00D95F), size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Data',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
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
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _selectTime,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: const Color(0xFF00D95F), size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Horário',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeStr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
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
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00D95F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
