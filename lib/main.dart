import 'package:demo_ai_workflow/app.dart';
import 'package:demo_ai_workflow/core/di/injection.dart';
import 'package:demo_ai_workflow/features/auth/domain/repositories/auth_repository.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/login_page.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();

  final hasSession = await sl<AuthRepository>().hasSession();
  runApp(
    App(
      initialRoute: hasSession ? ProfilePage.routeName : LoginPage.routeName,
    ),
  );
}
