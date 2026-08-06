import 'package:flutter/material.dart';

import '../main.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool registerMode = false;
  bool obscure = true;
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void submit() {
    if (!formKey.currentState!.validate()) return;
    final state = AppScope.of(context);
    final error = registerMode
        ? state.register(
            name: name.text,
            username: username.text,
            email: email.text,
            password: password.text,
          )
        : state.login(email.text, password.text);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.movie_filter_rounded, size: 40),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'فیلم‌یاب',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    registerMode
                        ? 'حساب بساز و تماشایت را ثبت کن'
                        : 'دنیای فیلم و سریال‌های تو',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 30),
                  if (registerMode) ...[
                    TextFormField(
                      controller: name,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'نام و نام خانوادگی',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.trim().length < 2
                          ? 'نام را وارد کنید'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: username,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'نام کاربری',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                      validator: (v) => v == null || v.trim().length < 3
                          ? 'حداقل ۳ کاراکتر'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'ایمیل',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) => v != null && v.contains('@')
                        ? null
                        : 'ایمیل معتبر وارد کنید',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    obscureText: obscure,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'رمز عبور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.length < 6 ? 'حداقل ۶ کاراکتر' : null,
                  ),
                  if (!registerMode)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _resetDialog,
                        child: const Text('رمز عبور را فراموش کرده‌ام'),
                      ),
                    ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.all(17),
                    ),
                    child: Text(registerMode ? 'ساخت حساب' : 'ورود'),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => registerMode = !registerMode),
                    child: Text(
                      registerMode
                          ? 'حساب دارم؛ وارد می‌شوم'
                          : 'حساب ندارم؛ ثبت‌نام',
                    ),
                  ),
                  const Divider(height: 28),
                  OutlinedButton.icon(
                    onPressed: AppScope.of(context).enterAsGuest,
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('ورود به‌عنوان مهمان'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'اطلاعات حساب و فعالیت‌ها فقط روی همین دستگاه ذخیره می‌شوند.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void _resetDialog() {
    final newPassword = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغییر رمز عبور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'ایمیل حساب'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'رمز جدید'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              final error = AppScope.of(
                context,
              ).resetPassword(email.text, newPassword.text);
              if (error == null) Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(content: Text(error ?? 'رمز عبور تغییر کرد.')),
              );
            },
            child: const Text('ثبت'),
          ),
        ],
      ),
    ).whenComplete(newPassword.dispose);
  }
}
