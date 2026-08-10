import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Shows the photo that came back from auth (`User.imageUrl`, decoded from
/// the JWT — see `UserModel.fromAccessToken`) as a circular avatar; falls
/// back to a plain generic profile icon when there isn't one (no photo on
/// file, or it failed to load). Used both for the small top-bar button on
/// the home page and the large header on the profile page itself.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return _fallbackIcon();

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _fallbackIcon(),
      ),
    );
  }

  Widget _fallbackIcon() =>
      Icon(Icons.account_circle_rounded, size: size, color: kGreen);
}
