import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_upload_compress.dart';
import '../../core/widgets/cofradeo_avatar.dart';
import '../../shared/models/user_profile.dart';
import '../auth/auth_provider.dart';
import 'data/profile_repository.dart';
import 'profile_design.dart';
import 'profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _addressController = TextEditingController();
  final _foundedController = TextEditingController();
  final _websiteController = TextEditingController();
  final _picker = ImagePicker();

  bool _loading = false;
  bool _uploadingAvatar = false;
  bool _initialized = false;
  String? _error;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _bioController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user == null && mounted) {
        context.push(
          '/login?redirect=${Uri.encodeComponent('/perfil/editar')}',
        );
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _foundedController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  void _initFields(UserProfile profile) {
    if (_initialized) return;
    _displayNameController.text = profile.displayName;
    _bioController.text = profile.bio;
    _addressController.text = profile.address;
    _foundedController.text = profile.foundedLabel;
    _websiteController.text = profile.website;
    _avatarUrl = profile.avatarUrl;
    _initialized = true;
  }

  Future<void> _pickAvatar() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });

    try {
      final raw = await file.readAsBytes();
      final compressed = await compressImageForUploadAsync(
        raw,
        maxBytes: ImageUploadLimits.avatarMaxBytes,
        maxSide: ImageUploadLimits.avatarMaxSide,
      );

      if (mounted && compressed.wasCompressed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Avatar optimizado (${formatImageSize(raw.length)} → '
              '${formatImageSize(compressed.bytes.length)})',
            ),
          ),
        );
      }

      final url = await ref.read(profileRepositoryProvider).uploadAvatar(
            userId: user.id,
            bytes: compressed.bytes,
            mimeType: compressed.mimeType,
          );

      setState(() => _avatarUrl = url);
      ref.invalidate(currentUserProfileProvider);
    } on ImageTooLargeAfterCompressException {
      setState(() => _error = 'La imagen es demasiado grande. Prueba con otra.');
    } on ProfileUnavailableException {
      setState(() => _error = 'Configura Supabase y el bucket avatars.');
    } catch (_) {
      setState(() => _error = 'No se pudo subir la imagen.');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final name = _displayNameController.text.trim();
    final bio = _bioController.text.trim();

    if (name.length < 2 || name.length > 40) {
      setState(() => _error = 'El nombre debe tener entre 2 y 40 caracteres.');
      return;
    }
    if (bio.length > 160) {
      setState(() => _error = 'La bio no puede superar 160 caracteres.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: user.id,
            displayName: name,
            bio: bio,
            address: _addressController.text,
            foundedLabel: _foundedController.text,
            website: _websiteController.text,
          );
      ref.invalidate(currentUserProfileProvider);
      if (mounted) context.pop();
    } on ProfileUnavailableException {
      setState(() => _error = 'Configura Supabase para guardar el perfil.');
    } catch (_) {
      setState(() => _error = 'No se pudo guardar el perfil.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TextStyle get _fieldLabelStyle => AppTypography.labelSmall(
        color: AppColors.burgundy,
      ).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      );

  TextStyle get _fieldValueStyle => AppTypography.bodyLarge().copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  InputDecoration _borderlessField({String? hint}) => InputDecoration(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: hint,
        hintStyle: AppTypography.bodyMedium(color: AppColors.textMuted)
            .copyWith(fontSize: 15),
        contentPadding: EdgeInsets.zero,
        counterText: '',
      );

  Widget _fieldDivider() => Padding(
        padding: const EdgeInsets.only(left: 48),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border.withValues(alpha: 0.75),
        ),
      );

  Widget _profileFieldRow({
    required IconData icon,
    required String label,
    required Widget field,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.burgundy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: _fieldLabelStyle)),
                    if (trailing != null)
                      Text(
                        trailing,
                        style: AppTypography.labelSmall(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                field,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.burgundy,
                      size: 30,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'EDITAR PERFIL',
                      textAlign: TextAlign.center,
                      style: AppTypography.screenAppBarTitle().copyWith(
                        fontSize: 24,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Guardar',
                            style: AppTypography.bodyMedium(
                              color: AppColors.burgundy,
                            ).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Error al cargar perfil')),
                data: (profile) {
                  _initFields(profile);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      Text(
                        'Actualiza tu información para que la comunidad '
                        'pueda conocerte mejor.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(
                          color: AppColors.textSecondary,
                        ).copyWith(fontSize: 14, height: 1.45),
                      ),
                      const SizedBox(height: 22),
                      Center(
                        child: GestureDetector(
                          onTap: _uploadingAvatar ? null : _pickAvatar,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CofradeoAvatar(
                                imageUrl: _avatarUrl,
                                icon: profile.avatarIcon,
                                size: 104,
                                backgroundColor: AppColors.burgundyDark,
                              ),
                              if (_uploadingAvatar)
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.textOnDark,
                                      ),
                                    ),
                                  ),
                                ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.border,
                                      width: 1.2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.textPrimary
                                            .withValues(alpha: 0.08),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 17,
                                    color: AppColors.burgundy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: _uploadingAvatar ? null : _pickAvatar,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.burgundy,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                          child: Text(
                            'Cambiar foto',
                            style: AppTypography.bodyMedium(
                              color: AppColors.burgundy,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      DecoratedBox(
                        decoration: ProfileDesign.cardDecoration(),
                        child: Column(
                          children: [
                            _profileFieldRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Nombre visible',
                              field: TextField(
                                controller: _displayNameController,
                                style: _fieldValueStyle,
                                textInputAction: TextInputAction.next,
                                decoration: _borderlessField(),
                              ),
                            ),
                            _fieldDivider(),
                            _profileFieldRow(
                              icon: Icons.edit_outlined,
                              label: 'Bio',
                              trailing: '${_bioController.text.length}/160',
                              field: TextField(
                                controller: _bioController,
                                style: _fieldValueStyle,
                                maxLines: 3,
                                minLines: 1,
                                maxLength: 160,
                                textInputAction: TextInputAction.newline,
                                decoration: _borderlessField(
                                  hint: 'Cuéntanos algo sobre ti…',
                                ),
                              ),
                            ),
                            _fieldDivider(),
                            _profileFieldRow(
                              icon: Icons.location_on_outlined,
                              label: 'Dirección',
                              field: TextField(
                                controller: _addressController,
                                style: _fieldValueStyle,
                                textInputAction: TextInputAction.next,
                                decoration: _borderlessField(
                                  hint: 'Añade tu ciudad o localidad',
                                ),
                              ),
                            ),
                            _fieldDivider(),
                            _profileFieldRow(
                              icon: Icons.calendar_today_outlined,
                              label: 'Fundación',
                              field: TextField(
                                controller: _foundedController,
                                style: _fieldValueStyle,
                                textInputAction: TextInputAction.next,
                                decoration: _borderlessField(
                                  hint: 'Año de fundación (opcional)',
                                ),
                              ),
                            ),
                            _fieldDivider(),
                            _profileFieldRow(
                              icon: Icons.language_outlined,
                              label: 'Sitio web',
                              field: TextField(
                                controller: _websiteController,
                                style: _fieldValueStyle,
                                keyboardType: TextInputType.url,
                                textInputAction: TextInputAction.done,
                                decoration: _borderlessField(
                                  hint: 'https://tuweb.com (opcional)',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Handle ${profile.handle} — cambio limitado en versión futura.',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSmall(
                          color: AppColors.textMuted,
                        ).copyWith(fontSize: 12, height: 1.4),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium(
                            color: AppColors.accentRed,
                          ),
                        ),
                      ],
                    ],
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
