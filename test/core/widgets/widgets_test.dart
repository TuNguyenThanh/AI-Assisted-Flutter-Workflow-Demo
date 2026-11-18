import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:demo_ai_workflow/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppButton', () {
    testWidgets('calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Go', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('loading: disabled, spinner, same size, announced', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(AppButton(label: 'Sign in', onPressed: () {})),
      );
      final idleSize = tester.getSize(find.byType(FilledButton));

      await tester.pumpWidget(
        _host(AppButton(label: 'Sign in', onPressed: () {}, isLoading: true)),
      );

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)), idleSize);
      expect(find.bySemanticsLabel('Sign in, loading'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('outlined variant', (tester) async {
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Retry',
            onPressed: () {},
            variant: AppButtonVariant.outlined,
          ),
        ),
      );
      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });

  testWidgets('AppPasswordField toggles visibility', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(AppPasswordField(controller: controller)));

    bool obscured() =>
        tester.widget<TextField>(find.byType(TextField)).obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);
  });

  group('AppButton with icon', () {
    testWidgets('shows icon, label is tappable, semantics is just label', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Login with Google',
            icon: const Icon(Icons.star, key: Key('btn_icon')),
            variant: AppButtonVariant.outlined,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byKey(const Key('btn_icon')), findsOneWidget);
      await tester.tap(find.text('Login with Google'));
      expect(taps, 1);
      expect(find.bySemanticsLabel('Login with Google'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('star')), findsNothing);
      semantics.dispose();
    });

    testWidgets('loading with icon: disabled, spinner, announced', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Go',
            icon: const Icon(Icons.star),
            onPressed: () {},
            isLoading: true,
          ),
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Go, loading'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('long label at 360dp and 1.3x does not overflow', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
            body: AppButton(
              label: 'Continue with a very long provider name',
              icon: const Icon(Icons.star),
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('AppPasswordField icon switches with visibility', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(AppPasswordField(controller: controller)));

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    expect(find.byTooltip('Hide password'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('AppPasswordField shows hint', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(AppPasswordField(controller: controller, hint: 'Enter pw')),
    );
    expect(find.text('Enter pw'), findsOneWidget);
  });

  testWidgets('AppInlineError is a live region for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AppInlineError('Wrong password')));
    final semantics = tester.getSemantics(find.text('Wrong password'));
    expect(semantics.flagsCollection.isLiveRegion, isTrue);
  });

  group('AppErrorView', () {
    testWidgets('shows retry only when onRetry is given', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _host(AppErrorView(message: 'Offline', onRetry: () => retried = true)),
      );
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);

      await tester.pumpWidget(_host(const AppErrorView(message: 'Offline')));
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('AppAvatar', () {
    testWidgets('shows up to two initials', (tester) async {
      await tester.pumpWidget(_host(const AppAvatar(name: 'Emily Johnson')));
      expect(find.text('EJ'), findsOneWidget);
    });

    testWidgets('falls back to "?" for empty names', (tester) async {
      await tester.pumpWidget(_host(const AppAvatar(name: '  ')));
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('broken image URL does not throw', (tester) async {
      await tester.pumpWidget(
        _host(const AppAvatar(name: 'A B', imageUrl: 'https://x.invalid/a')),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('AB'), findsOneWidget);
    });
  });

  testWidgets('components render in dark mode', (tester) async {
    await tester.pumpWidget(
      _host(
        const AppErrorView(message: 'Offline'),
        theme: AppTheme.dark(),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(icon.color, AppColorTokens.dark.error);
  });
}
