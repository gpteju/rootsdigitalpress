// CHANGE-2026-09-07: Created Stock Ledger and Inventory Management Screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../providers/purchase_provider.dart';
import '../providers/paper_provider.dart';
import '../widgets/app_data_table.dart';

class StockLedgerScreen extends StatefulWidget {
  const StockLedgerScreen({super.key});

  @override
  State<StockLedgerScreen> createState() => _StockLedgerScreenState();
}

class _StockLedgerScreenState extends State<StockLedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchaseProvider>().fetchStockSummary();
      context.read<PurchaseProvider>().fetchStockLedger();
      context.read<PaperProvider>().fetchPapers();
    });
  }

  void _showAdjustDialog() {
    final paperProvider = context.read<PaperProvider>();
    final formKey = GlobalKey<FormState>();
    int? selectedPaperId = paperProvider.papers.isNotEmpty ? paperProvider.papers.first.id : null;
    String adjType = 'IN';
    final qtyCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();

    if (selectedPaperId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No papers registered in Paper Master'), backgroundColor: AppColors.error));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manual Stock Adjustment'),
          content: Container(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedPaperId,
                    decoration: const InputDecoration(labelText: 'Paper Master *'),
                    items: paperProvider.papers.map((p) => DropdownMenuItem(value: p.id, child: Text(p.paperName))).toList(),
                    onChanged: (v) => setDialogState(() => selectedPaperId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: adjType,
                    decoration: const InputDecoration(labelText: 'Adjustment Type *'),
                    items: const [
                      DropdownMenuItem(value: 'IN', child: Text('Stock IN (+)')),
                      DropdownMenuItem(value: 'OUT', child: Text('Stock OUT (-)')),
                    ],
                    onChanged: (v) => setDialogState(() => adjType = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: qtyCtrl,
                    decoration: const InputDecoration(labelText: 'Adjustment Quantity *'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Quantity is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks / Reason'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final double q = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                final provider = context.read<PurchaseProvider>();
                final ok = await provider.adjustStock(
                  paperId: selectedPaperId!,
                  adjustmentType: adjType,
                  quantity: q,
                  remarks: remarksCtrl.text.trim().isEmpty ? null : remarksCtrl.text.trim(),
                );

                if (mounted) {
                  if (ok) {
                    Navigator.pop(dialogCtx);
                    provider.fetchStockLedger();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock adjusted successfully!'), backgroundColor: AppColors.success));
                  } else if (provider.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error));
                  }
                }
              },
              child: const Text('Submit Adjustment'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PurchaseProvider>();

    return Padding(
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
                  Text('Stock Ledger & Inventory Status', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Complete movement history, opening stock, purchases IN, sales OUT, and stock balance tracking', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showAdjustDialog,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Manual Stock Adjustment'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Current Stock Summary'),
              Tab(text: 'Stock Movement Ledger'),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Current Stock Summary
                AppDataTable(
                  isLoading: provider.isLoading,
                  data: provider.stockSummary,
                  emptyMessage: 'No stock items available',
                  columns: [
                    AppTableColumn(title: 'Paper Name', builder: (s) => Text(s['paper_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Type & Size', builder: (s) => Text('${s['paper_type_name']} (${s['gsm_value']} GSM, ${s['paper_size_name']})')),
                    AppTableColumn(title: 'Opening Stock', builder: (s) => Text('${s['opening_stock']} ${s['purchase_unit']}')),
                    AppTableColumn(
                      title: 'Current Stock',
                      builder: (s) => Text(
                        '${s['current_stock']} ${s['purchase_unit']}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: s['is_low_stock'] == 1 ? AppColors.error : AppColors.success,
                        ),
                      ),
                    ),
                    AppTableColumn(title: 'Reorder Level', builder: (s) => Text('${s['reorder_level']} ${s['purchase_unit']}')),
                    AppTableColumn(
                      title: 'Stock Alert',
                      builder: (s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: s['is_low_stock'] == 1 ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s['is_low_stock'] == 1 ? 'LOW STOCK ALERT' : 'HEALTHY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: s['is_low_stock'] == 1 ? AppColors.error : AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Tab 2: Stock Ledger History
                AppDataTable(
                  isLoading: provider.isLoading,
                  data: provider.stockLedger,
                  emptyMessage: 'No stock ledger transactions recorded',
                  columns: [
                    AppTableColumn(title: 'Date & Time', builder: (l) => Text(Formatters.formatDate(l['transaction_date']))),
                    AppTableColumn(title: 'Paper Name', builder: (l) => Text(l['paper_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Transaction Type', builder: (l) => Text(l['transaction_type'] ?? '')),
                    AppTableColumn(title: 'Ref #', builder: (l) => Text(l['reference_id'] ?? '-')),
                    AppTableColumn(title: 'Qty IN (+)', builder: (l) => Text(l['qty_in'] > 0 ? '+${l['qty_in']}' : '-', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Qty OUT (-)', builder: (l) => Text(l['qty_out'] > 0 ? '-${l['qty_out']}' : '-', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Closing Balance', builder: (l) => Text('${l['balance_qty']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Remarks', builder: (l) => Text(l['remarks'] ?? '-')),
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
