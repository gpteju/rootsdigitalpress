// CHANGE-2026-09-07: Created Supplier Purchase Screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';
import '../providers/paper_provider.dart';
import '../providers/purchase_provider.dart';
import '../widgets/app_data_table.dart';

class SupplierPurchaseScreen extends StatefulWidget {
  const SupplierPurchaseScreen({super.key});

  @override
  State<SupplierPurchaseScreen> createState() => _SupplierPurchaseScreenState();
}

class _SupplierPurchaseScreenState extends State<SupplierPurchaseScreen> {
  SupplierModel? _selectedSupplier;
  DateTime _purchaseDate = DateTime.now();
  final _invNumberController = TextEditingController();
  final _paidAmountController = TextEditingController(text: '0');

  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().fetchSuppliers();
      context.read<PaperProvider>().fetchPapers();
      context.read<PurchaseProvider>().fetchPurchases();
    });
  }

  void _addItem() {
    final papers = context.read<PaperProvider>().papers;
    if (papers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No papers registered in Paper Master!'), backgroundColor: AppColors.error));
      return;
    }
    setState(() {
      _items.add({
        'paper': papers.first,
        'quantity': 100.0,
        'rate': 2.0,
      });
    });
  }

  double get _subtotal {
    return _items.fold(0.0, (sum, i) => sum + ((i['quantity'] ?? 0) * (i['rate'] ?? 0)));
  }

  Future<void> _submitPurchase() async {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Supplier'), backgroundColor: AppColors.error));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one paper item'), backgroundColor: AppColors.error));
      return;
    }

    final purchaseData = {
      'supplier_id': _selectedSupplier!.id,
      'purchase_date': Formatters.toIsoDate(_purchaseDate),
      'invoice_number': _invNumberController.text.trim().isEmpty ? null : _invNumberController.text.trim(),
      'paid_amount': double.tryParse(_paidAmountController.text.trim()) ?? 0.0,
      'items': _items.map((i) => {
        'paper_id': i['paper'].id,
        'quantity': i['quantity'],
        'rate': i['rate'],
      }).toList(),
    };

    final provider = context.read<PurchaseProvider>();
    final success = await provider.createPurchase(purchaseData);

    if (mounted) {
      if (success) {
        setState(() {
          _items.clear();
          _invNumberController.clear();
          _paidAmountController.text = '0';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplier purchase recorded & stock updated!'), backgroundColor: AppColors.success),
        );
      } else if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierProvider = context.watch<SupplierProvider>();
    final paperProvider = context.watch<PaperProvider>();
    final purchaseProvider = context.watch<PurchaseProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Supplier Paper Purchases', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Record incoming paper stock purchases from suppliers and automatically update stock balances', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Purchase Entry Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<SupplierModel>(
                          value: _selectedSupplier,
                          decoration: const InputDecoration(labelText: 'Select Supplier *'),
                          items: supplierProvider.suppliers
                              .map((s) => DropdownMenuItem(value: s, child: Text(s.supplierName)))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedSupplier = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _invNumberController,
                          decoration: const InputDecoration(labelText: 'Supplier Invoice Ref #'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final dt = await showDatePicker(
                              context: context,
                              initialDate: _purchaseDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (dt != null) setState(() => _purchaseDate = dt);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Purchase Date *'),
                            child: Text(Formatters.formatDate(_purchaseDate)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Purchased Items', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      OutlinedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add, size: 18), label: const Text('Add Paper Item')),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    itemBuilder: (context, idx) {
                      final item = _items[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<dynamic>(
                                  value: item['paper'],
                                  decoration: const InputDecoration(labelText: 'Paper Master'),
                                  items: paperProvider.papers
                                      .map((p) => DropdownMenuItem(value: p, child: Text(p.paperName)))
                                      .toList(),
                                  onChanged: (v) => setState(() => item['paper'] = v),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: item['quantity'].toString(),
                                  decoration: const InputDecoration(labelText: 'Quantity'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => setState(() => item['quantity'] = double.tryParse(v) ?? 0.0),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: item['rate'].toString(),
                                  decoration: const InputDecoration(labelText: 'Unit Rate (₹)'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) => setState(() => item['rate'] = double.tryParse(v) ?? 0.0),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(Formatters.formatCurrency((item['quantity'] ?? 0) * (item['rate'] ?? 0)), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              IconButton(icon: const Icon(Icons.delete, color: AppColors.error), onPressed: () => setState(() => _items.removeAt(idx))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal: ${Formatters.formatCurrency(_subtotal)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      SizedBox(
                        width: 250,
                        child: TextFormField(
                          controller: _paidAmountController,
                          decoration: const InputDecoration(labelText: 'Paid Amount (₹)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: purchaseProvider.isLoading ? null : _submitPurchase,
                      icon: const Icon(Icons.check_circle),
                      label: Text(purchaseProvider.isLoading ? 'Recording Purchase...' : 'Save Purchase & Update Stock IN'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text('Purchase Transaction History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),

          AppDataTable(
            isLoading: purchaseProvider.isLoading,
            data: purchaseProvider.purchases,
            emptyMessage: 'No purchase records found',
            columns: [
              AppTableColumn(title: 'Purchase #', builder: (p) => Text(p['purchase_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
              AppTableColumn(title: 'Date', builder: (p) => Text(Formatters.formatDate(p['purchase_date']))),
              AppTableColumn(title: 'Supplier', builder: (p) => Text(p['supplier_name'] ?? '')),
              AppTableColumn(title: 'Inv Ref', builder: (p) => Text(p['invoice_number'] ?? '-')),
              AppTableColumn(title: 'Grand Total', builder: (p) => Text(Formatters.formatCurrency(p['grand_total']), style: const TextStyle(fontWeight: FontWeight.bold))),
              AppTableColumn(title: 'Paid', builder: (p) => Text(Formatters.formatCurrency(p['paid_amount']), style: const TextStyle(color: AppColors.success))),
              AppTableColumn(title: 'Balance', builder: (p) => Text(Formatters.formatCurrency(p['balance_amount']), style: TextStyle(color: (p['balance_amount'] ?? 0) > 0 ? AppColors.error : AppColors.success))),
            ],
          ),
        ],
      ),
    );
  }
}
