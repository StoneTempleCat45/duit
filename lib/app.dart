import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/budget/budget_providers.dart';
import 'features/home/home_shell.dart';
import 'features/setup/setup_screen.dart';
import 'home_widget/widget_sync.dart';

/// Lets code outside the widget tree open screens (used by the home screen
/// widget's quick-add button in Milestone 3).
final rootNavigatorKey = GlobalKey<NavigatorState>();

class DuitApp extends StatelessWidget {
  const DuitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duit',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const RootGate(),
    );
  }
}

/// Shows setup on first launch, then the main app.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(widgetSyncProvider); // keeps the home screen widget up to date
    final settings = ref.watch(settingsProvider);

    final Widget child;
    if (settings.hasValue) {
      child = settings.value == null
          ? const SetupScreen(key: ValueKey('setup'))
          : const HomeShell(key: ValueKey('home'));
    } else if (settings.hasError) {
      child = _ErrorView(key: const ValueKey('error'), error: settings.error!);
    } else {
      child = const _Splash(key: ValueKey('splash'));
    }

    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: child);
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Duit'),
            TextSpan(text: '.', style: TextStyle(color: theme.colorScheme.primary)),
          ]),
          style: theme.textTheme.displaySmall,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not open your data.\n$error', textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
