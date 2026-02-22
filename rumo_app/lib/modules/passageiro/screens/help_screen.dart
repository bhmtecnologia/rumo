import 'package:flutter/material.dart';

/// Tela de Ajuda / FAQ.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    _FaqItem(
      'Como solicito uma corrida?',
      'Toque em "Para onde?" na página inicial, informe o endereço de destino e confirme. Um motorista parceiro será notificado e poderá aceitar sua corrida.',
    ),
    _FaqItem(
      'Posso cancelar uma corrida?',
      'Sim. Enquanto a corrida estiver aguardando aceite ou o motorista a caminho, você pode cancelar pela tela de acompanhamento.',
    ),
    _FaqItem(
      'Como funciona o centro de custo?',
      'Se sua empresa utiliza centros de custo, você poderá escolher qual usar ao solicitar a corrida. Você pode definir um padrão em Opções > Forma de pagamento.',
    ),
    _FaqItem(
      'O motorista não está chegando. O que fazer?',
      'Use o chat na tela de acompanhamento para entrar em contato com o motorista. Se necessário, você pode cancelar a corrida.',
    ),
    _FaqItem(
      'Como funciona a avaliação?',
      'Após finalizar a corrida, você será solicitado a avaliar o serviço de 1 a 5 estrelas. Sua avaliação ajuda a melhorar o atendimento.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Ajuda'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Perguntas frequentes',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ..._faqs.map((f) => _FaqCard(item: f)),
          const SizedBox(height: 24),
          Text(
            'Contato',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
              children: [
                Text(
                  'Dúvidas ou problemas? Entre em contato com o suporte da sua empresa.',
                  style: TextStyle(color: Colors.grey[300], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem(this.question, this.answer);
}

class _FaqCard extends StatefulWidget {
  final _FaqItem item;

  const _FaqCard({required this.item});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFF2C2C2C),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.item.question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.item.answer,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
