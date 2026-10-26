import 'package:flutter/material.dart';

import 'models/wallet_store.dart';
import 'models/profile_store.dart';
import 'screens/home_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/scan_qr_screen.dart';
import 'screens/all_services_screen.dart';
import 'models/recipient_store.dart';
import 'models/pin_lock_store.dart';
import 'widgets/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await walletStore.initialize();
    await recipientStore.initialize();
    await profileStore.initialize();
    runApp(const KinaWalletApp());
  } catch (error) {
    debugPrint('Demo wallet could not load: $error');
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load the saved demo wallet. Close and reopen the app to retry. Saved data has not been erased.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const navy = Color(0xFF102443);
const walletBlue = Color(0xFF1769EF);

class KinaWalletApp extends StatelessWidget {
  const KinaWalletApp({super.key, this.lockStore});
  final PinLockStore? lockStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kina Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: walletBlue).copyWith(
          primary: walletBlue,
          onPrimary: Colors.white,
          secondary: navy,
          surface: Colors.white,
          onSurface: navy,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: navy,
          displayColor: navy,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 68,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE8EDF5)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 19,
          ),
          labelStyle: const TextStyle(color: Color(0xFF60718A)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFDCE4F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: walletBlue, width: 1.5),
          ),
          errorMaxLines: 3,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: walletBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(64, 54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: walletBlue,
            minimumSize: const Size(64, 54),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            side: const BorderSide(color: Color(0xFFB7CDF3)),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: walletBlue),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: Color(0xFFE8F0FF),
          height: 76,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFF5F7FB),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFE8EDF5)),
        listTileTheme: const ListTileThemeData(
          iconColor: walletBlue,
          textColor: navy,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      builder: (context, child) =>
          AppLockGate(store: lockStore ?? pinLockStore, child: child!),
      home: const WalletShell(),
    );
  }
}

class WalletShell extends StatefulWidget {
  const WalletShell({super.key});

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    // Keep the mobile layout readable when previewing in a desktop browser.
    return ColoredBox(
      color: const Color(0xFFE6EBF3),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Scaffold(
            body: IndexedStack(
              index: selectedTab >= 3 ? selectedTab - 1 : selectedTab,
              children: [
                const HomeScreen(),
                const ActivityScreen(),
                const AllServicesScreen(),
                const ProfileScreen(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: selectedTab,
              onDestinationSelected: (index) {
                if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ScanQrScreen(),
                    ),
                  );
                } else {
                  setState(() => selectedTab = index);
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: DecoratedBox(
                    decoration: BoxDecoration(
                      color: walletBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  label: 'Scan QR',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: 'Services',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Explains the next flow without pretending that a real payment happened.
void showFeaturePreview(
  BuildContext context,
  String title,
  String description,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(description, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            const Text(
              'Prototype preview only. No money moves and no information is submitted.',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
