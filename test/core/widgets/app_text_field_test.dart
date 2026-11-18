import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:demo_ai_workflow/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppTextField', () {
    testWidgets('shows label above the box and hint inside', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(
          AppTextField(
            key: const Key('tf'),
            controller: c,
            label: 'Username',
            hint: 'Enter name',
          ),
        ),
      );
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Enter name'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Username')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(TextField)).dy),
      );
    });

    testWidgets('enabled=false disables the TextField', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(AppTextField(controller: c, label: 'Username', enabled: false)),
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('accepts typed text', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(AppTextField(controller: c, label: 'Username')),
      );
      await tester.enterText(find.byType(TextField), 'emilys');
      expect(c.text, 'emilys');
    });

    testWidgets('semantics: field carries label, label Text not separate', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(AppTextField(controller: c, label: 'Username')),
      );
      expect(find.bySemanticsLabel('Username'), findsOneWidget);
      final node = tester.getSemantics(find.byType(TextField));
      expect(node.label, contains('Username'));
      expect(node.flagsCollection.isTextField, isTrue);
      semantics.dispose();
    });

    testWidgets('dark theme: border comes from the dark scheme', (
      tester,
    ) async {
      final dark = AppTheme.dark();
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        _host(
          AppTextField(controller: c, label: 'Username', hint: 'h'),
          theme: dark,
        ),
      );
      expect(tester.takeException(), isNull);
      final decoration = tester
          .widget<InputDecorator>(find.byType(InputDecorator))
          .decoration;
      final border = decoration.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, dark.colorScheme.outlineVariant);
    });

    testWidgets('360dp and 1.3x text: no overflow', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppTextField(
                controller: c,
                label: 'Username',
                hint: 'Enter your username',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
