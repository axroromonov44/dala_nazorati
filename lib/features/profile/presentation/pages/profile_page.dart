import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/map/tile_cache_service.dart';
import '../../../../core/notifications/app_notification.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/profile_cubit.dart';
import '../../../fields/data/field_media_cache.dart';
import '../../../fields/domain/repositories/field_repository.dart';
import '../widgets/profile_avatar.dart';

/// Full-page replacement for the old slide-out drawer — reached by tapping
/// the avatar/profile button next to the notification bell on the home
/// page (see `home_page.dart`). Everything the drawer used to hold
/// (language, dark mode, map cache, logout, app version) lives here now,
/// under a proper identity header (photo + name from `ProfileCubit`).
///
/// Each setting is its own dense [ListTile] wrapped in [_BorderedTile] —
/// separately bordered rows rather than one shared boxed/spaced-out list.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeCubit>().state == ThemeMode.dark;
    final user = context.watch<ProfileCubit>().state;
    final hPad = context.spaceLg;
    final displayName = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName
        : (user?.username ?? '');

    return Scaffold(
      appBar: AppBar(title: Text('profileTitle'.tr()), centerTitle: true),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          hPad,
          context.spaceMd,
          hPad,
          context.spaceLg,
        ),
        children: [
          _IdentityCard(user: user, displayName: displayName),
          SizedBox(height: context.spaceMd),
          const _BorderedTile(child: _LanguageTile()),
          SizedBox(height: context.spaceSm),
          _BorderedTile(child: _ThemeTile(isDark: isDark)),
          SizedBox(height: context.spaceSm),
          const _BorderedTile(child: _ClearMapCacheTile()),
          SizedBox(height: context.spaceXl),
          const _BorderedTile(child: _LogoutTile()),
          SizedBox(height: context.spaceMd),
          const _AppVersionLabel(),
        ],
      ),
    );
  }
}

/// Tappable identity summary at the top of the page — opens
/// [_ProfileDetailsSheet] with the full set of `GET /users/me` fields
/// (pinfl/passport/birth date/address/…) that don't fit in a compact
/// header.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user, required this.displayName});

  final User? user;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = this.user;
    final imageUrl = user?.imageUrl;
    final hasPhoto = imageUrl != null && imageUrl.isNotEmpty;
    final subtitle = [
      if (user?.position?.isNotEmpty ?? false) user!.position!,
      if (user?.phone?.isNotEmpty ?? false) user!.phone!,
    ].join(' • ');

    return GestureDetector(
      onTap: user == null
          ? null
          : () {
              hapticSelect();
              _showProfileDetailsSheet(context, user);
            },
      child: Container(
        padding: EdgeInsets.all(context.spaceLg),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rasmning o'zi alohida bosiladi (to'liq ekran preview ochadi)
            // — kartaning qolgan qismi esa tafsilotlar varag'ini ochadi;
            // ichki GestureDetector ustuvor bo'lgani uchun ikkalasi
            // to'qnashmaydi.
            GestureDetector(
              onTap: hasPhoto
                  ? () {
                      hapticSelect();
                      _showPhotoPreview(context, imageUrl);
                    }
                  : null,
              child: ProfileAvatar(
                imageUrl: imageUrl,
                size: context.rs(72.0, 88.0),
              ),
            ),
            SizedBox(width: context.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayName.isNotEmpty)
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: context.rs(19.0, 22.0),
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (user != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'tapForDetails'.tr(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: kGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (user != null)
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a single settings [ListTile] in its own bordered, rounded card —
/// each row (language/theme/cache/logout) stays visually separate rather
/// than merged into one shared container.
class _BorderedTile extends StatelessWidget {
  const _BorderedTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // `ClipRRect` + a separately-bordered `Container` clips the straight
    // rectangular border stroke right where it should curve, leaving the
    // corners looking border-less — putting `borderRadius` directly on the
    // same `BoxDecoration` as `border` draws a properly rounded stroke, and
    // `clipBehavior` alone still keeps the child (ListTile ink/ripple)
    // contained to that same rounded shape.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

void _showProfileDetailsSheet(BuildContext context, User user) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: context.isTablet
        ? BoxConstraints(maxWidth: context.sheetMaxWidth)
        : null,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ProfileDetailsSheet(user: user),
  );
}

void _showPhotoPreview(BuildContext context, String imageUrl) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
        opacity: animation,
        child: _PhotoPreviewPage(imageUrl: imageUrl),
      ),
    ),
  );
}

/// Full-screen, pinch-zoomable preview of the profile photo — tapping the
/// avatar in [_IdentityCard] opens this instead of (not in addition to) the
/// details sheet the rest of the card opens.
class _PhotoPreviewPage extends StatelessWidget {
  const _PhotoPreviewPage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full read-only breakdown of every `GET /users/me` field this employee
/// has — pinfl/passport carry a copy button (`_DetailRow(copyable: true)`)
/// since those are the two values most often needed to paste elsewhere.
class _ProfileDetailsSheet extends StatelessWidget {
  const _ProfileDetailsSheet({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).padding.bottom;
    final birthDate = _formattedBirthDate(user.birthDate);
    final gender = _localizedGender(user.gender);

    final rows = <Widget>[
      _DetailRow(label: 'detailFullName'.tr(), value: user.fullName),
      if (user.fullNameCyrillic?.isNotEmpty ?? false)
        _DetailRow(
          label: 'detailFullNameCyrillic'.tr(),
          value: user.fullNameCyrillic!,
        ),
      _DetailRow(label: 'detailUsername'.tr(), value: user.username),
      if (user.position?.isNotEmpty ?? false)
        _DetailRow(label: 'detailPosition'.tr(), value: user.position!),
      if (user.phone?.isNotEmpty ?? false)
        _DetailRow(label: 'detailPhone'.tr(), value: user.phone!),
      if (user.email?.isNotEmpty ?? false)
        _DetailRow(label: 'detailEmail'.tr(), value: user.email!),
      if (user.pinfl?.isNotEmpty ?? false)
        _DetailRow(
          label: 'detailPinfl'.tr(),
          value: user.pinfl!,
          copyable: true,
        ),
      if (user.passportNumber?.isNotEmpty ?? false)
        _DetailRow(
          label: 'detailPassport'.tr(),
          value: user.passportNumber!,
          copyable: true,
        ),
      if (birthDate != null)
        _DetailRow(label: 'detailBirthDate'.tr(), value: birthDate),
      if (gender != null) _DetailRow(label: 'detailGender'.tr(), value: gender),
      if (user.regionName?.isNotEmpty ?? false)
        _DetailRow(label: 'detailRegion'.tr(), value: user.regionName!),
      if (user.districtName?.isNotEmpty ?? false)
        _DetailRow(label: 'detailDistrict'.tr(), value: user.districtName!),
      if (user.address?.isNotEmpty ?? false)
        _DetailRow(label: 'detailAddress'.tr(), value: user.address!),
    ];

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'profileDetailsTitle'.tr(),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: colorScheme.outlineVariant),
                      rows[i],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One label/value line inside [_ProfileDetailsSheet]. [copyable] adds a
/// small copy-to-clipboard button — used for pinfl/passport, the two
/// values most often needed to paste into another form.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    hapticSelect();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('copiedToClipboard'.tr(namedArgs: {'label': label})),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_rounded, size: 18),
              color: kGreen,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

/// `birth_date` comes as a plain ISO date (`"2001-01-02"`) — reformatted to
/// `dd.MM.yyyy` when parseable; falls back to the raw string rather than
/// hiding it if the backend ever changes format.
String? _formattedBirthDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return DateFormat('dd.MM.yyyy').format(parsed);
}

String? _localizedGender(String? raw) {
  switch (raw) {
    case 'male':
      return 'genderMale'.tr();
    case 'female':
      return 'genderFemale'.tr();
    default:
      return null;
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  static const _langs = [
    (code: 'uz', label: "O'zbek tili", flag: '🇺🇿'),
    (code: 'ru', label: 'Русский язык', flag: '🇷🇺'),
    (code: 'en', label: 'English', flag: '🇬🇧'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final current = context.locale.languageCode;
    final currentLang = _langs.firstWhere(
      (l) => l.code == current,
      orElse: () => _langs.first,
    );

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: const Icon(Icons.language_rounded, color: kGreen),
      title: Text('languageLabel'.tr()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(currentLang.flag, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            currentLang.label,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right_rounded,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () => _showLanguagePicker(context),
    );
  }
}

void _showLanguagePicker(BuildContext context) {
  final current = context.locale.languageCode;
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final lang in _LanguageTile._langs)
            ListTile(
              leading: Text(lang.flag, style: const TextStyle(fontSize: 20)),
              title: Text(lang.label),
              trailing: lang.code == current
                  ? const Icon(Icons.check_rounded, color: kGreen)
                  : null,
              onTap: () {
                hapticSelect();
                context.setLocale(Locale(lang.code));
                Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    ),
  );
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.isDark});
  final bool isDark;

  void _toggle(BuildContext context) {
    hapticSelect();
    context.read<ThemeCubit>().toggle();
  }

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    visualDensity: VisualDensity.compact,
    leading: Icon(
      isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
      color: kGreen,
    ),
    title: Text(isDark ? 'darkMode'.tr() : 'lightMode'.tr()),
    trailing: Switch.adaptive(
      value: isDark,
      activeThumbColor: kGreen,
      onChanged: (_) => _toggle(context),
    ),
    onTap: () => _toggle(context),
  );
}

class _ClearMapCacheTile extends StatefulWidget {
  const _ClearMapCacheTile();

  @override
  State<_ClearMapCacheTile> createState() => _ClearMapCacheTileState();
}

class _ClearMapCacheTileState extends State<_ClearMapCacheTile> {
  late Future<int> _sizeFuture = TileCacheService.cacheSizeBytes();
  bool _clearing = false;

  Future<void> _clear() async {
    hapticSelect();
    final confirmed = await _showClearCacheConfirmDialog(context);
    if (!confirmed || !mounted) return;

    setState(() => _clearing = true);
    await TileCacheService.clearCache();
    // Kesh tozalanganda unga bog'liq bo'lgan yuklab olish bildirishnomalari
    // ham eskiradi — ularni olib tashlaymiz, boshqa (masalan umumiy xabar)
    // bildirishnomalarga tegmaymiz.
    NotificationCenter.items.value = NotificationCenter.items.value
        .where((n) => n is! OfflineDownloadNotification)
        .toList();
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _sizeFuture = TileCacheService.cacheSizeBytes();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('clearMapCacheSuccess'.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Boshqa tugmalar (til, rejim) kabi bitta qatorli — o'lchamni pastki
    // yozuv (subtitle) sifatida ko'rsatish qolganlariga nisbatan balandroq
    // qilib qo'yardi.
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: const Icon(Icons.delete_outline_rounded, color: kGreen),
      title: Text('clearMapCache'.tr()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<int>(
            future: _sizeFuture,
            builder: (context, snapshot) => Text(
              snapshot.hasData ? formatMapCacheSize(snapshot.data!) : '…',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (_clearing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: kGreen),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
      onTap: _clearing ? null : _clear,
    );
  }
}

Future<bool> _showClearCacheConfirmDialog(BuildContext context) {
  if (Platform.isIOS) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('clearMapCacheConfirmTitle'.tr()),
        content: Text('clearMapCacheConfirmBody'.tr()),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancelAction'.tr()),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('clearMapCache'.tr()),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('clearMapCacheConfirmTitle'.tr()),
      content: Text('clearMapCacheConfirmBody'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('cancelAction'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'clearMapCache'.tr(),
            style: const TextStyle(color: kError, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

Future<bool> _showLogoutConfirmDialog(BuildContext context) {
  if (Platform.isIOS) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text('logoutConfirmTitle'.tr()),
        content: Text('logoutConfirmBody'.tr()),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('cancelAction'.tr()),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('logout'.tr()),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('logoutConfirmTitle'.tr()),
      content: Text('logoutConfirmBody'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('cancelAction'.tr()),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'logout'.tr(),
            style: const TextStyle(color: kError, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  ).then((value) => value ?? false);
}

class _LogoutTile extends StatefulWidget {
  const _LogoutTile();

  @override
  State<_LogoutTile> createState() => _LogoutTileState();
}

class _LogoutTileState extends State<_LogoutTile> {
  bool _loggingOut = false;

  /// Chiqishda shu qurilmadagi joriy hodimga tegishli BARCHA lokal
  /// ma'lumotlar (token, profil, dalalar indeksi/tafsiloti, dala rasmlari,
  /// xarita tayl keshi, kutilayotgan oflayn navbat) tozalanadi — shunda
  /// boshqa hodim shu qurilmada kirsa avvalgisining hech narsasini
  /// ko'rmaydi, va qayta kirilganda hammasi qaytadan yuklanadi (bu
  /// so'nggisi `SyncTriggered` orqali `login_page.dart`da ta'minlanadi).
  Future<void> _logout() async {
    hapticSelect();
    final confirmed = await _showLogoutConfirmDialog(context);
    if (!confirmed || !mounted) return;

    setState(() => _loggingOut = true);
    await getIt<AuthRepository>().logout();
    await getIt<FieldRepository>().clearLocalData();
    await FieldMediaCache.clear();
    await TileCacheService.clearCache();
    await getIt<HiveService>().offlineQueueBox.clear();
    getIt<ProfileCubit>().reset();
    NotificationCenter.items.value = const [];

    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: _loggingOut
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: kError),
            )
          : const Icon(Icons.logout_rounded, color: kError),
      title: Text(
        'logout'.tr(),
        style: const TextStyle(color: kError, fontWeight: FontWeight.w600),
      ),
      onTap: _loggingOut ? null : _logout,
    );
  }
}

class _AppVersionLabel extends StatelessWidget {
  const _AppVersionLabel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final text = info == null ? '' : 'v${info.version}+${info.buildNumber}';
        return Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.rs(11.0, 13.0),
            color: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
