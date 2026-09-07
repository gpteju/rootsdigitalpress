// CHANGE-2026-09-07: Main Entry Point & Multi-Platform Navigation Shell for Printout Billing Software.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/company_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/paper_provider.dart';
import 'providers/billing_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/report_provider.dart';
import 'providers/printer_provider.dart';
import 'providers/auth_provider.dart';

import 'screens/dashboard_screen.dart';
import 'screens/company_screen.dart';
import 'screens/customer_screen.dart';
import 'screens/supplier_screen.dart';
import 'screens/paper_masters_screen.dart';
import 'screens/printout_type_screen.dart';
import 'screens/tax_screen.dart';
import 'screens/rate_screen.dart';
import 'screens/sales_bill_screen.dart';
import 'screens/customer_payment_screen.dart';
import 'screens/supplier_purchase_screen.dart';
import 'screens/stock_ledger_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/printer_settings_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => SupplierProvider()),
        ChangeNotifierProvider(create: (_) => PaperProvider()),
        ChangeNotifierProvider(create: (_) => BillingProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
        ChangeNotifierProvider(create: (_) => PrinterProvider()),
      ],
      child: const PrintoutBillingApp(),
    ),
  );
}

class PrintoutBillingApp extends StatelessWidget {
  const PrintoutBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Printout Company Billing Software',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: auth.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (auth.isAuthenticated ? const MainNavigationShell() : const LoginScreen()),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _selectedIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final List<Widget> screens = [
      DashboardScreen(onNavigateToTab: _navigateToTab),
      const CompanyScreen(),
      const CustomerScreen(),
      const SupplierScreen(),
      const PaperMastersScreen(),
      const PrintoutTypeScreen(),
      const TaxScreen(),
      const RateScreen(),
      const SalesBillScreen(),
      const CustomerPaymentScreen(),
      const SupplierPurchaseScreen(),
      const StockLedgerScreen(),
      const ReportsScreen(),
      const PrinterSettingsScreen(),
    ];

    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Dashboard Overview', 'icon': Icons.dashboard_outlined},
      {'title': 'Company Master', 'icon': Icons.business_outlined},
      {'title': 'Customer Master', 'icon': Icons.people_outline},
      {'title': 'Supplier Master', 'icon': Icons.local_shipping_outlined},
      {'title': 'Paper Masters', 'icon': Icons.description_outlined},
      {'title': 'Printout Type Master', 'icon': Icons.print_outlined},
      {'title': 'Tax Master', 'icon': Icons.account_balance_outlined},
      {'title': 'Rate Master', 'icon': Icons.sell_outlined},
      {'title': 'Sales Billing', 'icon': Icons.receipt_long_outlined},
      {'title': 'Customer Payments', 'icon': Icons.payment_outlined},
      {'title': 'Supplier Purchases', 'icon': Icons.add_shopping_cart_outlined},
      {'title': 'Stock Ledger', 'icon': Icons.inventory_2_outlined},
      {'title': 'Reports & Aging', 'icon': Icons.assessment_outlined},
      {'title': 'Printer Settings', 'icon': Icons.settings_applications_outlined},
    ];

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.print, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Text('Printout Company Billing Software', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
              child: const Text('PRODUCTION READY', style: TextStyle(fontSize: 10, letterSpacing: 1)),
            ),
          ],
        ),
        actions: [
          if (user != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, size: 18, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      '${user.fullName} (${user.role})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sign Out',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // Permanent Side Drawer for Desktop / Web
          if (isDesktop)
            Container(
              width: 240,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: menuItems.length,
                itemBuilder: (context, idx) {
                  final item = menuItems[idx];
                  final bool isSelected = _selectedIndex == idx;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(item['icon'], color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 20),
                      title: Text(
                        item['title'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      onTap: () => setState(() => _selectedIndex = idx),
                    ),
                  );
                },
              ),
            ),

          // Main View Content Area
          Expanded(
            child: screens[_selectedIndex],
          ),
        ],
      ),
      // Drawer for Mobile / Small Screens
      drawer: isDesktop
          ? null
          : Drawer(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: menuItems.length + 1,
                itemBuilder: (context, idx) {
                  if (idx == 0) {
                    return DrawerHeader(
                      decoration: const BoxDecoration(color: AppColors.primary),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.print, color: Colors.white, size: 40),
                          SizedBox(height: 10),
                          Text('Printout Billing System', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }
                  final item = menuItems[idx - 1];
                  final bool isSelected = _selectedIndex == idx - 1;

                  return ListTile(
                    leading: Icon(item['icon'], color: isSelected ? AppColors.primary : AppColors.textSecondary),
                    title: Text(item['title'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _selectedIndex = idx - 1);
                    },
                  );
                },
              ),
            ),
    );
  }
}
