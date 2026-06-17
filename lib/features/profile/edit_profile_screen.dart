import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/cofradeo_avatar.dart';
import '../../shared/models/user_profile.dart';
import '../auth/auth_provider.dart';
import '../forums/forums_provider.dart';
import '../forums/topic_replies_provider.dart';
import 'data/profile_repository.dart';
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
      final bytes = await file.readAsBytes();
      final mime = switch (file.path.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

      final url = await ref.read(profileRepositoryProvider).uploadAvatar(
            userId: user.id,
            bytes: bytes,
            mimeType: mime,
          );

      setState(() => _avatarUrl = url);
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(forumTopicsProvider);
      ref.invalidate(topicRepliesFirstPageProvider);
    } on AvatarTooLargeException {
      setState(() => _error = 'La imagen supera 2 MB.');
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.chevron_left, color: AppColors.burgundy),
        ),
        title: Text(
          'Editar perfil',
          style: AppTypography.displaySmall().copyWith(fontSize: 17),
        ),
        centerTitle: true,
        actions: [
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
                    style: AppTypography.bodyMedium(color: AppColors.burgundy),
                  ),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error al cargar perfil')),
        data: (profile) {
          _initFields(profile);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Stack(
                  children: [
                    CofradeoAvatar(
                      imageUrl: _avatarUrl,
                      icon: profile.avatarIcon,
                      size: 88,
                      backgroundColor: AppColors.burgundyDark,
                    ),
                    if (_uploadingAvatar)
                      const Positioned.fill(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _uploadingAvatar ? null : _pickAvatar,
                  child: const Text('Cambiar foto'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Nombre visible'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 160,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _foundedController,
                decoration: const InputDecoration(labelText: 'Fundación'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _websiteController,
                decoration: const InputDecoration(labelText: 'Sitio web'),
              ),
              const SizedBox(height: 8),
              Text(
                'Handle ${profile.handle} — cambio limitado en versión futura.',
                style: AppTypography.labelSmall(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTypography.bodyMedium(color: AppColors.accentRed),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
