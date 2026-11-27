import 'package:flutter/material.dart';
import '../services/company_rating_service.dart';

class CompanyRatingDisplay extends StatelessWidget {
  const CompanyRatingDisplay({super.key, this.average, this.count = 0, this.compact = false});
  final double? average;
  final int count;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final value = average ?? 0;
    final color = Theme.of(context).colorScheme.tertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) => Icon(
          i < value.floor() ? Icons.star_rounded : (i == value.floor() && value - value.floor() >= .25 ? Icons.star_half_rounded : Icons.star_outline_rounded),
          size: compact ? 8 : 17,
          color: color,
        )),
        const SizedBox(width: 4),
        Text(
          compact ? (count == 0 ? '—' : value.toStringAsFixed(1)) : (count == 0 ? 'Sem avaliações' : '${value.toStringAsFixed(1)} ($count)'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: compact ? 9 : null),
        ),
      ],
    );
  }
}

class CompanyRatingLookup extends StatefulWidget {
  const CompanyRatingLookup({super.key, required this.companyId, this.compact = false});
  final String companyId;
  final bool compact;

  @override
  State<CompanyRatingLookup> createState() => _CompanyRatingLookupState();
}

class _CompanyRatingLookupState extends State<CompanyRatingLookup> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant CompanyRatingLookup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final rows = await CompanyRatingService().getStats([widget.companyId]);
    return rows[widget.companyId];
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: _future,
    builder: (context, snapshot) {
      final data = snapshot.data;
      return CompanyRatingDisplay(
        average: (data?['average_rating'] as num?)?.toDouble(),
        count: (data?['rating_count'] as num?)?.toInt() ?? 0,
        compact: widget.compact,
      );
    },
  );
}
