import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/exercise_service.dart';
import 'package:pressfit/theme/app_theme.dart';

class PersonalNoteButton extends StatefulWidget {
  final String exerciseId;

  const PersonalNoteButton({super.key, required this.exerciseId});

  @override
  State<PersonalNoteButton> createState() => _PersonalNoteButtonState();
}

class _PersonalNoteButtonState extends State<PersonalNoteButton> {
  String? _note;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  Future<void> _loadNote() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    final note = await ExerciseService.getPersonalNote(userId, widget.exerciseId);
    if (mounted) setState(() => _note = note);
  }

  void _showNoteEditor() {
    final controller = TextEditingController(text: _note ?? '');
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Nota Personal',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 150,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Escribe tu nota sobre este ejercicio...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final userId = context.read<AuthProvider>().user?.id;
                  if (userId == null) return;
                  Navigator.pop(ctx);
                  await ExerciseService.savePersonalNote(userId, widget.exerciseId, controller.text);
                  if (mounted) setState(() => _note = controller.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasNote = _note?.isNotEmpty == true;

    return GestureDetector(
      onTap: _showNoteEditor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: hasNote ? AppColors.warning.withAlpha(30) : theme.dividerColor.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: hasNote ? AppColors.warning.withAlpha(60) : theme.dividerColor.withAlpha(50)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasNote ? Icons.note : Icons.note_add,
              size: 16,
              color: hasNote ? AppColors.warning : theme.textTheme.bodyMedium?.color,
            ),
            if (hasNote) ...[
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  _note!,
                  style: TextStyle(fontSize: 11, color: theme.textTheme.bodyMedium?.color),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
