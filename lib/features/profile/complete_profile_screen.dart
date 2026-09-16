import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/cofradeo_avatar.dart';
import '../auth/auth_provider.dart';
import 'profile_onboarding.dart';
import 'data/profile_repository.dart';
import 'profile_provider.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key, this.redirect});

  final String? redirect;

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _displayNameController = TextEditingController();
  final _handleController = TextEditingController();
  final _bioController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  String? _error;
  String? _handleError;
  bool _handleValid = false;

  static final _handleRegex = RegExp(r'^[a-z0-9_]{3,20}$');

  @override
  void initState() {
    super.initState();
    _handleController.addListener(_onFieldsChanged);
    _bioController.addListener(_onFieldsChanged);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onFieldsChanged() {
    _validateHandle();
    if (mounted) setState(() {});
  }

  void _validateHandle() {
    if (!_initialized) return;

    final raw = _handleController.text.trim();
    var normalized = raw;
    if (normalized.startsWith('@')) {
      normalized = normalized.substring(1);
    }
    normalized = normalized.toLowerCase();

    if (normalized.isEmpty) {
      setState(() {
        _handleValid = false;
        _handleError = 'El @handle es obligatorio.';
        _error = null;
      });
      return;
    }

    if (!_handleRegex.hasMatch(normalized)) {
      setState(() {
        _handleValid = false;
        _handleError = '3-20 caracteres (a-z, 0-9, _).';
        _error = null;
      });
      return;
    }

    setState(() {
      _handleValid = true;
      _handleError = null;
    });
  }

  void _initFields() {
    if (_initialized) return;
    final profile = ref.read(currentUserProfileProvider).asData?.value;
    final user = ref.read(currentUserProvider);
    if (profile == null || user == null) return;

    final emailLocal = user.email?.split('@').first ?? '';
    var handle = profile.handle.startsWith('@')
        ? profile.handle.substring(1)
        : profile.handle;
    if (handle.startsWith('user_') && emailLocal.isNotEmpty) {
      handle = emailLocal;
    }

    _displayNameController.text = profile.displayName;
    _handleController.text = handle;
    _bioController.text = profile.bio;
    _initialized = true;
    _validateHandle();
  }

  void _finish() {
    final redirect = widget.redirect;
    if (redirect != null && redirect.isNotEmpty) {
      context.go(redirect);
    } else {
      context.go('/calendario');
    }
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final displayName = _displayNameController.text.trim();
    final handle = _handleController.text.trim();
    final bio = _bioController.text.trim();

    if (displayName.length < 2 || displayName.length > 40) {
      setState(() {
        _error = 'El nombre debe tener entre 2 y 40 caracteres.';
      });
      return;
    }

    final normalizedHandle = handle.startsWith('@')
        ? handle.substring(1).toLowerCase()
        : handle.toLowerCase();
    final validHandle = RegExp(r'^[a-z0-9_]{3,20}$');
    if (!validHandle.hasMatch(normalizedHandle)) {
      setState(() {
        _error = 'El @handle debe tener 3-20 caracteres (a-z, 0-9, _).';
      });
      return;
    }
    if (bio.length > 160) {
      setState(() {
        _error = 'La bio no puede superar 160 caracteres.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            userId: user.id,
            displayName: displayName,
            handle: normalizedHandle,
            bio: bio,
          );
      await ref.read(authRepositoryProvider).markOnboardingCompleted();
      ref.invalidate(currentUserProfileProvider);
      if (mounted) _finish();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        setState(() {
          _error = 'Ese @handle ya existe. Prueba otro.';
        });
      } else {
        setState(() {
          _error = 'No se pudo guardar el perfil.';
        });
      }
    } on ProfileUnavailableException {
      setState(() {
        _error = 'Configura Supabase para completar el perfil.';
      });
    } catch (_) {
      setState(() {
        _error = 'No se pudo guardar el perfil.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  int get _handleLength {
    final raw = _handleController.text.trim();
    final normalized = raw.startsWith('@') ? raw.substring(1) : raw;
    return normalized.length;
  }

  InputDecoration _underlineDecoration({
    required String label,
    String? errorText,
    String? counter,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.labelSmall(color: AppColors.textSecondary)
          .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
      floatingLabelStyle: AppTypography.labelSmall(color: AppColors.textSecondary)
          .copyWith(fontSize: 12, fontWeight: FontWeight.w500),
      errorText: errorText,
      suffix: counter == null
          ? null
          : Text(
              counter,
              style: AppTypography.labelSmall(color: AppColors.textMuted)
                  .copyWith(fontSize: 12),
            ),
      contentPadding: const EdgeInsets.only(top: 8, bottom: 10),
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.textPrimary, width: 1),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.textPrimary, width: 1),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.burgundy, width: 1.5),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accentRed, width: 1),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.accentRed, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Error al cargar perfil')),
            data: (profile) {
              _initFields();
              final user = ref.watch(currentUserProvider);
              final copy = buildProfileOnboardingCopy(
                user: user,
                profile: profile,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  Text(
                    'COMPLETA TU PERFIL',
                    style: AppTypography.screenTitle().copyWith(
                      fontSize: 30,
                      letterSpacing: 0.4,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OnboardingExplanationCard(copy: copy),
                  const SizedBox(height: 24),
                  Center(
                    child: CofradeoAvatar(
                      imageUrl: profile.avatarUrl,
                      icon: profile.avatarIcon,
                      size: 112,
                      backgroundColor: AppColors.burgundyDark,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _displayNameController,
                    style: AppTypography.bodyLarge().copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: _underlineDecoration(label: 'Nombre visible'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Aparece en tu perfil y junto a tus publicaciones.',
                    style: AppTypography.labelSmall(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _handleController,
                    style: AppTypography.bodyLarge().copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: _underlineDecoration(
                      label: '@handle',
                      errorText: _handleError,
                      counter: '$_handleLength/20',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Único en la app. Sirve para @menciones y para que te encuentren.',
                    style: AppTypography.labelSmall(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _bioController,
                    maxLength: 160,
                    maxLines: 2,
                    style: AppTypography.bodyLarge().copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                    buildCounter: (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$currentLength/160',
                          style: AppTypography.labelSmall(
                            color: AppColors.textMuted,
                          ).copyWith(fontSize: 12),
                        ),
                      );
                    },
                    decoration: _underlineDecoration(label: 'Bio (opcional)'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: AppTypography.bodyMedium(color: AppColors.accentRed),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving || !_handleValid ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: AppColors.textOnDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnDark,
                              ),
                            )
                          : Text(
                              'Guardar y continuar',
                              style: AppTypography.titleLarge(
                                color: AppColors.textOnDark,
                              ).copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OnboardingExplanationCard extends StatelessWidget {
  const _OnboardingExplanationCard({required this.copy});

  final ProfileOnboardingCopy copy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: AppColors.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¿Por qué te pedimos esto?',
                  style: AppTypography.titleLarge().copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            copy.intro,
            style: AppTypography.bodyMedium(color: AppColors.textSecondary),
          ),
          if (copy.hints.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final hint in copy.hints) ...[
              _HintBullet(text: hint),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _HintBullet extends StatelessWidget {
  const _HintBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: AppTypography.bodyMedium(color: AppColors.gold),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
