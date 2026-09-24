import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/session.dart';
import '../../../design/design.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).login(_email.text, _password.text);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Material(
              color: TransitColors.signBlue,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, Space.xxl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Row(
                        children: [
                          const RouteBadge(code: 'T', color: TransitColors.led, size: 64),
                          const SizedBox(width: Space.l),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Transit', style: TransitType.display.copyWith(color: TransitColors.white)),
                                Text(
                                  'College bus service',
                                  style: TransitType.subheading.copyWith(
                                    color: TransitColors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The route colours of the network, as a band under the sign.
            const Row(
              children: [
                Expanded(
                  child: SizedBox(height: 8, child: ColoredBox(color: Color(0xFF0B5CAD))),
                ),
                Expanded(
                  child: SizedBox(height: 8, child: ColoredBox(color: Color(0xFF00857C))),
                ),
                Expanded(
                  child: SizedBox(height: 8, child: ColoredBox(color: Color(0xFF8C1D40))),
                ),
              ],
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(Space.gutter),
                  child: Form(
                    key: _form,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: Space.l),
                          const Text('Sign in', style: TransitType.title),
                          const SizedBox(height: Space.xs),
                          Text(
                            'Use the college email the transport office registered for you.',
                            style: TransitType.body.copyWith(color: TransitColors.inkSoft),
                          ),
                          const SizedBox(height: Space.xl),
                          TextFormField(
                            controller: _email,
                            decoration: const InputDecoration(labelText: 'College email'),
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || !v.contains('@')) ? 'Enter your college email' : null,
                          ),
                          const SizedBox(height: Space.m),
                          TextFormField(
                            controller: _password,
                            decoration: const InputDecoration(labelText: 'Password'),
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: Space.m),
                            Container(
                              padding: const EdgeInsets.all(Space.m),
                              decoration: const BoxDecoration(
                                color: TransitColors.white,
                                border: Border(left: BorderSide(color: TransitColors.late, width: 5)),
                              ),
                              child: Text(_error!, style: TransitType.body),
                            ),
                          ],
                          const SizedBox(height: Space.xl),
                          SignButton(label: 'Sign in', onPressed: _submit, busy: _busy, expand: true, height: 56),
                          if (kDebugMode) ...[
                            const SizedBox(height: Space.xl),
                            Text(
                              'Demo accounts (password transit123): admin@college.edu, driver1@college.edu, '
                              'student1@college.edu',
                              style: TransitType.small.copyWith(color: TransitColors.inkSoft),
                            ),
                          ],
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
    );
  }
}
