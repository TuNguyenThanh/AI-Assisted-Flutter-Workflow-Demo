import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:demo_ai_workflow/core/widgets/widgets.dart';
import 'package:demo_ai_workflow/features/auth/presentation/cubit/login_cubit.dart';
import 'package:demo_ai_workflow/features/auth/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Login screen — layout from Figma "Login" (node 16:5).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const routeName = '/login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    // Issue #2 in the session log: first AI draft leaked these controllers.
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context
        .read<LoginCubit>()
        .submit(
          username: _usernameController.text,
          password: _passwordController.text,
        )
        .ignore();
  }

  /// Forgot password and Google SSO are in the design but have no ticket /
  /// backend yet (see AUTH-001 spec, Human review notes).
  void _showNotAvailable(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      body: BlocConsumer<LoginCubit, LoginState>(
        listenWhen: (prev, curr) => prev.status != curr.status,
        listener: (context, state) {
          if (state.status == LoginStatus.success) {
            // Lets iOS Keychain / Android autofill offer to save the login.
            TextInput.finishAutofillContext();
            Navigator.of(context).pushReplacementNamed(ProfilePage.routeName);
          }
        },
        builder: (context, state) {
          final error = state.status == LoginStatus.failure
              ? state.errorMessage
              : null;
          final enabled = !state.isSubmitting;

          return SafeArea(
            child: AutofillGroup(
              // Form on top, SSO pinned to the bottom when there is room;
              // scrolls as a whole on small screens / large text.
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.xl * 2),
                          Semantics(
                            header: true,
                            child: Text(
                              'Login',
                              key: const Key('login_title'),
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl + AppSpacing.sm),
                          AppTextField(
                            key: const Key('login_username'),
                            controller: _usernameController,
                            label: 'Username',
                            hint: 'Enter your username',
                            enabled: enabled,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                          ),
                          const SizedBox(height: AppSpacing.sm + AppSpacing.xs),
                          AppPasswordField(
                            key: const Key('login_password'),
                            controller: _passwordController,
                            hint: 'Enter your password',
                            enabled: enabled,
                            onSubmitted: (_) => _submit(),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              key: const Key('login_forgot_password'),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.secondary,
                                textStyle: textTheme.labelLarge?.copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              onPressed: enabled
                                  ? () => _showNotAvailable(
                                      'Password reset is not available yet.',
                                    )
                                  : null,
                              child: const Text('Forgot Password?'),
                            ),
                          ),
                          if (error != null) ...[
                            AppInlineError(
                              error,
                              key: const Key('login_error'),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            key: const Key('login_submit'),
                            label: 'Login',
                            isLoading: state.isSubmitting,
                            onPressed: _submit,
                          ),
                          const Spacer(),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'or login with',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppButton(
                            key: const Key('login_google'),
                            label: 'Login with Google',
                            variant: AppButtonVariant.outlined,
                            icon: Image.asset(
                              'assets/icons/google.png',
                              width: AppSize.iconMd,
                              height: AppSize.iconMd,
                            ),
                            onPressed: enabled
                                ? () => _showNotAvailable(
                                    'Google sign-in is not available yet.',
                                  )
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
