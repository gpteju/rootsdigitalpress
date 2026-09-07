// CHANGE-2026-09-07: Created Financial Reports Screen featuring Customer Aging Report with customer filtering.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/customer_model.dart';
import '../providers/report_provider.dart';
import '../providers/customer_provider.dart';
import '../widgets/app_data_table.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CustomerModel? _selectedAgingCustomer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
      context.read<ReportProvider>().fetchDailySalesReport();
      context.read<ReportProvider>().fetchCustomerWiseReport();
      context.read<ReportProvider>().fetchSupplierPurchasesReport();
      context.read<ReportProvider>().fetchCustomerPendingReport();
      context.read<ReportProvider>().fetchCustomerAgingReport();
      context.read<ReportProvider>().fetchStockReport();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final customerProvider = context.watch<CustomerProvider>();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Financial & Inventory Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Server-side aggregation reports for Sales, Purchases, Pending Invoices, Customer Aging, and Stock', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 16),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Daily Sales'),
              Tab(text: 'Customer Wise'),
              Tab(text: 'Customer Aging (0-90+ Days)'),
              Tab(text: 'Customer Pending'),
              Tab(text: 'Supplier Purchases'),
              Tab(text: 'Stock Inventory'),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Daily Sales Report
                AppDataTable(
                  isLoading: reportProvider.isLoading,
                  data: reportProvider.dailySales,
                  emptyMessage: 'No daily sales recorded',
                  columns: [
                    AppTableColumn(title: 'Date', builder: (d) => Text(Formatters.formatDate(d['bill_date']), style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Bill Count', builder: (d) => Text('${d['bill_count']}')),
                    AppTableColumn(title: 'Customers', builder: (d) => Text('${d['customer_count']}')),
                    AppTableColumn(title: 'Subtotal', builder: (d) => Text(Formatters.formatCurrency(d['total_subtotal']))),
                    AppTableColumn(title: 'CGST + SGST', builder: (d) => Text(Formatters.formatCurrency((d['total_cgst'] ?? 0) + (d['total_sgst'] ?? 0)))),
                    AppTableColumn(title: 'IGST', builder: (d) => Text(Formatters.formatCurrency(d['total_igst']))),
                    AppTableColumn(title: 'Grand Total', builder: (d) => Text(Formatters.formatCurrency(d['grand_total']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                    AppTableColumn(title: 'Collected Paid', builder: (d) => Text(Formatters.formatCurrency(d['total_paid']), style: const TextStyle(color: AppColors.success))),
                    AppTableColumn(title: 'Outstanding', builder: (d) => Text(Formatters.formatCurrency(d['total_outstanding']), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
                  ],
                ),

                // Tab 2: Customer Wise Report
                AppDataTable(
                  isLoading: reportProvider.isLoading,
                  data: reportProvider.customerWise,
                  emptyMessage: 'No customer sales records',
                  columns: [
                    AppTableColumn(title: 'Customer Name', builder: (c) => Text(c['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Total Bills', builder: (c) => Text('${c['bill_count']}')),
                    AppTableColumn(title: 'Billed Sales', builder: (c) => Text(Formatters.formatCurrency(c['total_billed']), style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Total Paid', builder: (c) => Text(Formatters.formatCurrency(c['total_paid']), style: const TextStyle(color: AppColors.success))),
                    AppTableColumn(title: 'Outstanding Balance', builder: (c) => Text(Formatters.formatCurrency(c['total_outstanding']), style: TextStyle(fontWeight: FontWeight.bold, color: (c['total_outstanding'] ?? 0) > 0 ? AppColors.error : AppColors.success))),
                    AppTableColumn(title: 'Advance Credit', builder: (c) => Text(Formatters.formatCurrency(c['advance_balance']), style: TextStyle(color: (c['advance_balance'] ?? 0) > 0 ? AppColors.success : AppColors.textPrimary))),
                  ],
                ),

                // Tab 3: Customer Aging Report (with Customer Selection Filter)
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<CustomerModel?>(
                            value: _selectedAgingCustomer,
                            decoration: const InputDecoration(labelText: 'Filter by Customer'),
                            items: [
                              const DropdownMenuItem<CustomerModel?>(value: null, child: Text('All Customers')),
                              ...customerProvider.customers.map((c) => DropdownMenuItem(value: c, child: Text(c.customerName))),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedAgingCustomer = v);
                              context.read<ReportProvider>().fetchCustomerAgingReport(customerId: v?.id);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: AppDataTable(
                        isLoading: reportProvider.isLoading,
                        data: reportProvider.customerAging,
                        emptyMessage: 'No customer aging balances found',
                        columns: [
                          AppTableColumn(title: 'Customer Name', builder: (a) => Text(a['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                          AppTableColumn(title: '0 - 30 Days', builder: (a) => Text(Formatters.formatCurrency(a['bucket_0_30']))),
                          AppTableColumn(title: '31 - 60 Days', builder: (a) => Text(Formatters.formatCurrency(a['bucket_31_60']), style: TextStyle(color: (a['bucket_31_60'] ?? 0) > 0 ? AppColors.accent : AppColors.textPrimary))),
                          AppTableColumn(title: '61 - 90 Days', builder: (a) => Text(Formatters.formatCurrency(a['bucket_61_90']), style: TextStyle(fontWeight: FontWeight.bold, color: (a['bucket_61_90'] ?? 0) > 0 ? AppColors.error : AppColors.textPrimary))),
                          AppTableColumn(title: '> 90 Days (Critical)', builder: (a) => Text(Formatters.formatCurrency(a['bucket_over_90']), style: TextStyle(fontWeight: FontWeight.bold, color: (a['bucket_over_90'] ?? 0) > 0 ? AppColors.error : AppColors.textPrimary))),
                          AppTableColumn(title: 'Total Outstanding', builder: (a) => Text(Formatters.formatCurrency(a['total_outstanding']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.error))),
                        ],
                      ),
                    ),
                  ],
                ),

                // Tab 4: Customer Pending Invoices
                AppDataTable(
                  isLoading: reportProvider.isLoading,
                  data: reportProvider.customerPending,
                  emptyMessage: 'No pending customer invoices',
                  columns: [
                    AppTableColumn(title: 'Bill Number', builder: (p) => Text(p['bill_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Bill Date', builder: (p) => Text(Formatters.formatDate(p['bill_date']))),
                    AppTableColumn(title: 'Customer', builder: (p) => Text(p['customer_name'] ?? '')),
                    AppTableColumn(title: 'Grand Total', builder: (p) => Text(Formatters.formatCurrency(p['grand_total']))),
                    AppTableColumn(title: 'Paid', builder: (p) => Text(Formatters.formatCurrency(p['paid_amount']), style: const TextStyle(color: AppColors.success))),
                    AppTableColumn(title: 'Pending Balance', builder: (p) => Text(Formatters.formatCurrency(p['balance_amount']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error))),
                    AppTableColumn(title: 'Days Unpaid', builder: (p) => Text('${p['days_pending']} Days', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),

                // Tab 5: Supplier Purchases Report
                AppDataTable(
                  isLoading: reportProvider.isLoading,
                  data: reportProvider.supplierPurchases,
                  emptyMessage: 'No supplier purchase records',
                  columns: [
                    AppTableColumn(title: 'Supplier Name', builder: (s) => Text(s['supplier_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Purchase Count', builder: (s) => Text('${s['purchase_count']}')),
                    AppTableColumn(title: 'Subtotal', builder: (s) => Text(Formatters.formatCurrency(s['total_subtotal']))),
                    AppTableColumn(title: 'Tax Amount', builder: (s) => Text(Formatters.formatCurrency((s['total_cgst'] ?? 0) + (s['total_sgst'] ?? 0) + (s['total_igst'] ?? 0)))),
                    AppTableColumn(title: 'Grand Total', builder: (s) => Text(Formatters.formatCurrency(s['grand_total']), style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Paid Amount', builder: (s) => Text(Formatters.formatCurrency(s['total_paid']), style: const TextStyle(color: AppColors.success))),
                    AppTableColumn(title: 'Supplier Balance', builder: (s) => Text(Formatters.formatCurrency(s['total_outstanding']), style: TextStyle(fontWeight: FontWeight.bold, color: (s['total_outstanding'] ?? 0) > 0 ? AppColors.error : AppColors.success))),
                  ],
                ),

                // Tab 6: Stock Inventory Report
                AppDataTable(
                  isLoading: reportProvider.isLoading,
                  data: reportProvider.stockReport,
                  emptyMessage: 'No stock items available',
                  columns: [
                    AppTableColumn(title: 'Paper Name', builder: (st) => Text(st['paper_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Unit', builder: (st) => Text(st['purchase_unit'] ?? '')),
                    AppTableColumn(title: 'Opening Stock', builder: (st) => Text('${st['opening_stock']}')),
                    AppTableColumn(title: 'Total Purchased (+)', builder: (st) => Text('+${st['total_qty_in']}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Total Sales Out (-)', builder: (st) => Text('-${st['total_qty_out']}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Closing Stock', builder: (st) => Text('${st['current_stock']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                    AppTableColumn(title: 'Reorder Threshold', builder: (st) => Text('${st['reorder_level']}')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
