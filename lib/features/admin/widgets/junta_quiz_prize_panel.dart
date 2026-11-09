import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/pick_gallery_image.dart';
import '../../../core/widgets/cofradeo_network_image.dart';
import '../../quiz/models/quiz_models.dart';
import '../../quiz/quiz_provider.dart';
import '../junta_ui.dart';

/// Ficha editable del premio de un mes. El interruptor lo muestra o lo oculta.
class JuntaQuizPrizePanel extends ConsumerStatefulWidget {
  const JuntaQuizPrizePanel({super.key});

  @override
  ConsumerState<JuntaQuizPrizePanel> createState() =>
      _JuntaQuizPrizePanelState();
}

class _JuntaQuizPrizePanelState extends ConsumerState<JuntaQuizPrizePanel> {
  late String _month;
  final _sponsor = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  var _active = false;
  DateTime? _claimUntil;
  String? _imageUrl;
  Uint8List? _newImage;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _month = quizYearMonthOf(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _sponsor.dispose();
    _title.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  List<String> get _months {
    final now = DateTime.now();
    return [
      for (var delta = -1; delta <= 2; delta++)
        quizYearMonthOf(DateTime(now.year, now.month + delta)),
    ];
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prize = await ref.read(quizRepositoryProvider).fetchPrize(_month);
      if (!mounted) return;
      _sponsor.text = prize?.sponsorName ?? '';
      _title.text = prize?.title ?? '';
      _description.text = prize?.description ?? '';
      _address.text = prize?.address ?? '';
      _active = prize?.active ?? false;
      _claimUntil = prize?.claimUntil;
      _imageUrl = prize?.imageUrl;
      _newImage = null;
    } catch (e) {
      if (mounted) {
        _error = 'No se pudo cargar. Ejecuta quiz_prizes.sql. ($e)';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await pickGalleryImage(maxWidth: 1600);
    if (file == null || !mounted) return;
    setState(() => _newImage = file.bytes);
  }

  Future<void> _pickUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _claimUntil ?? now,
      firstDate: DateTime(now.year, now.month - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Recoger hasta',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (picked == null || !mounted) return;
    setState(() => _claimUntil = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var imageUrl = _imageUrl;
      final bytes = _newImage;
      if (bytes != null) {
        imageUrl = await ref.read(quizRepositoryProvider).uploadPrizeImage(
              yearMonth: _month,
              bytes: bytes,
            );
      }
      await ref.read(quizRepositoryProvider).savePrize(
            QuizPrize(
              yearMonth: _month,
              active: _active,
              sponsorName: _sponsor.text,
              title: _title.text,
              description: _description.text,
              imageUrl: imageUrl,
              address: _address.text,
              claimUntil: _claimUntil,
            ),
          );
      ref.invalidate(quizPrizeShowcaseProvider);
      if (!mounted) return;
      setState(() {
        _imageUrl = imageUrl;
        _newImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_active ? 'Premio visible' : 'Premio oculto'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudo guardar. Ejecuta quiz_prizes.sql. ($e)';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _newImage;
    final url = _imageUrl?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Premio del mes', style: JuntaUi.sectionTitle()),
          const SizedBox(height: 4),
          Text(
            'Si está activo, se ve en la pregunta y en el ranking.',
            style: JuntaUi.caption(),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _month,
            decoration: const InputDecoration(
              labelText: 'Mes',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final month in _months)
                DropdownMenuItem(
                  value: month,
                  child: Text(quizMonthLabel(month)),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null || value == _month) return;
                    setState(() => _month = value);
                    _load();
                  },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Premio activo'),
            subtitle: Text(
              _active ? 'Visible para quien juega' : 'Oculto',
              style: JuntaUi.caption(),
            ),
            value: _active,
            onChanged: _saving ? null : (value) => setState(() => _active = value),
          ),
          if (_loading)
            const LinearProgressIndicator(minHeight: 2)
          else ...[
            TextField(
              controller: _sponsor,
              decoration: const InputDecoration(
                labelText: 'Local',
                hintText: 'Inciensos Sevilla',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Premio',
                hintText: 'Lote de incienso',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalle',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Dónde recogerlo',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _pickUntil,
                    child: Text(
                      _claimUntil == null
                          ? 'Sin fecha límite'
                          : 'Hasta ${_claimUntil!.day}/${_claimUntil!.month}',
                    ),
                  ),
                ),
                if (_claimUntil != null)
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _claimUntil = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: photo != null
                        ? Image.memory(photo, fit: BoxFit.cover)
                        : url.isEmpty
                            ? const ColoredBox(
                                color: AppColors.backgroundElevated,
                                child: Icon(Icons.storefront_outlined),
                              )
                            : CofradeoNetworkImage(url: url, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickPhoto,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Foto del local'),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: JuntaUi.caption(color: AppColors.accentRed),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar premio'),
            ),
          ],
        ],
      ),
    );
  }
}
