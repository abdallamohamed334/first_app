import 'package:flutter/material.dart';
import '../../../../core/models/user_model.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel user;
  final int points;
  final VoidCallback onEditPressed;
  final VoidCallback onAvatarPressed;
  final bool isUploading;

  const ProfileHeader({
    super.key,
    required this.user,
    required this.points,
    required this.onEditPressed,
    required this.onAvatarPressed,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = user.name.trim().isEmpty ? 'مستخدم Loqma' : user.name.trim();
    final initial = name.substring(0, 1).toUpperCase();

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 124,
              height: 124,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [colors.primary, colors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withAlpha(45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: isUploading
                    ? Container(
                        color: colors.primary,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      )
                    : user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? Image.network(
                            user.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallback(
                              colors,
                              initial,
                            ),
                          )
                        : _fallback(colors, initial),
              ),
            ),
            Positioned(
              bottom: 0,
              right: -2,
              child: _RoundAction(
                icon: Icons.camera_alt_rounded,
                color: colors.primary,
                onTap: onAvatarPressed,
              ),
            ),
            Positioned(
              bottom: 0,
              left: -2,
              child: _RoundAction(
                icon: Icons.edit_rounded,
                color: colors.secondary,
                onTap: onEditPressed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (user.isVerified) ...[
              const SizedBox(width: 7),
              Icon(Icons.verified_rounded, color: colors.primary, size: 21),
            ],
          ],
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, size: 17, color: colors.primary),
              const SizedBox(width: 5),
              Text(
                '$points نقطة • ${user.type.displayName}',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fallback(ColorScheme colors, String initial) {
    return Container(
      color: colors.primary.withAlpha(28),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: colors.primary,
          fontSize: 48,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
