import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/reticles/reticle_definition.dart';
import 'reticle_canvas_painter.dart';
import 'reticle_preview_backdrop.dart';

/// Dürbün / hedef fotoğrafı üzerinde retikül + tutma (StreLok tarzı hizalama).
class ReticlePhotoSection extends StatefulWidget {
  final ReticleDefinition? reticle;
  final double holdUpUnits;
  final double holdLeftUnits;
  final bool unitIsMoa;

  const ReticlePhotoSection({
    super.key,
    required this.reticle,
    required this.holdUpUnits,
    required this.holdLeftUnits,
    required this.unitIsMoa,
  });

  @override
  State<ReticlePhotoSection> createState() => _ReticlePhotoSectionState();
}

class _ReticlePhotoSectionState extends State<ReticlePhotoSection> {
  Uint8List? _bytes;
  double _scale = 1.0;
  double _dx = 0;
  double _dy = 0;
  double _photoOpacity = 1.0;

  Future<void> _pick() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final b = await x.readAsBytes();
    setState(() {
      _bytes = b;
      _scale = 1.0;
      _dx = 0;
      _dy = 0;
    });
  }

  void _clear() => setState(() => _bytes = null);

  @override
  Widget build(BuildContext context) {
    final def = widget.reticle ??
        const ReticleDefinition(
          id: 'fallback',
          name: 'Genel MIL ızgara',
          manufacturer: '',
          unit: 'mil',
          pattern: 'hash',
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _pick,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Foto seç'),
            ),
            const SizedBox(width: 8),
            if (_bytes != null)
              TextButton(onPressed: _clear, child: const Text('Kaldır')),
          ],
        ),
        if (_bytes != null) ...[
          const SizedBox(height: 8),
          Text('Ölçek & hizalama (retikül çizimi üstte)', style: Theme.of(context).textTheme.labelLarge),
          Slider(
            label: _scale.toStringAsFixed(2),
            value: _scale.clamp(0.3, 4.0),
            min: 0.3,
            max: 4.0,
            onChanged: (v) => setState(() => _scale = v),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  label: _dx.toStringAsFixed(0),
                  value: _dx.clamp(-120, 120),
                  min: -120,
                  max: 120,
                  onChanged: (v) => setState(() => _dx = v),
                ),
              ),
              Expanded(
                child: Slider(
                  label: _dy.toStringAsFixed(0),
                  value: _dy.clamp(-120, 120),
                  min: -120,
                  max: 120,
                  onChanged: (v) => setState(() => _dy = v),
                ),
              ),
            ],
          ),
          Slider(
            label: _photoOpacity.toStringAsFixed(2),
            value: _photoOpacity,
            min: 0.25,
            max: 1.0,
            onChanged: (v) => setState(() => _photoOpacity = v),
          ),
        ],
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final s = math.min(c.maxWidth, 320.0);
            return SizedBox(
              width: s,
              height: s,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_bytes != null)
                      Opacity(
                        opacity: _photoOpacity,
                        child: Transform.translate(
                          offset: Offset(_dx, _dy),
                          child: Transform.scale(
                            scale: _scale,
                            alignment: Alignment.center,
                            child: Image.memory(
                              _bytes!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    else
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          const ReticlePreviewBackdrop(),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Foto yok — saha benzeri önizleme\n«Foto seç» ile net görüntü ekleyin',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  shadows: const [
                                    Shadow(blurRadius: 6, color: Color(0x66000000)),
                                    Shadow(blurRadius: 2, offset: Offset(0, 1), color: Color(0x99000000)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    CustomPaint(
                      painter: ReticleCanvasPainter(
                        def: def,
                        holdUpUnits: widget.holdUpUnits,
                        holdLeftUnits: widget.holdLeftUnits,
                        unitIsMoa: widget.unitIsMoa,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
