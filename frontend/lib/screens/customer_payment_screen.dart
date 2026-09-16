// CHANGE-2026-09-07: Created Customer Payment Screen with FIFO & Manual Allocation and Advance Credit support.
// CHANGE-2026-09-09: Display Advance Credit and incorporate customer advance balance into payment processing.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../providers/payment_provider.dart';
import '../widgets/app_data_table.dart';

class CustomerPaymentScreen extends StatefulWidget {
  const CustomerPaymentScreen({super.key});

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  CustomerModel? _selectedCustomer;
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _paymentDate = DateTime.now();

  String _allocationMode = 'FIFO'; // 'FIFO' or 'MANUAL'
  String _paymentMode = 'CASH'; // 'CASH', 'BANK_TRANSFER', 'UPI', 'CHEQUE'

  final Map<int, TextEditingController> _manualAllocControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
      context.read<PaymentProvider>().fetchPayments();
    });
  }

  void _onCustomerChanged(CustomerModel? customer) {
    setState(() {
      _selectedCustomer = customer;
      _manualAllocControllers.clear();
    });
    if (customer != null && customer.id != null) {
      context.read<PaymentProvider>().fetchCustomerPendingBills(customer.id!);
      context.read<PaymentProvider>().fetchPayments(customerId: customer.id!);
    }
  }

  Future<void> _submitPayment() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Customer'), backgroundColor: AppColors.error));
      return;
    }

    final double amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amt < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment amount cannot be negative'), backgroundColor: AppColors.error));
      return;
    }

    final double existingAdvance = _selectedCustomer!.advanceBalance;
    final double totalAvailable = amt + existingAdvance;

    if (totalAvailable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount > 0 or select a customer with available Advance Credit'), backgroundColor: AppColors.error),
      );
      return;
    }

    List<Map<String, dynamic>> manualList = [];
    if (_allocationMode == 'MANUAL') {
      _manualAllocControllers.forEach((billId, ctrl) {
        final double alloc = double.tryParse(ctrl.text.trim()) ?? 0.0;
        if (alloc > 0) {
          manualList.add({'sales_bill_id': billId, 'allocated_amount': alloc});
        }
      });
    }

    final provider = context.read<PaymentProvider>();
    final success = await provider.submitPayment(
      customerId: _selectedCustomer!.id!,
      paymentDate: Formatters.toIsoDate(_paymentDate),
      amount: amt,
      allocationMode: _allocationMode,
      manualAllocations: manualList,
      paymentMode: _paymentMode,
      referenceNumber: _refController.text.trim().isEmpty ? null : _refController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (mounted) {
      if (success) {
        _amountController.clear();
        _refController.clear();
        _notesController.clear();
        _manualAllocControllers.clear();
        await context.read<CustomerProvider>().fetchCustomers(); // Refresh customer advance balance
        if (_selectedCustomer != null) {
          // Refresh _selectedCustomer reference from updated customer list
          final updatedCustomers = context.read<CustomerProvider>().customers;
          final updated = updatedCustomers.firstWhere((c) => c.id == _selectedCustomer!.id, orElse: () => _selectedCustomer!);
          setState(() {
            _selectedCustomer = updated;
          });
          context.read<PaymentProvider>().fetchCustomerPendingBills(_selectedCustomer!.id!);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment processed & allocated successfully!'), backgroundColor: AppColors.success),
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
    final customerProvider = context.watch<CustomerProvider>();
    final paymentProvider = context.watch<PaymentProvider>();
    final pendingBills = paymentProvider.pendingBills;

    double totalPendingBalance = pendingBills.fold(0.0, (sum, b) => sum + (double.tryParse(b['balance_amount']?.toString() ?? '0') ?? 0.0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Payments & FIFO Allocation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),

          // Main Form Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Customer Dropdown & Allocation Mode
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
                              child: Text('${c.customerName} (${c.city ?? "No City"})'),
                            );
                          }).toList(),
                          onChanged: _onCustomerChanged,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Allocation Mode
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _allocationMode,
                          decoration: const InputDecoration(labelText: 'Allocation Mode *'),
                          items: const [
                            DropdownMenuItem(value: 'FIFO', child: Text('FIFO (Oldest First)')),
                            DropdownMenuItem(value: 'MANUAL', child: Text('Manual Allocation')),
                          ],
                          onChanged: (v) => setState(() => _allocationMode = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 2: Payment Date, Payment Amount, Payment Mode, Ref Number
                  Row(
                    children: [
                      // Payment Date
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _paymentDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => _paymentDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Payment Date *'),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(Formatters.formatDate(_paymentDate)),
                                const Icon(Icons.calendar_today, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Payment Amount
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(labelText: 'Payment Amount (₹)', hintText: '0.00'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Payment Mode
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _paymentMode,
                          decoration: const InputDecoration(labelText: 'Payment Mode *'),
                          items: const [
                            DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                            DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer / NEFT')),
                            DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
                            DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                          ],
                          onChanged: (v) => setState(() => _paymentMode = v!),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Reference Number
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _refController,
                          decoration: const InputDecoration(labelText: 'Ref Number / UTR', hintText: 'Txn ID or Cheque No'),
                        ),
                      ),
                    ],
                  ),

                  if (_selectedCustomer != null) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Pending Bills for ${_selectedCustomer!.customerName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        Row(
                          children: [
                            Text('Advance Credit: ${Formatters.formatCurrency(_selectedCustomer!.advanceBalance)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success)),
                            const SizedBox(width: 20),
                            Text('Total Outstanding: ${Formatters.formatCurrency(totalPendingBalance)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (pendingBills.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedCustomer!.advanceBalance > 0
                                    ? 'This customer has zero pending bills and an existing Advance Credit of ${Formatters.formatCurrency(_selectedCustomer!.advanceBalance)}.'
                                    : 'This customer has zero pending bills! Any payment entered will be recorded as Customer Advance Credit.',
                                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pendingBills.length,
                        itemBuilder: (context, idx) {
                          final bill = pendingBills[idx];
                          final int billId = bill['id'];
                          if (!_manualAllocControllers.containsKey(billId)) {
                            _manualAllocControllers[billId] = TextEditingController();
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${bill['bill_number']} • Date: ${Formatters.formatDate(bill['bill_date'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('Total: ${Formatters.formatCurrency(bill['grand_total'])} | Paid: ${Formatters.formatCurrency(bill['paid_amount'])}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text('Balance: ${Formatters.formatCurrency(bill['balance_amount'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
                                      if (_allocationMode == 'MANUAL') ...[
                                        const SizedBox(width: 16),
                                        SizedBox(
                                          width: 120,
                                          height: 40,
                                          child: TextField(
                                            controller: _manualAllocControllers[billId],
                                            decoration: const InputDecoration(hintText: 'Allocate ₹', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                            keyboardType: TextInputType.number,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: paymentProvider.isLoading ? null : _submitPayment,
                      icon: const Icon(Icons.payment),
                      label: Text(paymentProvider.isLoading ? 'Processing Payment...' : 'Submit & Allocate Payment'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text('Recent Customer Payment History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),

          AppDataTable(
            isLoading: paymentProvider.isLoading,
            data: paymentProvider.payments,
            emptyMessage: 'No payments recorded yet',
            columns: [
              AppTableColumn(title: 'Receipt #', builder: (p) => Text(p['payment_number'] ?? p['receipt_number'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
              AppTableColumn(title: 'Date', builder: (p) => Text(Formatters.formatDate(p['payment_date']))),
              AppTableColumn(title: 'Customer', builder: (p) => Text(p['customer_name'] ?? '')),
              AppTableColumn(title: 'Payment Amount', builder: (p) => Text(Formatters.formatCurrency(double.tryParse(p['amount']?.toString() ?? '0')), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success))),
              AppTableColumn(title: 'Bill Allocated', builder: (p) => Text(Formatters.formatCurrency(double.tryParse(p['allocated_amount']?.toString() ?? '0')))),
              AppTableColumn(title: 'Advance Credit', builder: (p) => Text(Formatters.formatCurrency(double.tryParse(p['advance_credit_amount']?.toString() ?? '0')), style: TextStyle(color: (double.tryParse(p['advance_credit_amount']?.toString() ?? '0') ?? 0) > 0 ? AppColors.success : AppColors.textPrimary))),
              AppTableColumn(title: 'Mode', builder: (p) => Text('${p['payment_mode']} ${p['reference_number'] != null ? "(${p['reference_number']})" : ""}')),
            ],
          ),
        ],
      ),
    );
  }
}
