import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:demo_ai_workflow/core/widgets/widgets.dart';
import 'package:demo_ai_workflow/features/auth/domain/entities/user.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/profile_cubit.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const routeName = '/profile';

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileCubit, ProfileState>(
      listener: (context, state) {
        final goToLogin =
            state is ProfileLoggedOut ||
            (state is ProfileError && state.sessionExpired);
        if (goToLogin) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            LoginPage.routeName,
            (_) => false,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              IconButton(
                key: const Key('profile_logout'),
                tooltip: 'Log out',
                icon: const Icon(Icons.logout),
                onPressed: () => context.read<ProfileCubit>().logout(),
              ),
            ],
          ),
          body: switch (state) {
            ProfileLoading() || ProfileLoggedOut() => const Center(
              child: CircularProgressIndicator(),
            ),
            ProfileError(:final message) => AppErrorView(
              message: message,
              onRetry: () => context.read<ProfileCubit>().load(),
            ),
            ProfileLoaded(:final user) => _ProfileView(user: user),
          },
        );
      },
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Center(
          child: AppAvatar(name: user.fullName, imageUrl: user.avatarUrl),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          user.fullName,
          key: const Key('profile_name'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          leading: const Icon(Icons.alternate_email),
          title: Text(user.username),
        ),
        ListTile(leading: const Icon(Icons.email), title: Text(user.email)),
      ],
    );
  }
}
