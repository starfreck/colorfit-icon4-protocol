import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/storage/data_storage.dart';
import 'features/home/home_screen.dart';
import 'features/device/device_screen.dart';
import 'features/settings/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataStorage().init();
  runApp(const ProviderScope(child: ColorFitApp()));
}

class ColorFitApp extends StatelessWidget {
  const ColorFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ColorFit Icon 4',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          DeviceScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppTheme.background,
        indicatorColor: AppTheme.secondary,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_outlined),
            selectedIcon: Icon(Icons.bluetooth),
            label: 'Device',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
