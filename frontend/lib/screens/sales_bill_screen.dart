// CHANGE-2026-09-07: Created Sales Billing Engine Screen with real-time rate lookup, dynamic tax preview, stock check, PDF generation, and emailing.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/customer_model.dart';
import '../models/tax_model.dart';
import '../models/sales_bill_model.dart';
import '../providers/billing_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/paper_provider.dart';
import '../providers/company_provider.dart';
import '../widgets/app_data_table.dart';

class SalesBillScreen extends StatefulWidget {
  const SalesBillScreen({super.key});

  @override
  State<SalesBillScreen> createState() => _SalesBillScreenState();
}

class _SalesBillScreenState extends State<SalesBillScreen> {
  CustomerModel? _selectedCustomer;
  TaxModel? _selectedTax;
  DateTime _billDate = DateTime.now();
  final _notesController = TextEditingController();

  final List<Map<String, dynamic>> _lineItems = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CompanyProvider>().fetchCompany();
      context.read<CustomerProvider>().fetchCustomers();
      context.read<PaperProvider>().fetchAllMasters();
      context.read<BillingProvider>().fetchSalesBills();
    });
  }

  void _addNewLineItem() {
    final paperProvider = context.read<PaperProvider>();
    if (paperProvider.papers.isEmpty || paperProvider.printoutTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create Papers and Printout Types in Masters before billing!'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() {
      _lineItems.add({
        'paper': paperProvider.papers.first,
        'printout_type': paperProvider.printoutTypes.first,
        'quantity': 1.0,
        'first_copy_rate': 0.0,
        'additional_copy_rate': 0.0,
        'calculated_amount': 0.0,
        'loading_rate': false,
      });
    });

    _recalculateItemRate(_lineItems.length - 1);
  }

  Future<void> _recalculateItemRate(int index) async {
    if (index >= _lineItems.length) return;
    final item = _lineItems[index];
    final paper = item['paper'];
    final printout = item['printout_type'];
    final double qty = item['quantity'] ?? 1.0;

    setState(() => item['loading_rate'] = true);

    final paperProvider = context.read<PaperProvider>();
    final rateModel = await paperProvider.lookupRate(paper.id!, printout.id!);

    if (rateModel != null) {
      final double firstRate = rateModel.firstCopyRate;
      final double addRate = rateModel.additionalCopyRate;

      double lineAmount = 0.0;
      if (qty <= 1) {
        lineAmount = firstRate * qty;
      } else {
        lineAmount = firstRate + ((qty - 1) * addRate);
      }

      setState(() {
        item['first_copy_rate'] = firstRate;
        item['additional_copy_rate'] = addRate;
        item['calculated_amount'] = lineAmount;
        item['loading_rate'] = false;
      });
    } else {
      setState(() {
        item['first_copy_rate'] = 0.0;
        item['additional_copy_rate'] = 0.0;
        item['calculated_amount'] = 0.0;
        item['loading_rate'] = false;
      });
    }
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  double get _subtotal {
    return _lineItems.fold(0.0, (sum, i) => sum + (i['calculated_amount'] ?? 0.0));
  }

  double get _taxPercentage {
    return _selectedTax?.taxPercentage ?? 0.0;
  }

  double get _taxAmount {
    return (_subtotal * _taxPercentage) / 100.0;
  }

  double get _grandTotal {
    return _subtotal + _taxAmount;
  }

  bool get _isInterstate {
    final company = context.read<CompanyProvider>().company;
    if (company == null || _selectedCustomer == null) return false;
    return company.state.trim().toUpperCase() != _selectedCustomer!.state.trim().toUpperCase();
  }

  Future<void> _submitSalesBill() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Customer'), backgroundColor: AppColors.error));
      return;
    }
    if (_selectedTax == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Tax Master'), backgroundColor: AppColors.error));
      return;
    }
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one bill item'), backgroundColor: AppColors.error));
      return;
    }

    final billData = SalesBillModel(
      billDate: Formatters.toIsoDate(_billDate),
      customerId: _selectedCustomer!.id!,
      taxId: _selectedTax!.id!,
      subtotal: _subtotal,
      grandTotal: _grandTotal,
      balanceAmount: _grandTotal,
      notes: _notesController.text.trim(),
      items: _lineItems.map((i) {
        return SalesBillItemModel(
          paperId: i['paper'].id!,
          printoutTypeId: i['printout_type'].id!,
          quantity: i['quantity'],
          firstCopyRate: i['first_copy_rate'],
          additionalCopyRate: i['additional_copy_rate'],
          calculatedAmount: i['calculated_amount'],
        );
      }).toList(),
    );

    final provider = context.read<BillingProvider>();
    final created = await provider.createSalesBill(billData);

    if (mounted) {
      if (created != null) {
        setState(() {
          _lineItems.clear();
          _notesController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sales Bill #${created.billNumber} created successfully!'), backgroundColor: AppColors.success),
        );
      } else if (provider.errorMessage != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(children: [Icon(Icons.error_outline, color: AppColors.error), SizedBox(width: 8), Text('Bill Validation Error')]),
            content: Text(provider.errorMessage!),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final paperProvider = context.watch<PaperProvider>();
    final billingProvider = context.watch<BillingProvider>();
    final company = context.watch<CompanyProvider>().company;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales Billing Engine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Create customer invoices with real-time rate lookup, dynamic state GST evaluation, and stock validation', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Billing Form Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Invoice Header Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Customer Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<CustomerModel>(
                          value: _selectedCustomer,
                          decoration: const InputDecoration(labelText: 'Select Customer *'),
                          items: customerProvider.customers
                              .map((c) => DropdownMenuItem(value: c, child: Text('${c.customerName} (${c.state})')))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCustomer = v),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Tax Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<TaxModel>(
                          value: _selectedTax,
                          decoration: const InputDecoration(labelText: 'Select Tax Master *'),
                          items: paperProvider.taxes
                              .map((t) => DropdownMenuItem(value: t, child: Text('${t.taxName} (${t.taxPercentage}%)')))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedTax = v),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Bill Date Picker
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final dt = await showDatePicker(
                              context: context,
                              initialDate: _billDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (dt != null) setState(() => _billDate = dt);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Bill Date *'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(Formatters.formatDate(_billDate)),
                                const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // State GST Warning / Info Banner
                  if (_selectedCustomer != null && company != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isInterstate ? AppColors.accent.withOpacity(0.1) : AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(_isInterstate ? Icons.swap_horiz : Icons.location_on, size: 20, color: _isInterstate ? AppColors.accent : AppColors.secondary),
                          const SizedBox(width: 10),
                          Text(
                            _isInterstate
                                ? 'Inter-State Transaction: Company State (${company.state}) ≠ Customer State (${_selectedCustomer!.state}). Applying IGST (${_selectedTax?.taxPercentage ?? 0}%).'
                                : 'Intra-State Transaction: Company State (${company.state}) = Customer State (${_selectedCustomer!.state}). Applying CGST + SGST (${(_selectedTax?.taxPercentage ?? 0) / 2}% each).',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Line Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      OutlinedButton.icon(
                        onPressed: _addNewLineItem,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Line Items List
                  if (_lineItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                      child: const Text('No items added to bill yet. Click "Add Item" to start.', style: TextStyle(color: AppColors.textMuted)),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _lineItems.length,
                      itemBuilder: (context, idx) {
                        final item = _lineItems[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          color: AppColors.background,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // Paper Dropdown
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<dynamic>(
                                    value: item['paper'],
                                    decoration: const InputDecoration(labelText: 'Paper Master'),
                                    items: paperProvider.papers
                                        .map((p) => DropdownMenuItem(value: p, child: Text(p.paperName)))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() => item['paper'] = v);
                                      _recalculateItemRate(idx);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Printout Type Dropdown
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<dynamic>(
                                    value: item['printout_type'],
                                    decoration: const InputDecoration(labelText: 'Printout Type'),
                                    items: paperProvider.printoutTypes
                                        .map((pt) => DropdownMenuItem(value: pt, child: Text(pt.name)))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() => item['printout_type'] = v);
                                      _recalculateItemRate(idx);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Quantity Input
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: item['quantity'].toString(),
                                    decoration: const InputDecoration(labelText: 'Quantity'),
                                    keyboardType: TextInputType.number,
                                    onChanged: (v) {
                                      final double q = double.tryParse(v) ?? 1.0;
                                      setState(() => item['quantity'] = q);
                                      _recalculateItemRate(idx);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Rates & Amount Preview
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (item['loading_rate'] == true)
                                        const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                      else ...[
                                        Text('1st Rate: ₹${item['first_copy_rate']} | Add: ₹${item['additional_copy_rate']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                        const SizedBox(height: 2),
                                        Text(Formatters.formatCurrency(item['calculated_amount']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      ],
                                    ],
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                  onPressed: () => _removeLineItem(idx),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),

                  // Grand Summary & Calculations
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _notesController,
                          decoration: const InputDecoration(labelText: 'Invoice Notes / Instructions', hintText: 'Optional bill remarks'),
                        ),
                      ),
                      const SizedBox(width: 32),

                      Container(
                        width: 300,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:'), Text(Formatters.formatCurrency(_subtotal), style: const TextStyle(fontWeight: FontWeight.bold))]),
                            const SizedBox(height: 6),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Tax (${_taxPercentage}%):'), Text(Formatters.formatCurrency(_taxAmount))]),
                            const Divider(height: 16),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Grand Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text(Formatters.formatCurrency(_grandTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary))]),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: billingProvider.isLoading ? null : _submitSalesBill,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(billingProvider.isLoading ? 'Creating Bill...' : 'Generate & Save Sales Bill'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Existing Sales Bills List
          const Text('Existing Sales Bills', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),

          AppDataTable(
            isLoading: billingProvider.isLoading,
            data: billingProvider.bills,
            emptyMessage: 'No sales bills generated yet',
            columns: [
              AppTableColumn(title: 'Bill Number', builder: (b) => Text(b.billNumber ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
              AppTableColumn(title: 'Date', builder: (b) => Text(Formatters.formatDate(b.billDate))),
              AppTableColumn(title: 'Customer', builder: (b) => Text(b.customerName ?? '')),
              AppTableColumn(title: 'Grand Total', builder: (b) => Text(Formatters.formatCurrency(b.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
              AppTableColumn(title: 'Paid', builder: (b) => Text(Formatters.formatCurrency(b.paidAmount), style: const TextStyle(color: AppColors.success))),
              AppTableColumn(title: 'Balance', builder: (b) => Text(Formatters.formatCurrency(b.balanceAmount), style: TextStyle(fontWeight: FontWeight.bold, color: b.balanceAmount > 0 ? AppColors.error : AppColors.success))),
              AppTableColumn(
                title: 'Actions',
                builder: (b) => Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_outlined, color: AppColors.secondary, size: 20),
                      tooltip: 'Print Thermal Receipt',
                      onPressed: () async {
                        final ok = await billingProvider.printInvoice(b.id!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Thermal receipt sent to printer!' : (billingProvider.errorMessage ?? 'Printing failed')),
                              backgroundColor: ok ? AppColors.success : AppColors.error,
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                      tooltip: 'Email Invoice PDF',
                      onPressed: () async {
                        final ok = await billingProvider.emailInvoice(b.id!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Email sent successfully!' : (billingProvider.errorMessage ?? 'Email failed')),
                              backgroundColor: ok ? AppColors.success : AppColors.error,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
