import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptic.dart';
import '../../../../core/utils/responsive.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key, required this.points});
  final List<LatLng> points;

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final _nameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _varietyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _ownershipType;
  String? _fieldStatus;
  String? _cropType;
  String? _irrigationType;
  final List<XFile> _images = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    _varietyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    hapticSelect();
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo != null) setState(() => _images.add(photo));
  }

  void _removeImage(int index) {
    hapticLight();
    setState(() => _images.removeAt(index));
  }

  void _onSubmit() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('fieldNameRequired'.tr()),
        backgroundColor: kError,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      _tabController.animateTo(0);
      return;
    }
    hapticMedium();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('fieldSaved'.tr()),
      backgroundColor: kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).padding.bottom;
    final bg = isDark ? const Color(0xFF111111) : const Color(0xFFEEF1EE);

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          _MonitoringAppBar(
            isDark: isDark,
            colorScheme: colorScheme,
            pointCount: widget.points.length,
          ),
          _MonitoringTabBar(controller: _tabController, isDark: isDark, colorScheme: colorScheme),
          const SizedBox(height: 2),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(),
              children: [
                _BasicTab(
                  nameCtrl: _nameCtrl,
                  areaCtrl: _areaCtrl,
                  notesCtrl: _notesCtrl,
                  ownershipType: _ownershipType,
                  fieldStatus: _fieldStatus,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onOwnershipChanged: (v) => setState(() => _ownershipType = v),
                  onStatusChanged: (v) => setState(() => _fieldStatus = v),
                ),
                _CropTab(
                  varietyCtrl: _varietyCtrl,
                  cropType: _cropType,
                  irrigationType: _irrigationType,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onCropTypeChanged: (v) => setState(() => _cropType = v),
                  onIrrigationChanged: (v) => setState(() => _irrigationType = v),
                ),
                _MediaTab(
                  images: _images,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onAdd: _pickFromCamera,
                  onRemove: _removeImage,
                ),
                _CoordsTab(
                  points: widget.points,
                  isDark: isDark,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
          _SubmitBar(bottom: bottom, onSubmit: _onSubmit, isDark: isDark, colorScheme: colorScheme),
        ],
      ),
    );
  }
}

class _MonitoringAppBar extends StatelessWidget {
  const _MonitoringAppBar({required this.isDark, required this.colorScheme, required this.pointCount});
  final bool isDark;
  final ColorScheme colorScheme;
  final int pointCount;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, top + 4, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? [const Color(0xFF1A2E1A), const Color(0xFF111111)] : [kGreen, const Color(0xFF2E7D32)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () { hapticLight(); Navigator.pop(context); },
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'monitoringTitle'.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.rs(17.0, 20.0),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'cornerPointsCount'.tr(namedArgs: {'count': pointCount.toString()}),
                  style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(50)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sensors_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text('tabCoord'.tr(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonitoringTabBar extends StatelessWidget {
  const _MonitoringTabBar({required this.controller, required this.isDark, required this.colorScheme});
  final TabController controller;
  final bool isDark;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF111111) : kGreen,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(10) : Colors.white.withAlpha(30),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            color: isDark ? kGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: isDark ? Colors.white : kGreen,
          unselectedLabelColor: isDark ? Colors.white.withAlpha(130) : Colors.white.withAlpha(200),
          labelPadding: EdgeInsets.zero,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: [
            _Tab(label: 'tabBasic'.tr()),
            _Tab(label: 'tabCrop'.tr()),
            _Tab(label: 'tabMedia'.tr()),
            _Tab(label: 'tabCoord'.tr()),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Tab(
    height: 38,
    child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, required this.isDark, required this.colorScheme});
  final String title;
  final List<Widget> children;
  final bool isDark;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E1E20) : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? [BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 10, offset: const Offset(0, 2))]
            : [
                BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 2)),
                BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 20, offset: const Offset(0, 5)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? kGreenLight : kGreen,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withAlpha(isDark ? 40 : 55)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BasicTab extends StatelessWidget {
  const _BasicTab({
    required this.nameCtrl,
    required this.areaCtrl,
    required this.notesCtrl,
    required this.ownershipType,
    required this.fieldStatus,
    required this.isDark,
    required this.colorScheme,
    required this.onOwnershipChanged,
    required this.onStatusChanged,
  });

  final TextEditingController nameCtrl;
  final TextEditingController areaCtrl;
  final TextEditingController notesCtrl;
  final String? ownershipType;
  final String? fieldStatus;
  final bool isDark;
  final ColorScheme colorScheme;
  final ValueChanged<String?> onOwnershipChanged;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _Section(
          title: 'sectionGeneral'.tr(),
          isDark: isDark,
          colorScheme: colorScheme,
          children: [
            _Input(controller: nameCtrl, label: 'fieldName'.tr(), hint: 'fieldNameHint'.tr(), isDark: isDark, colorScheme: colorScheme),
            _Input(controller: areaCtrl, label: 'fieldArea'.tr(), hint: '0.00', isDark: isDark, colorScheme: colorScheme, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'sectionOwnership'.tr(),
          isDark: isDark,
          colorScheme: colorScheme,
          children: [
            _Dropdown(label: 'ownershipType'.tr(), value: ownershipType, items: ['ownerPrivate'.tr(), 'ownerRented'.tr(), 'ownerState'.tr()], isDark: isDark, colorScheme: colorScheme, onChanged: onOwnershipChanged),
            _Dropdown(label: 'fieldStatusLabel'.tr(), value: fieldStatus, items: ['statusActive'.tr(), 'statusInactive'.tr(), 'statusPending'.tr()], isDark: isDark, colorScheme: colorScheme, onChanged: onStatusChanged),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'sectionNotes'.tr(),
          isDark: isDark,
          colorScheme: colorScheme,
          children: [
            _Input(controller: notesCtrl, label: 'fieldNotes'.tr(), hint: 'fieldNotesHint'.tr(), isDark: isDark, colorScheme: colorScheme, maxLines: 3),
          ],
        ),
      ],
    );
  }
}

class _CropTab extends StatelessWidget {
  const _CropTab({
    required this.varietyCtrl,
    required this.cropType,
    required this.irrigationType,
    required this.isDark,
    required this.colorScheme,
    required this.onCropTypeChanged,
    required this.onIrrigationChanged,
  });

  final TextEditingController varietyCtrl;
  final String? cropType;
  final String? irrigationType;
  final bool isDark;
  final ColorScheme colorScheme;
  final ValueChanged<String?> onCropTypeChanged;
  final ValueChanged<String?> onIrrigationChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _Section(
          title: 'cropTypeLabel'.tr(),
          isDark: isDark,
          colorScheme: colorScheme,
          children: [
            _Dropdown(
              label: 'cropTypeLabel'.tr(),
              value: cropType,
              items: ['cropWheat'.tr(), 'cropCorn'.tr(), 'cropCotton'.tr(), 'cropBarley'.tr(), 'cropRice'.tr(), 'cropVegetable'.tr(), 'cropFruit'.tr(), 'cropOther'.tr()],
              isDark: isDark,
              colorScheme: colorScheme,
              onChanged: onCropTypeChanged,
            ),
            _Input(controller: varietyCtrl, label: 'cropVariety'.tr(), hint: 'cropVarietyHint'.tr(), isDark: isDark, colorScheme: colorScheme),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'sectionIrrigation'.tr(),
          isDark: isDark,
          colorScheme: colorScheme,
          children: [
            _Dropdown(
              label: 'irrigationMethod'.tr(),
              value: irrigationType,
              items: ['irrigationSurface'.tr(), 'irrigationDrip'.tr(), 'irrigationSprinkler'.tr(), 'irrigationRainfed'.tr()],
              isDark: isDark,
              colorScheme: colorScheme,
              onChanged: onIrrigationChanged,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kGreen.withAlpha(isDark ? 20 : 12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kGreen.withAlpha(50)),
          ),
          child: Text(
            'cropInfoText'.tr(),
            style: TextStyle(fontSize: 12.5, color: isDark ? kGreenLight : kGreen, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({
    required this.images,
    required this.isDark,
    required this.colorScheme,
    required this.onAdd,
    required this.onRemove,
  });
  final List<XFile> images;
  final bool isDark;
  final ColorScheme colorScheme;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 32 - 20) / 3;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: _Section(
        title: 'mediaLabel'.tr(),
        isDark: isDark,
        colorScheme: colorScheme,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: w,
                  height: w,
                  decoration: BoxDecoration(
                    color: kGreen.withAlpha(isDark ? 22 : 14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kGreen.withAlpha(120), width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: kGreen.withAlpha(22), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, color: kGreen, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text('addPhotoLabel'.tr(), textAlign: TextAlign.center, style: const TextStyle(color: kGreen, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.3)),
                    ],
                  ),
                ),
              ),
              for (var i = 0; i < images.length; i++)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(images[i].path),
                        width: w,
                        height: w,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: GestureDetector(
                        onTap: () => onRemove(i),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(160),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (images.isEmpty) ...[
            const SizedBox(height: 10),
            Text('mediaInfoText'.tr(), style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withAlpha(170), height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _CoordsTab extends StatelessWidget {
  const _CoordsTab({required this.points, required this.isDark, required this.colorScheme});
  final List<LatLng> points;
  final bool isDark;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _Section(
          title: 'coordinates'.tr(),
          isDark: isDark,
          colorScheme: colorScheme,
          children: [
            for (int i = 0; i < points.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _CoordCard(index: i, point: points[i], isDark: isDark, colorScheme: colorScheme),
            ],
          ],
        ),
      ],
    );
  }
}

class _CoordCard extends StatelessWidget {
  const _CoordCard({required this.index, required this.point, required this.isDark, required this.colorScheme});
  final int index;
  final LatLng point;
  final bool isDark;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kGreen, kGreenLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle,
          ),
          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${'latitude'.tr()}: ${point.latitude.toStringAsFixed(7)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurface, fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 2),
              Text('${'longitude'.tr()}: ${point.longitude.toStringAsFixed(7)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurface, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            hapticLight();
            Clipboard.setData(ClipboardData(text: '${point.latitude.toStringAsFixed(7)}, ${point.longitude.toStringAsFixed(7)}'));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('pointCopied'.tr(namedArgs: {'index': '${index + 1}'})),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ));
          },
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: kGreen.withAlpha(isDark ? 35 : 18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.copy_rounded, size: 15, color: kGreen),
          ),
        ),
      ],
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.bottom, required this.onSubmit, required this.isDark, required this.colorScheme});
  final double bottom;
  final VoidCallback onSubmit;
  final bool isDark;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottom + 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFEEF1EE),
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withAlpha(70))),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kGreen, kGreenLight], begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: kGreen.withAlpha(90), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hTapMedium(onSubmit),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'submit'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.label, required this.hint, required this.isDark, required this.colorScheme, this.keyboardType, this.maxLines = 1});
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isDark;
  final ColorScheme colorScheme;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? Colors.white.withAlpha(8) : Colors.grey.shade50;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(60))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kGreen, width: 1.8)),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        floatingLabelStyle: TextStyle(color: isDark ? kGreenLight : kGreen, fontSize: 13, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withAlpha(100), fontSize: 13),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.label, required this.value, required this.items, required this.isDark, required this.colorScheme, required this.onChanged});
  final String label;
  final String? value;
  final List<String> items;
  final bool isDark;
  final ColorScheme colorScheme;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final fill = isDark ? Colors.white.withAlpha(8) : Colors.grey.shade50;
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(60))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: kGreen, width: 1.8)),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        floatingLabelStyle: TextStyle(color: isDark ? kGreenLight : kGreen, fontSize: 13, fontWeight: FontWeight.w600),
      ),
      borderRadius: BorderRadius.circular(14),
      dropdownColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kGreen),
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }
}
