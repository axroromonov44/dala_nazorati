import 'dart:convert';
import 'dart:io';

import 'package:dala_nazorati/features/auth/domain/entities/inspector_role.dart';
import 'package:dala_nazorati/features/auth/domain/entities/user.dart';
import 'package:dala_nazorati/features/auth/presentation/widgets/role_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveInspectorRole', () {
    test('matches an exact backend code', () {
      expect(
        resolveInspectorRole(['karantin_inspector']),
        InspectorRole.karantin,
      );
      expect(resolveInspectorRole(['vet_inspector']), InspectorRole.veterinary);
      expect(resolveInspectorRole(['ses_inspector']), InspectorRole.ses);
    });

    test('ignores case and surrounding whitespace', () {
      expect(
        resolveInspectorRole([' VET_Inspector ']),
        InspectorRole.veterinary,
      );
    });

    test('falls back to keywords for codes not in the table', () {
      expect(
        resolveInspectorRole(['regional_veterinary_officer']),
        InspectorRole.veterinary,
      );
      expect(resolveInspectorRole(['sanepid_supervisor']), InspectorRole.ses);
      expect(
        resolveInspectorRole(['phytosanitary_control']),
        InspectorRole.karantin,
      );
    });

    test('prefers an exact code over a keyword hit in another entry', () {
      // 'ses_inspector' is exact; 'district_veterinary' would only match by
      // keyword, so the exact code has to win regardless of list order.
      expect(
        resolveInspectorRole(['district_veterinary', 'ses_inspector']),
        InspectorRole.ses,
      );
    });

    test('uses position only when roles say nothing', () {
      expect(
        resolveInspectorRole([], position: 'Karantin inspektori'),
        InspectorRole.karantin,
      );
      expect(
        resolveInspectorRole(['vet'], position: 'Karantin inspektori'),
        InspectorRole.veterinary,
      );
    });

    test('returns null rather than guessing', () {
      expect(resolveInspectorRole([]), isNull);
      expect(resolveInspectorRole(['admin', 'user']), isNull);
      expect(resolveInspectorRole([''], position: '  '), isNull);
    });

    test('a short keyword does not match inside an unrelated word', () {
      expect(resolveInspectorRole(['processes_manager']), isNull);
      expect(resolveInspectorRole(['developer']), isNull);
    });
  });

  group('User.inspectorRole', () {
    User userWith({List<String> roles = const [], String? position}) => User(
      id: '1',
      username: 'u',
      fullName: 'Test User',
      roles: roles,
      position: position,
    );

    test('derives the role from the token claim', () {
      expect(
        userWith(roles: ['ses_inspector']).inspectorRole,
        InspectorRole.ses,
      );
    });

    test('is null when the claim carries nothing recognisable', () {
      expect(userWith().inspectorRole, isNull);
    });
  });

  group('role presentation', () {
    test('every role has its own colour, icon and label key', () {
      final roles = [null, ...InspectorRole.values];
      expect(
        roles.map(roleColor).toSet().length,
        roles.length - 1, // the unknown role deliberately reuses kGreen
      );
      expect(roles.map(roleIcon).toSet().length, roles.length);
      expect(
        InspectorRole.values.map((r) => r.labelKey).toSet().length,
        InspectorRole.values.length,
      );
    });

    test('every label key is translated in all three languages', () {
      final keys = [
        'roleInspector',
        'roleSectionLabel',
        ...InspectorRole.values.map((r) => r.labelKey),
      ];
      for (final lang in ['uz', 'ru', 'en']) {
        final json =
            jsonDecode(
                  File('assets/translations/$lang.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final key in keys) {
          expect(
            json[key],
            isA<String>().having((s) => s.isNotEmpty, 'is not empty', isTrue),
            reason: '$key missing from $lang.json',
          );
        }
        expect(
          json['appTitle'],
          'Nazorat AAT',
          reason: 'app name in $lang.json',
        );
      }
    });
  });
}
