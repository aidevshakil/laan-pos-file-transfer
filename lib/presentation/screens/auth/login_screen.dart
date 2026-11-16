import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/decorations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _register = false;
  bool _obscure = true;
  String? _error;

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static final _usernamePattern = RegExp(r'^[A-Za-z0-9_.\-]{3,32}$');

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final u = _username.text.trim();
    final p = _password.text;
    context.read<AuthBloc>().add(
          _register ? RegisterSubmitted(username: u, password: p) : LoginSubmitted(username: u, password: p),
        );
  }

  void _toggleMode() => setState(() {
        _register = !_register;
        _error = null;
        _formKey.currentState?.reset();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthFailure) setState(() => _error = state.message);
          if (state is AuthRegistrationSuccess) {
            if (_register) _toggleMode();
            showAppSnack(context, state.message);
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return Stack(
            children: [
              const Align(alignment: Alignment.bottomCenter, child: WaveBackdrop(height: 130)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AutofillGroup(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: HaloIllustration(
                                  icon: _register ? Icons.person_add_alt_1_rounded : Icons.shield_rounded,
                                  size: 132,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _register ? 'Create Account' : 'Welcome Back!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _register
                                    ? 'Register an operator account on the LAAN POS server'
                                    : 'Sign in to continue to LAAN POS',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 28),
                              TextFormField(
                                controller: _username,
                                enabled: !loading,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline_rounded),
                                ),
                                validator: (v) {
                                  final s = v?.trim() ?? '';
                                  if (s.isEmpty) return 'Enter your username';
                                  if (_register && !_usernamePattern.hasMatch(s)) {
                                    return '3–32 characters: letters, numbers, _ . -';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _password,
                                enabled: !loading,
                                obscureText: _obscure,
                                autofillHints: [
                                  _register ? AutofillHints.newPassword : AutofillHints.password,
                                ],
                                textInputAction: _register ? TextInputAction.next : TextInputAction.done,
                                onFieldSubmitted: (_) => _register ? null : _submit(),
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure ? 'Show password' : 'Hide password',
                                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                                validator: (v) {
                                  if ((v ?? '').isEmpty) return 'Enter your password';
                                  if (_register && v!.length < 6) return 'Use at least 6 characters';
                                  return null;
                                },
                              ),
                              if (_register) ...[
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _confirm,
                                  enabled: !loading,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: const InputDecoration(
                                    hintText: 'Confirm password',
                                    prefixIcon: Icon(Icons.lock_reset_rounded),
                                  ),
                                  validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                InlineMessage.error(_error!),
                              ],
                              const SizedBox(height: 22),
                              FilledButton(
                                onPressed: loading ? null : _submit,
                                child: loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                      )
                                    : Text(_register ? 'Create account' : 'Login'),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _register ? 'Already have an account?' : "Don't have an account?",
                                    style: const TextStyle(color: AppColors.textSecondary),
                                  ),
                                  TextButton(
                                    onPressed: loading ? null : _toggleMode,
                                    child: Text(_register ? 'Log in' : 'Register'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.dns_outlined, size: 14, color: AppColors.textMuted),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      ApiConstants.defaultBaseUrl,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
