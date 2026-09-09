// CHANGE-2026-09-08: Financial Reporting Screen supporting Daily Sales (Bill-Wise), Customer Wise, Customer Aging, Supplier Purchases, Customer Pending, and Stock Reports.
// CHANGE-2026-09-09: Added Customer Payment Report tab with customer filter, payment-to-bill allocation display, and CSV export.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_saver/file_saver.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/app_data_table.dart';

class ReportsScreen extends StatefulWidget {
  final int initialTabIndex;
  const ReportsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _df = DateFormat('yyyy-MM-dd');
  final DateFormat _displayDf = DateFormat('dd-MM-yyyy');

  DateTime? _dailyFromDate;
  DateTime? _dailyToDate;
  CustomerModel? _selectedDailyCustomer;
  CustomerModel? _selectedPaymentCustomer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex >= 0 && widget.initialTabIndex < 7 ? widget.initialTabIndex : 0,
    );
    _tabController.addListener(_handleTabSelection);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
      _loadCurrentTabReport();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _loadCurrentTabReport();
    }
  }

  void _loadCurrentTabReport() {
    final provider = context.read<ReportProvider>();
    switch (_tabController.index) {
      case 0:
        final fromStr = _dailyFromDate != null ? _df.format(_dailyFromDate!) : null;
        final toStr = _dailyToDate != null ? _df.format(_dailyToDate!) : null;
        provider.fetchDailySalesReport(startDate: fromStr, endDate: toStr, customerId: _selectedDailyCustomer?.id);
        break;
      case 1:
        provider.fetchCustomerWiseReport();
        break;
      case 2:
        provider.fetchCustomerAgingReport();
        break;
      case 3:
        provider.fetchCustomerPendingReport();
        break;
      case 4:
        provider.fetchSupplierPurchasesReport();
        break;
      case 5:
        provider.fetchStockReport();
        break;
      case 6:
        if (_selectedPaymentCustomer != null && _selectedPaymentCustomer!.id != null) {
          provider.fetchCustomerPaymentReport(_selectedPaymentCustomer!.id!);
        }
        break;
    }
  }

  void _onDailySalesGo() {
    if (_dailyFromDate != null && _dailyToDate != null && _dailyFromDate!.isAfter(_dailyToDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('From Date cannot be after To Date'), backgroundColor: AppColors.error),
      );
      return;
    }

    final fromStr = _dailyFromDate != null ? _df.format(_dailyFromDate!) : null;
    final toStr = _dailyToDate != null ? _df.format(_dailyToDate!) : null;

    context.read<ReportProvider>().fetchDailySalesReport(
      startDate: fromStr,
      endDate: toStr,
      customerId: _selectedDailyCustomer?.id,
    );
  }

  Future<void> _exportCsv({
    required String fileName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    final StringBuffer sb = StringBuffer();
    sb.writeln(headers.map((h) => _escapeCsv(h)).join(','));
    for (var row in rows) {
      sb.writeln(row.map((cell) => _escapeCsv(cell)).join(','));
    }

    final bytes = Uint8List.fromList(utf8.encode(sb.toString()));
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded ${fileName}.csv successfully'), backgroundColor: AppColors.success),
      );
    }
  }

  String _escapeCsv(dynamic val) {
    if (val == null) return '""';
    String str = val.toString().replaceAll('"', '""');
    return '"$str"';
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final nonEstimateCustomers = customerProvider.customers.where((c) => !c.isEstimate).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Financial & Inventory Reports', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Server-side aggregation reports for Sales, Payments, Purchases, Pending Invoices, Customer Aging, and Stock', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
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
              Tab(text: 'Customer Payments'),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: DAILY SALES REPORT (Bill-Wise with Date/Customer Filters & GO button)
                Column(
                  children: [
                    // Filter Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          // From Date
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dailyFromDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) setState(() => _dailyFromDate = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'From Date',
                                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                child: Text(_dailyFromDate != null ? _displayDf.format(_dailyFromDate!) : 'DD-MM-YYYY'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // To Date
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _dailyToDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) setState(() => _dailyToDate = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'To Date',
                                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                child: Text(_dailyToDate != null ? _displayDf.format(_dailyToDate!) : 'DD-MM-YYYY'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Customer Filter (Non-estimate only)
                          Expanded(
                            child: DropdownButtonFormField<CustomerModel?>(
                              value: _selectedDailyCustomer,
                              decoration: const InputDecoration(
                                labelText: 'Customer',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<CustomerModel?>(value: null, child: Text('All Customers')),
                                ...nonEstimateCustomers.map((c) => DropdownMenuItem(value: c, child: Text(c.customerName))),
                              ],
                              onChanged: (v) => setState(() => _selectedDailyCustomer = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // GO Button
                          ElevatedButton.icon(
                            onPressed: _onDailySalesGo,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('GO'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Download Button
                          OutlinedButton.icon(
                            onPressed: () {
                              final fromStr = _dailyFromDate != null ? _df.format(_dailyFromDate!) : 'all';
                              final toStr = _dailyToDate != null ? _df.format(_dailyToDate!) : 'all';
                              final fn = 'daily_sales_${fromStr}_to_${toStr}';
                              final rows = reportProvider.dailySales.map((b) => [
                                b['bill_number'] ?? '',
                                Formatters.formatDate(b['bill_date']),
                                b['customer_name'] ?? '',
                                b['subtotal'] ?? 0,
                                b['cgst_amount'] ?? 0,
                                b['sgst_amount'] ?? 0,
                                b['igst_amount'] ?? 0,
                                b['round_off'] ?? 0,
                                b['grand_total'] ?? 0,
                                b['paid_amount'] ?? 0,
                                b['balance_amount'] ?? 0,
                                b['status'] ?? '',
                              ]).toList();

                              _exportCsv(
                                fileName: fn,
                                headers: ['Bill No', 'Bill Date', 'Customer', 'Subtotal', 'CGST', 'SGST', 'IGST', 'Round Off', 'Grand Total', 'Paid', 'Outstanding', 'Status'],
                                rows: rows,
                              );
                            },
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download CSV'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bill-wise Table
                    Expanded(
                      child: AppDataTable(
                        isLoading: reportProvider.isLoading,
                        data: reportProvider.dailySales,
                        emptyMessage: 'No sales found for the selected criteria.',
                        columns: [
                          AppTableColumn(title: 'Bill No', builder: (b) => Text(b['bill_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                          AppTableColumn(title: 'Bill Date', builder: (b) => Text(Formatters.formatDate(b['bill_date']))),
                          AppTableColumn(title: 'Customer', builder: (b) => Text(b['customer_name'] ?? '')),
                          AppTableColumn(title: 'Subtotal', builder: (b) => Text(Formatters.formatCurrency(b['subtotal']))),
                          AppTableColumn(title: 'CGST', builder: (b) => Text(Formatters.formatCurrency(b['cgst_amount']))),
                          AppTableColumn(title: 'SGST', builder: (b) => Text(Formatters.formatCurrency(b['sgst_amount']))),
                          AppTableColumn(title: 'IGST', builder: (b) => Text(Formatters.formatCurrency(b['igst_amount']))),
                          AppTableColumn(title: 'Round Off', builder: (b) => Text(Formatters.formatCurrency(b['round_off']))),
                          AppTableColumn(title: 'Grand Total', builder: (b) => Text(Formatters.formatCurrency(b['grand_total']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                          AppTableColumn(title: 'Paid', builder: (b) => Text(Formatters.formatCurrency(b['paid_amount']), style: const TextStyle(color: AppColors.success))),
                          AppTableColumn(title: 'Outstanding', builder: (b) => Text(Formatters.formatCurrency(b['balance_amount']), style: TextStyle(fontWeight: FontWeight.bold, color: (b['balance_amount'] ?? 0) > 0 ? AppColors.error : AppColors.success))),
                        ],
                      ),
                    ),

                    // Daily Sales Summary Footer
                    if (reportProvider.dailySalesSummary != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Bills: ${reportProvider.dailySalesSummary!['total_bills'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Subtotal: ${Formatters.formatCurrency(reportProvider.dailySalesSummary!['total_subtotal'])}'),
                            Text('CGST: ${Formatters.formatCurrency(reportProvider.dailySalesSummary!['total_cgst'])}'),
                            Text('SGST: ${Formatters.formatCurrency(reportProvider.dailySalesSummary!['total_sgst'])}'),
                            Text('IGST: ${Formatters.formatCurrency(reportProvider.dailySalesSummary!['total_igst'])}'),
                            Text('Round Off: ${Formatters.formatCurrency(reportProvider.dailySalesSummary!['total_round_off'])}'),
                            Text('Grand Total: ${Formatters.formatCurrency(reportProvider.dailySalesSummary!['grand_total'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // TAB 2: CUSTOMER WISE REPORT (Non-Estimate Customers Only)
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            final todayStr = _df.format(DateTime.now());
                            final rows = reportProvider.customerWise.map((c) => [
                              c['customer_name'] ?? '',
                              c['phone'] ?? '',
                              c['bill_count'] ?? 0,
                              c['total_subtotal'] ?? 0,
                              (c['total_cgst'] ?? 0) + (c['total_sgst'] ?? 0) + (c['total_igst'] ?? 0),
                              c['total_round_off'] ?? 0,
                              c['total_billed'] ?? 0,
                              c['total_paid'] ?? 0,
                              c['total_outstanding'] ?? 0,
                              c['advance_balance'] ?? 0,
                            ]).toList();

                            _exportCsv(
                              fileName: 'customer_wise_report_$todayStr',
                              headers: ['Customer Name', 'Phone', 'Total Invoices', 'Subtotal', 'Tax Amount', 'Round Off', 'Total Billed', 'Total Paid', 'Pending Balance', 'Advance Balance'],
                              rows: rows,
                            );
                          },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: AppDataTable(
                        isLoading: reportProvider.isLoading,
                        data: reportProvider.customerWise,
                        emptyMessage: 'No non-estimate customer records found.',
                        columns: [
                          AppTableColumn(title: 'Customer Name', builder: (c) => Text(c['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                          AppTableColumn(title: 'Phone', builder: (c) => Text(c['phone'] ?? '-')),
                          AppTableColumn(title: 'Invoices', builder: (c) => Text('${c['bill_count']}')),
                          AppTableColumn(title: 'Total Billed', builder: (c) => Text(Formatters.formatCurrency(c['total_billed']), style: const TextStyle(fontWeight: FontWeight.bold))),
                          AppTableColumn(title: 'Total Paid', builder: (c) => Text(Formatters.formatCurrency(c['total_paid']), style: const TextStyle(color: AppColors.success))),
                          AppTableColumn(title: 'Pending Balance', builder: (c) => Text(Formatters.formatCurrency(c['total_outstanding']), style: TextStyle(fontWeight: FontWeight.bold, color: (c['total_outstanding'] ?? 0) > 0 ? AppColors.error : AppColors.success))),
                          AppTableColumn(title: 'Advance Credit', builder: (c) => Text(Formatters.formatCurrency(c['advance_balance']), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ],
                ),

                // TAB 3: CUSTOMER AGING REPORT
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            final todayStr = _df.format(DateTime.now());
                            final rows = reportProvider.customerAging.map((a) => [
                              a['customer_name'] ?? '',
                              a['phone'] ?? '',
                              a['bucket_0_30'] ?? 0,
                              a['bucket_31_60'] ?? 0,
                              a['bucket_61_90'] ?? 0,
                              a['bucket_over_90'] ?? 0,
                              a['total_outstanding'] ?? 0,
                            ]).toList();

                            _exportCsv(
                              fileName: 'customer_aging_report_$todayStr',
                              headers: ['Customer Name', 'Phone', '0-30 Days', '31-60 Days', '61-90 Days', '90+ Days', 'Total Outstanding'],
                              rows: rows,
                            );
                          },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: AppDataTable(
                        isLoading: reportProvider.isLoading,
                        data: reportProvider.customerAging,
                        emptyMessage: 'No aging records found.',
                        columns: [
                          AppTableColumn(title: 'Customer Name', builder: (a) => Text(a['customer_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                          AppTableColumn(title: 'Phone', builder: (a) => Text(a['phone'] ?? '-')),
                          AppTableColumn(title: '0-30 Days', builder: (a) => Text(Formatters.formatCurrency(a['bucket_0_30']))),
                          AppTableColumn(title: '31-60 Days', builder: (a) => Text(Formatters.formatCurrency(a['bucket_31_60']), style: const TextStyle(color: Colors.orange))),
                          AppTableColumn(title: '61-90 Days', builder: (a) => Text(Formatters.formatCurrency(a['bucket_61_90']), style: const TextStyle(color: Colors.deepOrange))),
                          AppTableColumn(title: '90+ Days Overdue', builder: (a) => Text(Formatters.formatCurrency(a['bucket_over_90']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error))),
                          AppTableColumn(title: 'Total Outstanding', builder: (a) => Text(Formatters.formatCurrency(a['total_outstanding']), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ],
                ),

                // TAB 4: CUSTOMER PENDING INVOICES REPORT
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            final todayStr = _df.format(DateTime.now());
                            final rows = reportProvider.customerPending.map((p) => [
                              p['bill_number'] ?? '',
                              Formatters.formatDate(p['bill_date']),
                              p['customer_name'] ?? '',
                              p['grand_total'] ?? 0,
                              p['paid_amount'] ?? 0,
                              p['balance_amount'] ?? 0,
                              p['days_pending'] ?? 0,
                              p['status'] ?? '',
                            ]).toList();

                            _exportCsv(
                              fileName: 'customer_pending_report_$todayStr',
                              headers: ['Bill Number', 'Bill Date', 'Customer', 'Grand Total', 'Paid Amount', 'Pending Balance', 'Days Unpaid', 'Status'],
                              rows: rows,
                            );
                          },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: AppDataTable(
                        isLoading: reportProvider.isLoading,
                        data: reportProvider.customerPending,
                        emptyMessage: 'No pending customer invoices.',
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
                    ),
                  ],
                ),

                // TAB 5: SUPPLIER PURCHASES REPORT
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            final todayStr = _df.format(DateTime.now());
                            final rows = reportProvider.supplierPurchases.map((s) => [
                              s['supplier_name'] ?? '',
                              s['purchase_count'] ?? 0,
                              s['total_subtotal'] ?? 0,
                              (s['total_cgst'] ?? 0) + (s['total_sgst'] ?? 0) + (s['total_igst'] ?? 0),
                              s['grand_total'] ?? 0,
                              s['total_paid'] ?? 0,
                              s['total_outstanding'] ?? 0,
                            ]).toList();

                            _exportCsv(
                              fileName: 'supplier_purchases_report_$todayStr',
                              headers: ['Supplier Name', 'Purchase Count', 'Subtotal', 'Tax Amount', 'Grand Total', 'Paid Amount', 'Supplier Balance'],
                              rows: rows,
                            );
                          },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: AppDataTable(
                        isLoading: reportProvider.isLoading,
                        data: reportProvider.supplierPurchases,
                        emptyMessage: 'No supplier purchase records.',
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
                    ),
                  ],
                ),

                // TAB 6: STOCK INVENTORY REPORT
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            final todayStr = _df.format(DateTime.now());
                            final rows = reportProvider.stockReport.map((st) => [
                              st['paper_name'] ?? '',
                              st['purchase_unit'] ?? '',
                              st['opening_stock'] ?? 0,
                              st['total_qty_in'] ?? 0,
                              st['total_qty_out'] ?? 0,
                              st['current_stock'] ?? 0,
                              st['reorder_level'] ?? 0,
                            ]).toList();

                            _exportCsv(
                              fileName: 'stock_inventory_report_$todayStr',
                              headers: ['Paper Name', 'Unit', 'Opening Stock', 'Total Purchased (+)', 'Total Sales Out (-)', 'Closing Stock', 'Reorder Threshold'],
                              rows: rows,
                            );
                          },
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: AppDataTable(
                        isLoading: reportProvider.isLoading,
                        data: reportProvider.stockReport,
                        emptyMessage: 'No stock items available.',
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
                    ),
                  ],
                ),

                // TAB 7: CUSTOMER PAYMENT REPORT
                Column(
                  children: [
                    // Filter Row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<CustomerModel?>(
                              value: _selectedPaymentCustomer,
                              decoration: const InputDecoration(
                                labelText: 'Select Customer *',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem<CustomerModel?>(value: null, child: Text('Select a Customer...')),
                                ...nonEstimateCustomers.map((c) => DropdownMenuItem(value: c, child: Text(c.customerName))),
                              ],
                              onChanged: (v) => setState(() => _selectedPaymentCustomer = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (_selectedPaymentCustomer == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a Customer first'), backgroundColor: AppColors.error),
                                );
                                return;
                              }
                              context.read<ReportProvider>().fetchCustomerPaymentReport(_selectedPaymentCustomer!.id!);
                            },
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text('GO'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              final reportData = reportProvider.customerPaymentReport;
                              if (reportData == null || _selectedPaymentCustomer == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No report data available to export'), backgroundColor: AppColors.error),
                                );
                                return;
                              }
                              final payments = reportData['payments'] as List<dynamic>? ?? [];
                              final custName = _selectedPaymentCustomer!.customerName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                              final fileName = 'Customer_Payment_Report_$custName';

                              List<List<dynamic>> csvRows = [];
                              for (var p in payments) {
                                final pDate = Formatters.formatDate(p['payment_date']);
                                final pNum = p['payment_number'] ?? '';
                                final pAmt = p['amount'] ?? 0;
                                final pMode = p['payment_mode'] ?? '';
                                final allocations = p['allocations'] as List<dynamic>? ?? [];

                                if (allocations.isEmpty) {
                                  csvRows.add([
                                    _selectedPaymentCustomer!.customerName,
                                    pDate,
                                    pNum,
                                    pAmt,
                                    pMode,
                                    'N/A',
                                    'N/A',
                                    0,
                                    0,
                                    0,
                                  ]);
                                } else {
                                  for (var alloc in allocations) {
                                    csvRows.add([
                                      _selectedPaymentCustomer!.customerName,
                                      pDate,
                                      pNum,
                                      pAmt,
                                      pMode,
                                      alloc['bill_number'] ?? '',
                                      Formatters.formatDate(alloc['bill_date']),
                                      alloc['bill_grand_total'] ?? 0,
                                      alloc['allocated_amount'] ?? 0,
                                      alloc['bill_balance_amount'] ?? 0,
                                    ]);
                                  }
                                }
                              }

                              _exportCsv(
                                fileName: fileName,
                                headers: ['Customer', 'Payment Date', 'Receipt No', 'Payment Amount', 'Payment Mode', 'Bill No', 'Bill Date', 'Bill Amount', 'Allocated Amount', 'Bill Balance'],
                                rows: csvRows,
                              );
                            },
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Download CSV'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Content Body
                    Expanded(
                      child: _selectedPaymentCustomer == null
                          ? const Center(
                              child: Text('Please select a customer and click GO to view the payment report.', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                            )
                          : reportProvider.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : (reportProvider.customerPaymentReport == null || (reportProvider.customerPaymentReport!['payments'] as List? ?? []).isEmpty)
                                  ? const Center(
                                      child: Text('No payment records found for this customer.', style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Summary Banner Card
                                        if (reportProvider.customerPaymentReport!['summary'] != null) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Customer: ${reportProvider.customerPaymentReport!['customer']['customer_name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                                Text('Total Payments: ${Formatters.formatCurrency(reportProvider.customerPaymentReport!['summary']['total_payments'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                                                Text('Total Billed Allocated: ${Formatters.formatCurrency(reportProvider.customerPaymentReport!['summary']['total_allocated'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                Text('Advance Credit Balance: ${Formatters.formatCurrency(reportProvider.customerPaymentReport!['summary']['advance_credit'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                        ],

                                        // Payments & Allocation List
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: (reportProvider.customerPaymentReport!['payments'] as List).length,
                                            itemBuilder: (context, idx) {
                                              final payment = reportProvider.customerPaymentReport!['payments'][idx];
                                              final allocations = payment['allocations'] as List<dynamic>? ?? [];

                                              return Card(
                                                margin: const EdgeInsets.only(bottom: 12),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(14),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      // Receipt Header Row
                                                      Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Text('${payment['payment_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                                                              const SizedBox(width: 12),
                                                              Text('Date: ${Formatters.formatDate(payment['payment_date'])}', style: const TextStyle(color: AppColors.textSecondary)),
                                                              const SizedBox(width: 12),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                                                child: Text('${payment['payment_mode']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                                              ),
                                                            ],
                                                          ),
                                                          Row(
                                                            children: [
                                                              Text('Payment: ${Formatters.formatCurrency(payment['amount'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.success)),
                                                              const SizedBox(width: 16),
                                                              Text('Allocated: ${Formatters.formatCurrency(payment['allocated_amount'])}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                      if (payment['reference_number'] != null || payment['notes'] != null) ...[
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          'Ref: ${payment['reference_number'] ?? 'N/A'} ${payment['notes'] != null ? "• Notes: ${payment['notes']}" : ""}',
                                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                        ),
                                                      ],
                                                      const SizedBox(height: 10),
                                                      const Divider(height: 1),
                                                      const SizedBox(height: 10),

                                                      // Allocations Table
                                                      if (allocations.isEmpty)
                                                        const Padding(
                                                          padding: EdgeInsets.symmetric(vertical: 6),
                                                          child: Text('No bill allocations (Recorded as Customer Advance Credit).', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
                                                        )
                                                      else
                                                        AppDataTable(
                                                          isLoading: false,
                                                          data: allocations,
                                                          emptyMessage: 'No allocations',
                                                          columns: [
                                                            AppTableColumn(title: 'Bill No', builder: (a) => Text(a['bill_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                                            AppTableColumn(title: 'Bill Date', builder: (a) => Text(Formatters.formatDate(a['bill_date']))),
                                                            AppTableColumn(title: 'Bill Amount', builder: (a) => Text(Formatters.formatCurrency(a['bill_grand_total']))),
                                                            AppTableColumn(title: 'Allocated Amount', builder: (a) => Text(Formatters.formatCurrency(a['allocated_amount']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success))),
                                                            AppTableColumn(title: 'Bill Balance', builder: (a) => Text(Formatters.formatCurrency(a['bill_balance_amount']), style: TextStyle(fontWeight: FontWeight.bold, color: (a['bill_balance_amount'] ?? 0) > 0 ? AppColors.error : AppColors.success))),
                                                            AppTableColumn(title: 'Status', builder: (a) => Text(a['bill_status'] ?? '')),
                                                          ],
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                    ),
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
