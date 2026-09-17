// CHANGE-2026-09-08: Reorganized Left Side Menu navigation into Master, Transaction, Stock Ledger, Reports & Aging, and Printer Settings.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/company_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/supplier_provider.dart';
import 'providers/paper_provider.dart';
import 'providers/billing_provider.dart';
import 'providers/payment_provider.dart';
import 'providers/job_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/report_provider.dart';
import 'providers/printer_provider.dart';

import 'screens/login_screen.dart';
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
        ChangeNotifierProvider(create: (_) => JobProvider()),
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
      title: 'Roots Digital Press - Billing',
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
  String _selectedKey = 'dashboard';

  void _navigateToTab(int index) {
    final indexMap = {
      0: 'dashboard',
      1: 'master_company',
      2: 'master_customer',
      3: 'master_supplier',
      4: 'master_paper',
      5: 'master_printout_type',
      6: 'master_tax',
      7: 'master_rate',
      8: 'trans_sales',
      9: 'trans_payments',
      10: 'trans_purchases',
      11: 'stock',
      12: 'reports_daily_sales',
      13: 'printer',
    };
    if (indexMap.containsKey(index)) {
      setState(() => _selectedKey = indexMap[index]!);
    }
  }

  Widget _buildScreen() {
    switch (_selectedKey) {
      case 'dashboard':
        return DashboardScreen(onNavigateToTab: _navigateToTab);

      // Master Group
      case 'master_company':
        return const CompanyScreen();
      case 'master_customer':
        return const CustomerScreen();
      case 'master_supplier':
        return const SupplierScreen();
      case 'master_paper_type':
        return const PaperMastersScreen(initialTabIndex: 1);
      case 'master_paper_gsm':
        return const PaperMastersScreen(initialTabIndex: 2);
      case 'master_paper_size':
        return const PaperMastersScreen(initialTabIndex: 3);
      case 'master_paper':
        return const PaperMastersScreen(initialTabIndex: 0);
      case 'master_printout_type':
        return const PrintoutTypeScreen();
      case 'master_tax':
        return const TaxScreen();
      case 'master_rate':
        return const RateScreen();

      // Transaction Group
      case 'trans_sales':
        return const SalesBillScreen();
      case 'trans_payments':
        return const CustomerPaymentScreen();
      case 'trans_purchases':
        return const SupplierPurchaseScreen();

      // Stock Ledger
      case 'stock':
        return const StockLedgerScreen();

      // Reports & Aging Group
      case 'reports_daily_sales':
        return ReportsScreen(key: ValueKey(_selectedKey), initialTabIndex: 0);
      case 'reports_customer_wise':
        return ReportsScreen(key: ValueKey(_selectedKey), initialTabIndex: 1);
      case 'reports_customer_aging':
        return ReportsScreen(key: ValueKey(_selectedKey), initialTabIndex: 2);
      case 'reports_customer_pending':
        return ReportsScreen(key: ValueKey(_selectedKey), initialTabIndex: 3);
      case 'reports_supplier_purchases':
        return ReportsScreen(key: ValueKey(_selectedKey), initialTabIndex: 4);
      case 'reports_stock':
        return ReportsScreen(key: ValueKey(_selectedKey), initialTabIndex: 5);
      case 'reports_customer_payment':
        return ReportsScreen(key: ValueKey(_selectedKey), initialTabIndex: 6);

      // Printer Settings
      case 'printer':
        return const PrinterSettingsScreen();

      default:
        return DashboardScreen(onNavigateToTab: _navigateToTab);
    }
  }

  List<Map<String, dynamic>> _getMenuTree() {
    return [
      {
        'key': 'dashboard',
        'title': 'Dashboard Overview',
        'icon': Icons.dashboard_outlined,
      },
      {
        'title': 'Master',
        'icon': Icons.folder_outlined,
        'children': [
          {'key': 'master_company', 'title': 'Company Master', 'icon': Icons.business_outlined},
          {'key': 'master_customer', 'title': 'Customer Master', 'icon': Icons.people_outline},
          {'key': 'master_supplier', 'title': 'Supplier Master', 'icon': Icons.local_shipping_outlined},
          {'key': 'master_paper_type', 'title': 'Paper Type', 'icon': Icons.style_outlined},
          {'key': 'master_paper_gsm', 'title': 'Paper GSM', 'icon': Icons.line_weight_outlined},
          {'key': 'master_paper_size', 'title': 'Paper Size', 'icon': Icons.aspect_ratio_outlined},
          {'key': 'master_paper', 'title': 'Paper', 'icon': Icons.description_outlined},
          {'key': 'master_printout_type', 'title': 'Printout Type', 'icon': Icons.print_outlined},
          {'key': 'master_tax', 'title': 'Tax Master', 'icon': Icons.account_balance_outlined},
          {'key': 'master_rate', 'title': 'Rate Master', 'icon': Icons.sell_outlined},
        ]
      },
      {
        'title': 'Transaction',
        'icon': Icons.point_of_sale_outlined,
        'children': [
          {'key': 'trans_sales', 'title': 'Sales Billing', 'icon': Icons.receipt_long_outlined},
          {'key': 'trans_payments', 'title': 'Customer Payments', 'icon': Icons.payment_outlined},
          {'key': 'trans_purchases', 'title': 'Supplier Purchase', 'icon': Icons.add_shopping_cart_outlined},
        ]
      },
      {
        'key': 'stock',
        'title': 'Stock Ledger',
        'icon': Icons.inventory_2_outlined,
      },
      {
        'title': 'Reports & Aging',
        'icon': Icons.assessment_outlined,
        'children': [
          {'key': 'reports_daily_sales', 'title': 'Daily Sales', 'icon': Icons.today_outlined},
          {'key': 'reports_customer_wise', 'title': 'Customer Wise Report', 'icon': Icons.analytics_outlined},
          {'key': 'reports_customer_aging', 'title': 'Customer Aging', 'icon': Icons.history_outlined},
          {'key': 'reports_customer_pending', 'title': 'Customer Pending', 'icon': Icons.pending_actions_outlined},
          {'key': 'reports_supplier_purchases', 'title': 'Supplier Wise Purchase', 'icon': Icons.shopping_bag_outlined},
          {'key': 'reports_stock', 'title': 'Stock Report', 'icon': Icons.warehouse_outlined},
          {'key': 'reports_customer_payment', 'title': 'Customer Payment Report', 'icon': Icons.receipt_long_outlined},
        ]
      },
      {
        'key': 'printer',
        'title': 'Printer Settings',
        'icon': Icons.settings_applications_outlined,
      },
    ];
  }

  Widget _buildMenuItem(Map<String, dynamic> item, {bool isDrawer = false}) {
    final bool isSelected = _selectedKey == item['key'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
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
        onTap: () {
          if (isDrawer) Navigator.pop(context);
          setState(() => _selectedKey = item['key']);
        },
      ),
    );
  }

  Widget _buildMenuGroup(Map<String, dynamic> group, {bool isDrawer = false}) {
    final List<Map<String, dynamic>> children = List<Map<String, dynamic>>.from(group['children']);
    final bool isAnyChildSelected = children.any((c) => c['key'] == _selectedKey);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: PageStorageKey<String>(group['title']),
        initiallyExpanded: isAnyChildSelected,
        leading: Icon(group['icon'], color: isAnyChildSelected ? AppColors.primary : AppColors.textSecondary, size: 20),
        title: Text(
          group['title'],
          style: TextStyle(
            fontSize: 13,
            fontWeight: isAnyChildSelected ? FontWeight.bold : FontWeight.w600,
            color: isAnyChildSelected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 12),
        children: children.map((c) => _buildMenuItem(c, isDrawer: isDrawer)).toList(),
      ),
    );
  }

  Widget _buildMenuList({bool isDrawer = false}) {
    final menuTree = _getMenuTree();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: menuTree.map((item) {
        if (item.containsKey('children')) {
          return _buildMenuGroup(item, isDrawer: isDrawer);
        } else {
          return _buildMenuItem(item, isDrawer: isDrawer);
        }
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.print, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Text('Roots Digital Press - Billing', style: TextStyle(fontWeight: FontWeight.bold)),
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
              width: 250,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: _buildMenuList(isDrawer: false),
            ),

          // Main View Content Area
          Expanded(
            child: _buildScreen(),
          ),
        ],
      ),
      // Drawer for Mobile / Small Screens
      drawer: isDesktop
          ? null
          : Drawer(
              child: Column(
                children: [
                  DrawerHeader(
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
                  ),
                  Expanded(
                    child: _buildMenuList(isDrawer: true),
                  ),
                ],
              ),
            ),
    );
  }
}
