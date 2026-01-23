import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:red_time_app/view/main_viewmodel.dart';
import 'package:red_time_app/view/calendar/calendar_view.dart';
import 'package:red_time_app/view/my/my_view.dart';
import 'package:red_time_app/view/report/report_view.dart';
import 'package:red_time_app/widgets/bottom_nav.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final Set<int> _loadedIndices = {0};

  NavTab _indexToTab(int index) {
    switch (index) {
      case 0:
        return NavTab.calendar;
      case 1:
        return NavTab.report;
      case 2:
        return NavTab.my;
      default:
        return NavTab.calendar;
    }
  }

  int _tabToIndex(NavTab tab) {
    switch (tab) {
      case NavTab.calendar:
        return 0;
      case NavTab.report:
        return 1;
      case NavTab.my:
        return 2;
    }
  }

  Widget _buildPage(int index, Widget page) {
    if (_loadedIndices.contains(index)) {
      return page;
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Selector<MainViewModel, int>(
        selector: (_, vm) => vm.currentIndex,
        builder: (_, index, __) {
          _loadedIndices.add(index);
          return IndexedStack(
            index: index,
            children: [
              _buildPage(0, CalendarView(isActive: index == 0)),
              _buildPage(1, const ReportView()),
              _buildPage(2, const MyView()),
            ],
          );
        },
      ),
      bottomNavigationBar: Selector<MainViewModel, int>(
        selector: (_, vm) => vm.currentIndex,
        builder: (context, index, __) {
          return BottomNav(
            current: _indexToTab(index),
            onTap: (tab) {
              final newIndex = _tabToIndex(tab);
              context.read<MainViewModel>().changeTab(newIndex);
            },
          );
        },
      ),
    );
  }
}
