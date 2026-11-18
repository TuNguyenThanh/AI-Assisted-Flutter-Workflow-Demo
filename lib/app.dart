import 'package:demo_ai_workflow/core/di/injection.dart';
import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/login_cubit.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/profile_cubit.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/login_page.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class App extends StatelessWidget {
  const App({required this.initialRoute, super.key});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Workflow Demo',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialRoute: initialRoute,
      routes: {
        LoginPage.routeName: (_) => BlocProvider(
          create: (_) => sl<LoginCubit>(),
          child: const LoginPage(),
        ),
        ProfilePage.routeName: (_) => BlocProvider(
          create: (_) => sl<ProfileCubit>()..load().ignore(),
          child: const ProfilePage(),
        ),
      },
    );
  }
}
