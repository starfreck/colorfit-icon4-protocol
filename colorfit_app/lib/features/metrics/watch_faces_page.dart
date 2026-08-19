import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/protocol/parser.dart';
import '../../core/providers/ble_provider.dart';
import '../../core/watchface/watch_face_renderer.dart';

class WatchFacesPage extends ConsumerStatefulWidget {
  const WatchFacesPage({super.key});

  @override
  ConsumerState<WatchFacesPage> createState() => _WatchFacesPageState();
}

class _WatchFacesPageState extends ConsumerState<WatchFacesPage> {
  int _selectedIndex = 0;
  bool _isLoading = false;
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    _renderPreview();
  }

  Future<void> _renderPreview() async {
    final bytes = await WatchFaceRenderer.renderToPng(
      style: defaultWatchFaces[_selectedIndex],
      time: DateTime.now(),
      width: 300,
      height: 300,
      healthData: {'steps': 8432, 'bpm': 72, 'battery': 85},
    );
    if (mounted) setState(() => _previewBytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text('Watch Faces', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0F0F0F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Preview
          Container(
            height: 320,
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2A2A2A), width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _previewBytes != null
                    ? Image.memory(_previewBytes!, fit: BoxFit.cover)
                    : const Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
              ),
            ),
          ),

          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Built-in Faces', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate, size: 18, color: Color(0xFF1DB954)),
                  label: Text('Custom', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1DB954))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Watch face grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: defaultWatchFaces.length,
              itemBuilder: (context, index) {
                final face = defaultWatchFaces[index];
                final isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = index);
                    _renderPreview();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1DB954) : const Color(0xFF2A2A2A),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: _FaceThumbnail(style: face),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Text(face.name, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(face.description, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Apply button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _applyWatchFace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Apply', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400);
    if (image != null) {
      setState(() => _previewBytes = null);
      final bytes = await image.readAsBytes();
      if (mounted) setState(() => _previewBytes = bytes);
    }
  }

  Future<void> _applyWatchFace() async {
    final service = ref.read(bleServiceProvider);
    if (!service.isReady) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not connected to watch')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Send photo watch face type (type=1)
      await service.sendPacket(ProtocolParser.buildSwitchWatchFace(1));
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${defaultWatchFaces[_selectedIndex].name} watch face applied'),
            backgroundColor: const Color(0xFF1DB954),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _FaceThumbnail extends StatelessWidget {
  final WatchFaceStyle style;
  const _FaceThumbnail({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        gradient: style.backgroundType == BackgroundType.gradient
            ? LinearGradient(
                colors: style.gradientColors,
                begin: style.gradientStart,
                end: style.gradientEnd,
              )
            : null,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: style.timeColor,
                fontSize: 24,
                fontWeight: style.timeFontWeight,
                letterSpacing: style.timeLetterSpacing,
              ),
            ),
            if (style.showDate)
              Text(
                '${DateTime.now().day}',
                style: TextStyle(color: style.dateColor, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}
