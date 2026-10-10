import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_decode_cache.dart';
import '../../core/utils/image_upload_compress.dart';
import '../../core/widgets/cofradeo_asset_image.dart';
import '../../core/widgets/cofradeo_avatar.dart';
import '../../core/widgets/cofradeo_network_image.dart';
import '../../core/constants/app_assets.dart';
import '../../shared/models/user_profile.dart';
import '../auth/auth_provider.dart';
import 'data/profile_repository.dart';
import 'profile_design.dart';
import 'profile_provider.dart';
import '../../core/widgets/cofradeo_skeleton.dart';

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
  bool _uploadingCover = false;
  bool _initialized = false;
  bool _isPrivate = false;
  String? _error;
  String? _avatarUrl;
  String? _coverImageUrl;

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
    _coverImageUrl = profile.coverImageUrl;
    _isPrivate = profile.isPrivate;
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

  Future<void> _pickCover() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() {
      _uploadingCover = true;
      _error = null;
    });

    try {
      final raw = await file.readAsBytes();
      final compressed = await compressImageForUploadAsync(
        raw,
        maxBytes: ImageUploadLimits.profileCoverMaxBytes,
        maxSide: ImageUploadLimits.profileCoverMaxSide,
      );

      if (mounted && compressed.wasCompressed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Portada optimizada (${formatImageSize(raw.length)} → '
              '${formatImageSize(compressed.bytes.length)})',
            ),
          ),
        );
      }

      final url = await ref.read(profileRepositoryProvider).uploadCover(
            userId: user.id,
            bytes: compressed.bytes,
            mimeType: compressed.mimeType,
          );

      setState(() => _coverImageUrl = url);
      ref.invalidate(currentUserProfileProvider);
    } on ImageTooLargeAfterCompressException {
      setState(() => _error = 'La portada es demasiado grande. Prueba con otra.');
    } on AvatarTooLargeException {
      setState(() => _error = 'La portada es demasiado grande. Prueba con otra.');
    } on ProfileUnavailableException {
      setState(() => _error = 'Configura Supabase y el bucket avatars.');
    } catch (_) {
      setState(() => _error = 'No se pudo subir la portada.');
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _clearCover() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() {
      _uploadingCover = true;
      _error = null;
    });

    try {
      await ref.read(profileRepositoryProvider).clearCover(userId: user.id);
      setState(() => _coverImageUrl = null);
      ref.invalidate(currentUserProfileProvider);
    } on ProfileUnavailableException {
      setState(() => _error = 'Configura Supabase para quitar la portada.');
    } catch (_) {
      setState(() => _error = 'No se pudo quitar la portada.');
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
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
            isPrivate: _isPrivate,
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
        padding: const EdgeInsets.only(left: 44),
        child: Divider(
          height: 1,
          thickness: 1,
          color: AppColors.border.withValues(alpha: 0.75),
        ),
      );

  bool get _hasCustomCover {
    final url = _coverImageUrl?.trim();
    return url != null && url.isNotEmpty && !url.startsWith('assets/');
  }

  Widget _coverPreview(BuildContext context) {
    if (_hasCustomCover) {
      return CofradeoNetworkImage(
        url: _coverImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheSize: ImageDecodeCache.px(
          context,
          MediaQuery.sizeOf(context).width,
        ).toDouble(),
      );
    }
    return CofradeoAssetImage(
      assetPath: AppAssets.profileHeaderCover,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.15),
      cacheWidth: ImageDecodeCache.px(
        context,
        MediaQuery.sizeOf(context).width,
      ),
      fadeDuration: const Duration(milliseconds: 320),
    );
  }

  Widget _profileFieldRow({
    required IconData icon,
    required String label,
    required Widget field,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.burgundy),
          ),
          const SizedBox(width: 10),
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
                        ).copyWith(fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                field,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarEditor({required IconData avatarIcon}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _uploadingAvatar ? null : _pickAvatar,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CofradeoAvatar(
                imageUrl: _avatarUrl,
                icon: avatarIcon,
                size: 84,
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
                right: -2,
                bottom: -2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.border,
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    size: 14,
                    color: AppColors.burgundy,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _uploadingAvatar ? null : _pickAvatar,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.burgundy,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Foto',
            style: AppTypography.bodyMedium(
              color: AppColors.burgundy,
            ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _coverEditor(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 16 / 6.5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _coverPreview(context),
                if (_uploadingCover)
                  const ColoredBox(
                    color: Colors.black38,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnDark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _uploadingCover ? null : _pickCover,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.burgundy,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Portada',
                style: AppTypography.bodyMedium(
                  color: AppColors.burgundy,
                ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            if (_hasCustomCover)
              TextButton(
                onPressed: _uploadingCover ? null : _clearCover,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Quitar',
                  style: AppTypography.bodyMedium(
                    color: AppColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
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
                        fontSize: 22,
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
                    const PrefsFormSkeleton(),
                error: (_, __) =>
                    const Center(child: Text('Error al cargar perfil')),
                data: (profile) {
                  _initFields(profile);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 4,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: _avatarEditor(
                                  avatarIcon: profile.avatarIcon,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _coverEditor(context),
                              const SizedBox(height: 10),
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
                                      trailing:
                                          '${_bioController.text.length}/160',
                                      field: TextField(
                                        controller: _bioController,
                                        style: _fieldValueStyle,
                                        maxLines: 2,
                                        minLines: 1,
                                        maxLength: 160,
                                        textInputAction:
                                            TextInputAction.newline,
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
                              const SizedBox(height: 10),
                              DecoratedBox(
                                decoration: ProfileDesign.cardDecoration(),
                                child: SwitchListTile.adaptive(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 0,
                                  ),
                                  dense: true,
                                  secondary: Icon(
                                    _isPrivate
                                        ? Icons.lock_outline_rounded
                                        : Icons.public_rounded,
                                    color: AppColors.burgundy,
                                  ),
                                  title: Text(
                                    'Perfil privado',
                                    style: AppTypography.titleLarge().copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _isPrivate
                                        ? 'Solo seguidores ven tu contenido.'
                                        : 'Cualquiera puede ver tu actividad.',
                                    style: AppTypography.bodyMedium(
                                      color: AppColors.textSecondary,
                                    ).copyWith(fontSize: 12, height: 1.3),
                                  ),
                                  value: _isPrivate,
                                  activeThumbColor: AppColors.burgundy,
                                  onChanged: (value) =>
                                      setState(() => _isPrivate = value),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Handle ${profile.handle}',
                                textAlign: TextAlign.center,
                                style: AppTypography.labelSmall(
                                  color: AppColors.textMuted,
                                ).copyWith(fontSize: 11, height: 1.3),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium(
                                    color: AppColors.accentRed,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
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
