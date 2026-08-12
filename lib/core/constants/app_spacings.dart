import 'package:flutter/material.dart';

const kVerticalSpace4 = SizedBox(height: 4);
const kVerticalSpace8 = SizedBox(height: 8);
const kVerticalSpace12 = SizedBox(height: 12);
const kVerticalSpace16 = SizedBox(height: 16);
const kVerticalSpace24 = SizedBox(height: 24);
const kVerticalSpace32 = SizedBox(height: 32);
const kVerticalSpace48 = SizedBox(height: 48);
const kVerticalSpace64 = SizedBox(height: 64);

const kHorizontalSpace4 = SizedBox(width: 4);
const kHorizontalSpace8 = SizedBox(width: 8);
const kHorizontalSpace12 = SizedBox(width: 12);
const kHorizontalSpace16 = SizedBox(width: 16);
const kHorizontalSpace24 = SizedBox(width: 24);

const kPaddingAll8 = EdgeInsets.all(8);
const kPaddingAll12 = EdgeInsets.all(12);
const kPaddingAll16 = EdgeInsets.all(16);
const kPaddingAll24 = EdgeInsets.all(24);
const kPaddingH16 = EdgeInsets.symmetric(horizontal: 16);
const kPaddingH24 = EdgeInsets.symmetric(horizontal: 24);
const kPaddingV8 = EdgeInsets.symmetric(vertical: 8);
const kPaddingV16 = EdgeInsets.symmetric(vertical: 16);
const kPaddingV24 = EdgeInsets.symmetric(vertical: 24);

/// Clearance bottom-anchored map content (zoom/location/draw-field buttons,
/// the in-progress-drawing bottom bar — see `location_map.dart`) needs to
/// clear `MainPage`'s `bottomNavigationBar` + FAB notch. Needed because
/// `MainPage` sets `extendBody: true` (required for the notch to render
/// correctly at all — without it `Scaffold.geometryOf` never reports a
/// `floatingActionButtonArea`, so the bar just draws flat with no notch).
/// That same flag is what makes `body` extend behind the bar, so anything
/// bottom-anchored in `body` needs to opt back out with this. Doesn't
/// include the safe-area inset — add `MediaQuery.of(context).padding.bottom`
/// separately at the call site if the existing offset there doesn't already
/// account for it.
const kFloatingNavBarClearance = 76.0;
