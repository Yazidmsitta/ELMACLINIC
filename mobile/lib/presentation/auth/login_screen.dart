import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/app_failure.dart';
import '../theme/app_theme.dart';
import '../widgets/elma_widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _obscure = true, _remember = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.auth.loading && _form.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      widget.auth.login(_email.text, _password.text, remember: _remember);
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: ElmaDecor.login),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 250),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 36,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/branding/logo.png',
                                width: 180,
                                semanticLabel: 'ELMA Clinic',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bienvenue',
                                style: ElmaType.display.copyWith(
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Connectez-vous à votre espace',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: .6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(ElmaRadii.login),
                          ),
                          boxShadow: ElmaDecor.panelShadow,
                        ),
                        padding: EdgeInsets.fromLTRB(
                          24,
                          32,
                          24,
                          40 + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: AutofillGroup(
                              child: Form(
                                key: _form,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.auth.error != null) ...[
                                      Semantics(
                                        liveRegion: true,
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: ElmaColors.redLight,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            friendlyError(widget.auth.error!),
                                            style: const TextStyle(
                                              color: ElmaColors.red,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    Text(
                                      'EMAIL',
                                      style: ElmaType.label.copyWith(
                                        color: ElmaColors.secondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _email,
                                      enabled: !widget.auth.loading,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [
                                        AutofillHints.username,
                                      ],
                                      textInputAction: TextInputAction.next,
                                      style: ElmaType.body,
                                      decoration: const InputDecoration(
                                        hintText: 'votre@email.com',
                                      ),
                                      validator: (value) =>
                                          value != null &&
                                              RegExp(
                                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                              ).hasMatch(value.trim())
                                          ? null
                                          : 'Saisissez une adresse e-mail valide.',
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'MOT DE PASSE',
                                      style: ElmaType.label.copyWith(
                                        color: ElmaColors.secondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _password,
                                      enabled: !widget.auth.loading,
                                      obscureText: _obscure,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      onFieldSubmitted: (_) => _submit(),
                                      style: ElmaType.body,
                                      decoration: InputDecoration(
                                        hintText: '••••••••',
                                        suffixIcon: IconButton(
                                          tooltip: _obscure
                                              ? 'Afficher le mot de passe'
                                              : 'Masquer le mot de passe',
                                          onPressed: () => setState(
                                            () => _obscure = !_obscure,
                                          ),
                                          icon: ElmaIcon(
                                            _obscure ? 'Eye' : 'EyeOff',
                                            size: 18,
                                            color: ElmaColors.muted,
                                          ),
                                        ),
                                      ),
                                      validator: (value) =>
                                          value == null || value.isEmpty
                                          ? 'Saisissez votre mot de passe.'
                                          : null,
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 8,
                                      children: [
                                        InkWell(
                                          onTap: widget.auth.loading
                                              ? null
                                              : () => setState(
                                                  () => _remember = !_remember,
                                                ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value: _remember,
                                                onChanged: widget.auth.loading
                                                    ? null
                                                    : (v) => setState(
                                                        () => _remember = v!,
                                                      ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              const Text(
                                                'Se souvenir',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: ElmaColors.secondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => showElmaNotice(
                                            context,
                                            'Mot de passe oublié ?',
                                            'Contactez votre administrateur pour rétablir l’accès à votre compte.',
                                          ),
                                          child: const Text(
                                            'Mot de passe oublié ?',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    ElmaButton(
                                      label: 'Connexion',
                                      loading: widget.auth.loading,
                                      onPressed: _submit,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
