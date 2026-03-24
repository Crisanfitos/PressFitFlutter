import 'package:flutter/material.dart';
import 'package:pressfit/models/tipo_peso.dart';
import 'package:pressfit/theme/app_theme.dart';

class WeightTypeBadge extends StatelessWidget {
  final TipoPeso tipoPeso;
  final bool editable;
  final ValueChanged<TipoPeso>? onSelect;

  const WeightTypeBadge({
    super.key,
    required this.tipoPeso,
    this.editable = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: editable ? () => _showSelector(context, theme) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForType(tipoPeso), size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              tipoPeso.shortLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            if (editable) ...[
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForType(TipoPeso tipo) {
    switch (tipo) {
      case TipoPeso.total:
        return Icons.fitness_center;
      case TipoPeso.porLado:
        return Icons.sync_alt;
      case TipoPeso.corporal:
        return Icons.accessibility_new;
    }
  }

  void _showSelector(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Tipo de Peso',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
              ),
              ...TipoPeso.values.map((tipo) => ListTile(
                    leading: Icon(_iconForType(tipo),
                        color: tipo == tipoPeso ? AppColors.primary : theme.textTheme.bodyMedium?.color),
                    title: Text(tipo.label,
                        style: TextStyle(
                          color: tipo == tipoPeso ? AppColors.primary : theme.textTheme.bodyLarge?.color,
                          fontWeight: tipo == tipoPeso ? FontWeight.w600 : FontWeight.normal,
                        )),
                    trailing: tipo == tipoPeso ? const Icon(Icons.check, color: AppColors.primary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect?.call(tipo);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
