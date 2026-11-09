import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../apiMapper/auth.dart' as auth_api;
import '../pages/menu_entries.dart';
import '../store/models/models.dart';
import '../utils/commemorator.dart';
import 'api_error_view.dart' show failureMessage;

/// Авторизация и разделы шторки обновляются вместе с состоянием сессии.
class DrawerMenuSections extends StatefulWidget {
  const DrawerMenuSections({super.key});

  @override
  State<DrawerMenuSections> createState() => _DrawerMenuSectionsState();
}

class _DrawerMenuSectionsState extends State<DrawerMenuSections> {
  bool _signingIn = false;

  Future<void> _signIn() async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      await auth_api.signInWithGoogle(StoreProvider.of<AppState>(context));
      forgetCommemorator();
      unawaited(refreshCommemorator());
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _showError('Не удалось войти через Google');
      }
    } catch (error) {
      _showError(failureMessage(error, 'Не удалось войти'));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => StoreConnector<AppState, AuthState>(
    converter: (store) => store.state.auth,
    distinct: true,
    builder: (context, auth) {
      bool visible(MenuEntry entry) => switch (entry.visibility) {
        MenuVisibility.always => true,
        MenuVisibility.signedIn => auth.isSignedIn,
        MenuVisibility.commemorator => auth.isSignedIn && auth.isCommemorator,
      };

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!auth.isSignedIn) ...[
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(_signingIn ? 'Входим…' : 'Войти через Google'),
              enabled: !_signingIn,
              onTap: _signingIn ? null : _signIn,
            ),
            const Divider(height: 1),
          ],
          for (final section in drawerSections)
            if (section.entries.any(visible)) ...[
              if (section.title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    section.title!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              for (final entry in section.entries.where(visible))
                ListTile(
                  title: Text(
                    entry.title,
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: entry.requiresSignIn && !auth.isSignedIn
                      ? const Text('Доступен после входа')
                      : null,
                  enabled: !entry.requiresSignIn || auth.isSignedIn,
                  selected:
                      ModalRoute.of(context)?.settings.name == entry.route,
                  onTap: entry.requiresSignIn && !auth.isSignedIn
                      ? null
                      : () => Navigator.pushNamed(context, entry.route),
                ),
              const Divider(height: 1),
            ],
        ],
      );
    },
  );
}
