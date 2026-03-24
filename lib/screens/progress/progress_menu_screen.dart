import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pressfit/theme/app_theme.dart';

class ProgressMenuScreen extends StatelessWidget {
  const ProgressMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = [
      _ProgressItem(icon: Icons.calendar_view_month, title: 'Progreso Mensual', subtitle: 'Vista general de tu mes', route: '/progress/monthly'),
      _ProgressItem(icon: Icons.date_range, title: 'Progreso Semanal', subtitle: 'Resumen de tu semana', route: '/progress/weekly'),
      _ProgressItem(icon: Icons.today, title: 'Progreso Diario', subtitle: 'Detalles de hoy', route: '/progress/daily'),
      _ProgressItem(icon: Icons.fitness_center, title: 'Progreso por Ejercicio', subtitle: 'Evolución en cada ejercicio', route: '/progress/exercises'),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text('Progreso',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withAlpha(25)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return GestureDetector(
                    onTap: () => context.go(item.route),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withAlpha(25)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(51),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(item.icon, size: 28, color: AppColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                                Text(item.subtitle, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios, size: 20, color: theme.textTheme.bodyMedium?.color),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  _ProgressItem({required this.icon, required this.title, required this.subtitle, required this.route});
}
