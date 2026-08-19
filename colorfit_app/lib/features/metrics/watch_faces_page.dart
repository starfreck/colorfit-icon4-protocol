import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
  double _uploadProgress = 0.0;
  String _statusText = 'Apply';
  Uint8List? _previewBytes;
  Uint8List? _customPhotoBytes;

  @override
  void initState() {
    super.initState();
    _renderPreview();
  }

  Future<void> _renderPreview() async {
    final bytes = await WatchFaceRenderer.renderToPng(
      style: defaultWatchFaces[_selectedIndex],
      time: DateTime.now(),
      width: 240,
      height: 280,
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
                width: 240,
                height: 280,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
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
                Text('Custom & Built-in Designs', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
                TextButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_photo_alternate, size: 18, color: Color(0xFF1DB954)),
                  label: Text('Photo', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF1DB954))),
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
                final isSelected = _selectedIndex == index && _customPhotoBytes == null;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                      _customPhotoBytes = null;
                    });
                    _renderPreview();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1DB954) : const Color(0xFF2A2A2A),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            child: _FaceThumbnail(style: defaultWatchFaces[index]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            defaultWatchFaces[index].name,
                            style: GoogleFonts.inter(
                              color: isSelected ? const Color(0xFF1DB954) : Colors.white,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
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
            child: Column(
              children: [
                if (_isLoading) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
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
                        ? Text(_statusText, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15))
                        : Text('Apply to Watch', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ],
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
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _customPhotoBytes = bytes;
          _previewBytes = bytes;
        });
      }
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

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
      _statusText = 'Preparing design...';
    });

    try {
      Uint8List rgb565;
      if (_customPhotoBytes != null) {
        setState(() => _statusText = 'Processing photo...');
        rgb565 = await WatchFaceRenderer.convertImageToRGB565(_customPhotoBytes!, 240, 280);
      } else {
        setState(() => _statusText = 'Rendering ${defaultWatchFaces[_selectedIndex].name}...');
        rgb565 = await WatchFaceRenderer.renderToRGB565(
          style: defaultWatchFaces[_selectedIndex],
          time: DateTime.now(),
          width: 240,
          height: 280,
          healthData: {'steps': 8432, 'bpm': 72, 'battery': 85},
        );
      }

      setState(() => _statusText = 'Uploading to watch...');
      await service.uploadCustomWatchFace(
        rgb565,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              _statusText = 'Transferring ${(progress * 100).toInt()}%';
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${defaultWatchFaces[_selectedIndex].name} transferred & applied to watch!'),
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusText = 'Apply';
          _uploadProgress = 0.0;
        });
      }
    }
  }
}

class _FaceThumbnail extends StatelessWidget {
  final WatchFaceStyle style;
  const _FaceThumbnail({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
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
                fontSize: 20,
                fontWeight: style.timeFontWeight,
                letterSpacing: style.timeLetterSpacing,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateTime.now().day}',
              style: TextStyle(color: style.dateColor, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
