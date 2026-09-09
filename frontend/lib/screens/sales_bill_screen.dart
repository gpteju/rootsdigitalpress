// CHANGE-2026-09-08: Updated Sales Billing Engine Screen to support Dual Customer Types (Normal Customer vs Estimate/Job Customer).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/customer_model.dart';
import '../models/tax_model.dart';
import '../models/sales_bill_model.dart';
import '../models/job_model.dart';
import '../providers/billing_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/paper_provider.dart';
import '../providers/company_provider.dart';
import '../providers/job_provider.dart';
import '../widgets/app_data_table.dart';
import '../widgets/thermal_receipt_dialog.dart';

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
      context.read<JobProvider>().fetchJobs();
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
        'rate_based_on': 'Rates',
        'first_copy_rate': 0.0,
        'click_rate': 0.0,
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
    final String rateBasedOn = item['rate_based_on'] ?? 'Rates';

    setState(() => item['loading_rate'] = true);

    final paperProvider = context.read<PaperProvider>();
    final rateModel = await paperProvider.lookupRate(paper.id!, printout.id!);

    if (rateModel != null) {
      final double firstRate = rateModel.firstCopyRate;
      final double addRate = rateModel.additionalCopyRate;
      final double clickRateVal = rateModel.clickRate;

      double lineAmount = 0.0;
      if (rateBasedOn == 'Click Rate') {
        lineAmount = double.parse((clickRateVal * qty).toStringAsFixed(2));
      } else {
        if (qty <= 1) {
          lineAmount = firstRate * qty;
        } else {
          lineAmount = firstRate + ((qty - 1) * addRate);
        }
      }

      setState(() {
        item['first_copy_rate'] = firstRate;
        item['additional_copy_rate'] = addRate;
        item['click_rate'] = clickRateVal;
        item['calculated_amount'] = lineAmount;
        item['loading_rate'] = false;
      });
    } else {
      setState(() {
        item['first_copy_rate'] = 0.0;
        item['additional_copy_rate'] = 0.0;
        item['click_rate'] = 0.0;
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

  bool get _isInterstate {
    final company = context.watch<CompanyProvider>().company;
    if (company == null || _selectedCustomer == null) return false;
    final compCode = company.stateCode.trim().toUpperCase();
    final custCode = _selectedCustomer!.stateCode.trim().toUpperCase();
    if (compCode.isNotEmpty && custCode.isNotEmpty) {
      return compCode != custCode;
    }
    return company.state.trim().toUpperCase() != _selectedCustomer!.state.trim().toUpperCase();
  }

  bool get _isEstimateCustomer {
    return _selectedCustomer?.isEstimate == true;
  }

  double get _subtotal {
    return _lineItems.fold(0.0, (sum, i) => sum + (i['calculated_amount'] ?? 0.0));
  }

  double get _taxPercentage {
    if (_isEstimateCustomer) return 0.0;
    return _selectedTax?.taxPercentage ?? 0.0;
  }

  double get _taxAmount {
    if (_isEstimateCustomer) return 0.0;
    return (_subtotal * _taxPercentage) / 100.0;
  }

  double get _amountBeforeRoundOff {
    return _subtotal + _taxAmount;
  }

  double get _roundOff {
    if (_isEstimateCustomer) return 0.0;
    final double raw = _amountBeforeRoundOff;
    final double rounded = raw.roundToDouble();
    return double.parse((rounded - raw).toStringAsFixed(2));
  }

  double get _grandTotal {
    if (_isEstimateCustomer) return _subtotal;
    return _amountBeforeRoundOff + _roundOff;
  }

  Future<void> _submitSalesBill() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Customer'), backgroundColor: AppColors.error));
      return;
    }
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one line item'), backgroundColor: AppColors.error));
      return;
    }

    // BRANCH: Estimate / Job Customer vs Normal Customer
    if (_isEstimateCustomer) {
      final jobData = JobModel(
        jobDate: Formatters.toIsoDate(_billDate),
        customerId: _selectedCustomer!.id!,
        subtotal: _subtotal,
        grandTotal: _grandTotal,
        notes: _notesController.text.trim(),
        items: _lineItems.map((i) {
          return JobItemModel(
            paperId: i['paper'].id!,
            printoutTypeId: i['printout_type'].id!,
            paperNameSnapshot: i['paper'].paperName,
            printoutTypeNameSnapshot: i['printout_type'].name,
            quantity: i['quantity'],
            firstCopyRate: i['first_copy_rate'],
            additionalCopyRate: i['additional_copy_rate'],
            calculatedAmount: i['calculated_amount'],
            totalAmount: i['calculated_amount'],
          );
        }).toList(),
      );

      final provider = context.read<JobProvider>();
      final created = await provider.createJob(jobData);

      if (mounted) {
        if (created != null) {
          setState(() {
            _lineItems.clear();
            _notesController.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Job Estimate #${created.jobNumber} created successfully!'),
              backgroundColor: AppColors.success,
              action: SnackBarAction(
                label: 'PRINT',
                textColor: Colors.white,
                onPressed: () => ThermalReceiptDialog.showForJob(context, created),
              ),
            ),
          );
          ThermalReceiptDialog.showForJob(context, created);
        } else if (provider.errorMessage != null) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(children: [Icon(Icons.error_outline, color: AppColors.error), SizedBox(width: 8), Text('Job Error')]),
              content: Text(provider.errorMessage!),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }
      }
    } else {
      // Normal Customer Workflow (Original & Unchanged)
      if (_selectedTax == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Tax Master'), backgroundColor: AppColors.error));
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
            rateBasedOn: i['rate_based_on'] ?? 'Rates',
            clickRate: i['click_rate'] ?? 0.0,
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
            SnackBar(
              content: Text('Sales Bill #${created.billNumber} created successfully!'),
              backgroundColor: AppColors.success,
              action: SnackBarAction(
                label: 'PRINT',
                textColor: Colors.white,
                onPressed: () => ThermalReceiptDialog.showForSalesBill(context, created),
              ),
            ),
          );
          ThermalReceiptDialog.showForSalesBill(context, created);
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
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final paperProvider = context.watch<PaperProvider>();
    final billingProvider = context.watch<BillingProvider>();
    final jobProvider = context.watch<JobProvider>();

    final isBusy = billingProvider.isLoading || jobProvider.isLoading;

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
                  Text('Sales Billing Engine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Create Sales Invoices & Job Estimates with real-time rates and stock updates', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addNewLineItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item Line'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Header Card: Customer, Tax, Date
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_isEstimateCustomer)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ESTIMATE / JOB CUSTOMER MODE: Tax calculation is bypassed (Tax = 0). Transaction will be stored in Job Details without affecting normal Sales Bills.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      // Customer Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<CustomerModel>(
                          value: _selectedCustomer,
                          decoration: const InputDecoration(labelText: 'Select Customer *'),
                          items: customerProvider.customers.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Text(c.customerName),
                                  if (c.isEstimate) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('JOB', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (c) {
                            setState(() {
                              _selectedCustomer = c;
                              if (c != null && c.isEstimate) {
                                _selectedTax = null; // Tax disabled for Job Customer
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Tax Dropdown (Hidden/Disabled for Estimate Customers)
                      if (!_isEstimateCustomer)
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<TaxModel>(
                            value: _selectedTax,
                            decoration: const InputDecoration(labelText: 'Tax Master *'),
                            items: paperProvider.taxes.map((t) {
                              return DropdownMenuItem(value: t, child: Text('${t.taxName} (${t.taxPercentage}%)'));
                            }).toList(),
                            onChanged: (t) => setState(() => _selectedTax = t),
                          ),
                        )
                      else
                        Expanded(
                          flex: 2,
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                            child: const Text('Tax Not Applicable (0%)', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      const SizedBox(width: 16),

                      // Bill Date Picker
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _billDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _billDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Bill / Job Date'),
                            child: Text(Formatters.formatDate(Formatters.toIsoDate(_billDate))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Items Form Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Line Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),

                  if (_lineItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(Icons.playlist_add, size: 48, color: AppColors.border),
                          SizedBox(height: 8),
                          Text('No line items added yet. Click "Add Item Line" above.', style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _lineItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, idx) {
                        final item = _lineItems[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              // Paper Dropdown
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField(
                                  value: item['paper'],
                                  decoration: const InputDecoration(labelText: 'Paper'),
                                  items: paperProvider.papers.map((p) {
                                    return DropdownMenuItem(value: p, child: Text(p.paperName));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => item['paper'] = val);
                                      _recalculateItemRate(idx);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Printout Type Dropdown
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField(
                                  value: item['printout_type'],
                                  decoration: const InputDecoration(labelText: 'Printout Type'),
                                  items: paperProvider.printoutTypes.map((pt) {
                                    return DropdownMenuItem(value: pt, child: Text(pt.name));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => item['printout_type'] = val);
                                      _recalculateItemRate(idx);
                                    }
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

                              // Rate Based On Dropdown
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: item['rate_based_on'] ?? 'Rates',
                                  decoration: const InputDecoration(labelText: 'Rate Based On'),
                                  items: const [
                                    DropdownMenuItem(value: 'Rates', child: Text('Rates')),
                                    DropdownMenuItem(value: 'Click Rate', child: Text('Click Rate')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => item['rate_based_on'] = val);
                                      _recalculateItemRate(idx);
                                    }
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
                                      if (item['rate_based_on'] == 'Click Rate')
                                        Text('Click Rate: ₹${item['click_rate'] ?? 0.0}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))
                                      else
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
                          decoration: const InputDecoration(labelText: 'Remarks / Notes', hintText: 'Optional instructions'),
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
                            if (!_isEstimateCustomer) ...[
                              if (!_isInterstate) ...[
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('CGST (${(_taxPercentage / 2).toStringAsFixed(1).replaceAll(".0", "")}%):'), Text(Formatters.formatCurrency(_taxAmount / 2))]),
                                const SizedBox(height: 6),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('SGST (${(_taxPercentage / 2).toStringAsFixed(1).replaceAll(".0", "")}%):'), Text(Formatters.formatCurrency(_taxAmount / 2))]),
                              ] else ...[
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('IGST (${_taxPercentage.toStringAsFixed(1).replaceAll(".0", "")}%):'), Text(Formatters.formatCurrency(_taxAmount))]),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Round Off:'),
                                  Text(
                                    '${_roundOff >= 0 ? "+" : ""}${Formatters.formatCurrency(_roundOff)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _roundOff == 0 ? AppColors.textSecondary : (_roundOff < 0 ? AppColors.error : AppColors.success),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                      onPressed: isBusy ? null : _submitSalesBill,
                      style: _isEstimateCustomer
                          ? ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800)
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(isBusy ? 'Saving...' : (_isEstimateCustomer ? 'Generate & Save Job Estimate' : 'Generate & Save Sales Bill')),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Existing Sales Bills List
          const Text('Existing Sales Bills (Normal Customers)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),

          AppDataTable(
            isLoading: billingProvider.isLoading,
            data: billingProvider.bills,
            emptyMessage: 'No normal sales bills generated yet',
            columns: [
              AppTableColumn(title: 'Bill Number', builder: (b) => Text(b.billNumber ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
              AppTableColumn(title: 'Date', builder: (b) => Text(Formatters.formatDate(b.billDate))),
              AppTableColumn(title: 'Customer', builder: (b) => Text(b.customerName ?? '')),
              AppTableColumn(
                title: 'Tax',
                builder: (b) {
                  final taxAmt = b.totalTaxAmount;
                  final pctStr = b.taxPercentage > 0 ? ' (${b.taxPercentage.toInt()}%)' : '';
                  return Text(
                    taxAmt > 0 ? '${Formatters.formatCurrency(taxAmt)}$pctStr' : '₹0.00',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  );
                },
              ),
              AppTableColumn(title: 'Grand Total', builder: (b) => Text(Formatters.formatCurrency(b.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
              AppTableColumn(title: 'Paid', builder: (b) => Text(Formatters.formatCurrency(b.paidAmount), style: const TextStyle(color: AppColors.success))),
              AppTableColumn(title: 'Balance', builder: (b) => Text(Formatters.formatCurrency(b.balanceAmount), style: TextStyle(fontWeight: FontWeight.bold, color: b.balanceAmount > 0 ? AppColors.error : AppColors.success))),
              AppTableColumn(
                title: 'Actions',
                builder: (b) => Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_outlined, color: AppColors.secondary, size: 20),
                      tooltip: 'Thermal Receipt Preview & Print',
                      onPressed: () => ThermalReceiptDialog.showForSalesBill(context, b),
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

          const SizedBox(height: 32),

          // Existing Estimate Jobs List
          const Text('Estimate / Job Details (Job Customers)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),

          AppDataTable(
            isLoading: jobProvider.isLoading,
            data: jobProvider.jobs,
            emptyMessage: 'No estimate / job details created yet',
            columns: [
              AppTableColumn(title: 'Job Number', builder: (j) => Text(j.jobNumber ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber))),
              AppTableColumn(title: 'Date', builder: (j) => Text(Formatters.formatDate(j.jobDate))),
              AppTableColumn(title: 'Customer', builder: (j) => Text(j.customerName ?? '')),
              AppTableColumn(title: 'Grand Total', builder: (j) => Text(Formatters.formatCurrency(j.grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
              AppTableColumn(
                title: 'Actions',
                builder: (j) => Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.print_outlined, color: AppColors.secondary, size: 20),
                      tooltip: 'Thermal Estimate Preview & Print',
                      onPressed: () => ThermalReceiptDialog.showForJob(context, j),
                    ),
                    IconButton(
                      icon: const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                      tooltip: 'Email Estimate PDF',
                      onPressed: () async {
                        final ok = await jobProvider.emailJob(j.id!);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Estimate PDF emailed successfully!' : (jobProvider.errorMessage ?? 'Email failed')),
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
