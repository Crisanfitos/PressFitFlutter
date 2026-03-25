import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/progress_service.dart';
import 'package:pressfit/services/user_service.dart';
import 'package:pressfit/models/foto_progreso.dart';
import 'package:pressfit/theme/app_theme.dart';

class PhysicalProgressScreen extends StatefulWidget {
  const PhysicalProgressScreen({super.key});

  @override
  State<PhysicalProgressScreen> createState() => _PhysicalProgressScreenState();
}

class _PhysicalProgressScreenState extends State<PhysicalProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<FotoProgreso> _photos = [];
  List<Map<String, dynamic>> _weightHistory = [];
  bool _loading = true;
  bool _uploading = false;
  bool _selectionMode = false;
  final Set<String> _selectedPhotos = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final photos = await ProgressService.getProgressPhotos(userId);
      final weight = await UserService.getWeightHistory(userId, limit: 30);
      if (mounted) {
        setState(() {
          _photos = photos;
          _weightHistory = weight;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAddPhoto() async {
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

    // Show date/comment dialog
    DateTime selectedDate = DateTime.now();
    final commentCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nueva Foto de Progreso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(image.path),
                    height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setDialogState(() => selectedDate = date);
                  }
                },
                child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Fecha', border: OutlineInputBorder()),
                  child: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ProgressService.uploadProgressPhoto(
        userId,
        image.path,
        selectedDate,
        commentCtrl.text.trim(),
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _handleDeleteSelected() async {
    if (_selectedPhotos.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Fotos'),
        content: Text(
            '¿Eliminar ${_selectedPhotos.length} foto${_selectedPhotos.length > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ProgressService.deleteProgressPhotos(_selectedPhotos.toList());
      setState(() {
        _selectionMode = false;
        _selectedPhotos.clear();
      });
      _loadData();
    }
  }

  void _openPhotoViewer(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(
          photos: _photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // Group photos by month
  Map<String, List<FotoProgreso>> get _groupedPhotos {
    final grouped = <String, List<FotoProgreso>>{};
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    for (final photo in _photos) {
      final date = photo.createdAt;
      final key = '${months[date.month]} ${date.year}';
      grouped.putIfAbsent(key, () => []).add(photo);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('${_selectedPhotos.length} seleccionada${_selectedPhotos.length != 1 ? 's' : ''}')
            : const Text('Cambio Físico'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: _handleDeleteSelected,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectionMode = false;
                _selectedPhotos.clear();
              }),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Fotos'),
            Tab(text: 'Peso'),
          ],
        ),
      ),
      floatingActionButton: !_selectionMode
          ? FloatingActionButton(
              onPressed: _uploading ? null : _handleAddPhoto,
              backgroundColor: AppColors.primary,
              child: _uploading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_a_photo, color: Colors.white),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildPhotosTab(theme),
                _buildWeightTab(theme),
              ],
            ),
    );
  }

  Widget _buildPhotosTab(ThemeData theme) {
    if (_photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera,
                size: 64, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 16),
            Text('No hay fotos de progreso',
                style: TextStyle(
                    fontSize: 18, color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 8),
            Text('Añade tu primera foto para registrar tu progreso',
                style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
          ],
        ),
      );
    }

    final grouped = _groupedPhotos;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final monthKey = grouped.keys.elementAt(index);
        final monthPhotos = grouped[monthKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(monthKey,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.75,
              ),
              itemCount: monthPhotos.length,
              itemBuilder: (context, photoIdx) {
                final photo = monthPhotos[photoIdx];
                final globalIdx = _photos.indexOf(photo);
                final isSelected = _selectedPhotos.contains(photo.id);

                return GestureDetector(
                  onTap: _selectionMode
                      ? () {
                          setState(() {
                            if (isSelected) {
                              _selectedPhotos.remove(photo.id);
                              if (_selectedPhotos.isEmpty) {
                                _selectionMode = false;
                              }
                            } else {
                              _selectedPhotos.add(photo.id);
                            }
                          });
                        }
                      : () => _openPhotoViewer(globalIdx),
                  onLongPress: !_selectionMode
                      ? () {
                          setState(() {
                            _selectionMode = true;
                            _selectedPhotos.add(photo.id);
                          });
                        }
                      : null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          photo.urlFoto,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, error, stack) => Container(
                            color: theme.cardTheme.color,
                            child: const Icon(Icons.broken_image, size: 40),
                          ),
                        ),
                      ),
                      // Date overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withAlpha(178),
                              ],
                            ),
                          ),
                          child: Text(
                            '${photo.createdAt.day} de ${_monthName(photo.createdAt.month)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.primary.withAlpha(100),
                          ),
                          child: const Center(
                            child: Icon(Icons.check_circle,
                                color: Colors.white, size: 40),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildWeightTab(ThemeData theme) {
    if (_weightHistory.isEmpty) {
      return Center(
        child: Text('No hay datos de peso registrados',
            style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
      );
    }

    final spots = _weightHistory.asMap().entries.map((e) {
      final peso = (e.value['peso'] as num).toDouble();
      return FlSpot(e.key.toDouble(), peso);
    }).toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Historial de Peso',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 8),
          if (_weightHistory.isNotEmpty)
            Text(
              'Último: ${(_weightHistory.last['peso'] as num).toStringAsFixed(1)} kg',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withAlpha(50),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toStringAsFixed(0)} kg',
                        style: TextStyle(
                            fontSize: 10,
                            color: theme.textTheme.bodyMedium?.color),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withAlpha(30),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return names[month];
  }
}

class _PhotoViewer extends StatefulWidget {
  final List<FotoProgreso> photos;
  final int initialIndex;

  const _PhotoViewer({required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (ctx, index) {
                final photo = widget.photos[index];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      photo.urlFoto,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, error, stack) =>
                          const Icon(Icons.broken_image,
                              size: 64, color: Colors.white54),
                    ),
                  ),
                );
              },
            ),
          ),
          // Footer with date and comment
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(widget.photos[_currentIndex].createdAt),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                if (widget.photos[_currentIndex].comentario?.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.photos[_currentIndex].comentario!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${date.day} de ${months[date.month]} de ${date.year}';
  }
}
