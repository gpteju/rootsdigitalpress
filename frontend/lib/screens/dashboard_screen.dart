// CHANGE-2026-09-07: Created Dashboard Overview Screen for Printout Billing Software.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../widgets/app_stat_card.dart';
import '../providers/billing_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/purchase_provider.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int index)? onNavigateToTab;

  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillingProvider>().fetchSalesBills();
      context.read<CustomerProvider>().fetchCustomers();
      context.read<PurchaseProvider>().fetchStockSummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final billingProvider = context.watch<BillingProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final purchaseProvider = context.watch<PurchaseProvider>();

    final bills = billingProvider.bills;
    double totalBilled = bills.fold(0, (sum, item) => sum + item.grandTotal);
    double totalPaid = bills.fold(0, (sum, item) => sum + item.paidAmount);
    double totalOutstanding = bills.fold(0, (sum, item) => sum + item.balanceAmount);

    final lowStockItems = purchaseProvider.stockSummary.where((i) => i['is_low_stock'] == 1).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard Overview',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Real-time billing, stock movements, and financial status',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => widget.onNavigateToTab?.call(8), // Navigate to Create Bill
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Create Sale Bill'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stat Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final int crossAxisCount = width > 1100 ? 4 : (width > 650 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                childAspectRatio: 2.3,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  AppStatCard(
                    title: 'Total Billed Sales',
                    value: Formatters.formatCurrency(totalBilled),
                    icon: Icons.receipt_long,
                    color: AppColors.primary,
                    subtitle: '${bills.length} Total Bills Generated',
                  ),
                  AppStatCard(
                    title: 'Collected Payments',
                    value: Formatters.formatCurrency(totalPaid),
                    icon: Icons.payments_outlined,
                    color: AppColors.success,
                    subtitle: 'Received from customers',
                  ),
                  AppStatCard(
                    title: 'Outstanding Balance',
                    value: Formatters.formatCurrency(totalOutstanding),
                    icon: Icons.pending_actions,
                    color: AppColors.error,
                    subtitle: 'Pending collection',
                  ),
                  AppStatCard(
                    title: 'Active Customers',
                    value: '${customerProvider.customers.length}',
                    icon: Icons.people_outline,
                    color: AppColors.secondary,
                    subtitle: 'Registered clients',
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // Quick Actions & Low Stock Warnings
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent Bills List
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Sales Bills',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            TextButton(
                              onPressed: () => widget.onNavigateToTab?.call(8),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (bills.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('No bills created yet', style: TextStyle(color: AppColors.textMuted))),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: bills.take(5).length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final bill = bills[idx];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  '${bill.billNumber} • ${bill.customerName ?? "Customer"}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text('Date: ${Formatters.formatDate(bill.billDate)}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Formatters.formatCurrency(bill.grandTotal),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                    Text(
                                      bill.status,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: bill.status == 'PAID' ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Low Stock Alerts Sidebar
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Low Stock Alerts',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (lowStockItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('All paper items are well stocked!', style: TextStyle(color: AppColors.success, fontSize: 13))),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: lowStockItems.length,
                            itemBuilder: (context, idx) {
                              final item = lowStockItems[idx];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['paper_name'] ?? 'Paper',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          'Reorder level: ${item['reorder_level']} ${item['purchase_unit']}',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${item['current_stock']} ${item['purchase_unit']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 13),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
