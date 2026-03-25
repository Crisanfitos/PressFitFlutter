import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/providers/theme_provider.dart';
import 'package:pressfit/services/user_service.dart';
import 'package:pressfit/services/progress_service.dart';
import 'package:pressfit/models/foto_progreso.dart';
import 'package:pressfit/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _uploadingPhoto = false;
  Map<String, dynamic>? _metrics;
  String? _userName;
  String? _userEmail;
  String? _userPhotoUrl;
  List<FotoProgreso> _progressPhotos = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null) return;

    _userName = auth.user?.userMetadata?['full_name'] as String?;
    _userEmail = auth.user?.email;
    _userPhotoUrl = auth.user?.userMetadata?['custom_avatar_url'] as String? ??
        auth.user?.userMetadata?['avatar_url'] as String?;

    try {
      final metrics = await UserService.getUserMetrics(userId);
      final photos = await ProgressService.getProgressPhotos(userId);
      if (mounted) {
        setState(() {
          _metrics = metrics;
          _progressPhotos = photos.take(4).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Perfil',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 24),

                  // Profile card
                  _buildProfileCard(theme),
                  const SizedBox(height: 20),

                  // Metrics
                  _buildMetricsCard(theme),
                  const SizedBox(height: 20),

                  // Progress photos preview
                  if (_progressPhotos.isNotEmpty) ...[
                    _buildProgressPhotosPreview(theme),
                    const SizedBox(height: 20),
                  ],

                  // Ver Cambio Físico button
                  OutlinedButton.icon(
                    onPressed: () => context.go('/profile/physical-progress'),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Ver Cambio Físico'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Edit metrics button
                  OutlinedButton.icon(
                    onPressed: () => _showEditMetricsDialog(theme),
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar Métricas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Settings section
                  _buildSettingsSection(theme, themeProvider),
                  const SizedBox(height: 20),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar Sesión'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleChangeAvatar() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 80);
    if (image == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await UserService.uploadProfilePhoto(userId, image.path);
      if (url != null && mounted) {
        setState(() => _userPhotoUrl = url);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir foto')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Widget _buildProfileCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _uploadingPhoto ? null : _handleChangeAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withAlpha(51),
                  backgroundImage: _userPhotoUrl != null ? NetworkImage(_userPhotoUrl!) : null,
                  child: _uploadingPhoto
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : _userPhotoUrl == null
                          ? Text(
                              (_userName ?? _userEmail ?? '?')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                            )
                          : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'Usuario',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail ?? '',
                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressPhotosPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fotos de Progreso',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
              TextButton(
                onPressed: () => context.go('/profile/physical-progress'),
                child: const Text('Ver todas'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _progressPhotos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final photo = _progressPhotos[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    photo.urlFoto,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, error, stack) => Container(
                      width: 80,
                      height: 80,
                      color: theme.cardTheme.color,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(ThemeData theme) {
    final weight = (_metrics?['peso'] as num?)?.toDouble();
    final heightM = (_metrics?['altura'] as num?)?.toDouble();
    final heightCm = heightM != null ? (heightM * 100).round() : null;
    final imc = (_metrics?['imc'] as num?)?.toDouble();
    final bodyFat = (_metrics?['grasa_corporal'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Métricas Corporales',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricItem(theme, 'Peso', weight != null ? '${weight.toStringAsFixed(1)} kg' : '-', Icons.monitor_weight)),
              Expanded(child: _buildMetricItem(theme, 'Altura', heightCm != null ? '$heightCm cm' : '-', Icons.height)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetricItem(theme, 'IMC', imc != null ? imc.toStringAsFixed(1) : '-', Icons.speed)),
              Expanded(child: _buildMetricItem(theme, 'Grasa Corp.', bodyFat != null ? '${bodyFat.toStringAsFixed(1)}%' : '-', Icons.percent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(ThemeData theme, String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
          Text(label, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(ThemeData theme, ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.dark_mode, color: AppColors.primary),
            title: Text('Tema Oscuro', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
            trailing: Switch(
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
              activeThumbColor: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditMetricsDialog(ThemeData theme) {
    final weightCtrl = TextEditingController(
        text: (_metrics?['peso'] as num?)?.toStringAsFixed(1) ?? '');
    final heightCtrl = TextEditingController(
        text: (_metrics?['altura'] as num?) != null
            ? ((_metrics!['altura'] as num).toDouble() * 100).round().toString()
            : '');
    final bodyFatCtrl = TextEditingController(
        text: (_metrics?['grasa_corporal'] as num?)?.toStringAsFixed(1) ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Métricas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Peso (kg)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: heightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Altura (cm)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyFatCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Grasa Corporal (%)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final weight = double.tryParse(weightCtrl.text);
              final heightCm = double.tryParse(heightCtrl.text);
              if (weight == null || heightCm == null) return;

              final userId = context.read<AuthProvider>().user?.id;
              if (userId == null) return;

              Navigator.pop(ctx);
              setState(() => _loading = true);

              await UserService.saveUserMetrics(
                userId,
                weight: weight,
                heightCm: heightCm,
                bodyFatPercentage: double.tryParse(bodyFatCtrl.text),
              );
              await _loadProfile();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().signOut();
    }
  }
}
