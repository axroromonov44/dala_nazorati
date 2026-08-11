import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({super.key, required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  String? _loadedForUrl;

  void _markLoaded(String url) {
    if (_loadedForUrl == url) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _loadedForUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.imageUrl;
    final size = widget.size;
    if (url == null || url.isEmpty) return _fallbackIcon(size);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _fallbackIcon(size),
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                _markLoaded(url);
                return child;
              }
              return _loadingSpinner(progress, size);
            },
          ),
        ),
        if (_loadedForUrl == url)
          Positioned(
            right: -size * 0.02,
            bottom: -size * 0.02,
            child: ProfileVerifiedBadge(avatarSize: size),
          ),
      ],
    );
  }

  Widget _fallbackIcon(double size) =>
      Icon(Icons.account_circle_rounded, size: size, color: kGreen);

  Widget _loadingSpinner(ImageChunkEvent progress, double size) => SizedBox(
    width: size,
    height: size,
    child: Center(
      child: SizedBox(
        width: size * 0.4,
        height: size * 0.4,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: kGreen,
          value: progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null,
        ),
      ),
    ),
  );
}

class ProfileVerifiedBadge extends StatelessWidget {
  const ProfileVerifiedBadge({
    super.key,
    required this.avatarSize,
    this.sizeBoost = 0,
  });

  final double avatarSize;
  final double sizeBoost;

  @override
  Widget build(BuildContext context) {
    final badgeSize = (avatarSize * 0.34).clamp(14.0, 26.0) + sizeBoost;
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        'assets/images/verified.png',
        width: badgeSize,
        height: badgeSize,
      ),
    );
  }
}
