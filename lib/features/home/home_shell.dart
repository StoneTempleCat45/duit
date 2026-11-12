import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/widgets/common.dart';
import '../dashboard/dashboard_screen.dart';
import '../expenses/add_edit_expense_screen.dart';
import '../expenses/history_screen.dart';
import '../insights/insights_screen.dart';
import 'glass_nav_bar.dart';

/// Main screen: Home, Insights and History tabs with a floating glass tab bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  /// Makes sure a widget tap that launched the app is handled only once.
  static bool _handledLaunchUri = false;

  static const _items = [
    NavItem(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Home'),
    NavItem(Icons.insights_outlined, Icons.insights_rounded, 'Insights'),
    NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'History'),
  ];

  int _index = 0;
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    // Taps on the home screen widget while the app is running.
    _widgetClicks = HomeWidget.widgetClicked.listen(_handleWidgetUri, onError: (_) {});
    // A tap on the widget that started the app.
    if (!_handledLaunchUri) {
      _handledLaunchUri = true;
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    super.dispose();
  }

  /// "duit://add" comes from the widget's + button.
  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    if (uri.host == 'add') {
      setState(() => _index = 0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openAddExpense(context);
      });
    }
  }

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(onSeeAll: () => _goTo(2)),
      const InsightsScreen(),
      const HistoryScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: AmbientBackground(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < tabs.length; i++)
              IgnorePointer(
                ignoring: i != _index,
                child: ExcludeSemantics(
                  excluding: i != _index,
                  child: AnimatedOpacity(
                    opacity: i == _index ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: TickerMode(enabled: i == _index, child: tabs[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: GlassNavBar(
        items: _items,
        selectedIndex: _index,
        onSelected: _goTo,
        onAdd: () => openAddExpense(context),
      ),
    );
  }
}
