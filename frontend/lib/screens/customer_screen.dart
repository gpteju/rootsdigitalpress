// CHANGE-2026-09-07: Created Customer Master Screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/customer_model.dart';
import '../providers/customer_provider.dart';
import '../widgets/app_data_table.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
    });
  }

  void _showCustomerDialog([CustomerModel? customer]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: customer?.customerName ?? '');
    final addressCtrl = TextEditingController(text: customer?.address ?? '');
    final cityCtrl = TextEditingController(text: customer?.city ?? '');
    final stateCtrl = TextEditingController(text: customer?.state ?? '');
    final stateCodeCtrl = TextEditingController(text: customer?.stateCode ?? '');
    final gstinCtrl = TextEditingController(text: customer?.gstin ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final creditLimitCtrl = TextEditingController(text: (customer?.creditLimit ?? 0.0).toString());
    final termsCtrl = TextEditingController(text: (customer?.paymentTerms ?? 30).toString());
    bool isEstimateVal = customer?.isEstimate ?? false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (stCtx, setDlgState) => AlertDialog(
        title: Text(customer == null ? 'Add New Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Container(
            width: 600,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isEstimateVal ? Colors.amber.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isEstimateVal ? Colors.amber : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Estimate / Job Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              isEstimateVal ? 'ON (Estimate / Job Customer)' : 'OFF (Normal Customer)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isEstimateVal ? Colors.amber.shade900 : AppColors.textSecondary),
                            ),
                          ],
                        ),
                        Switch(
                          value: isEstimateVal,
                          activeColor: Colors.amber.shade800,
                          onChanged: (val) {
                            setDlgState(() => isEstimateVal = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Customer / Business Name *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'City'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: stateCtrl,
                          decoration: const InputDecoration(labelText: 'State *'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'State is required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: stateCodeCtrl,
                          decoration: const InputDecoration(labelText: 'State Code *', hintText: '33'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Code required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: gstinCtrl,
                          decoration: const InputDecoration(labelText: 'GSTIN'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email Address'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: creditLimitCtrl,
                          decoration: const InputDecoration(labelText: 'Credit Limit (₹)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: termsCtrl,
                          decoration: const InputDecoration(labelText: 'Payment Terms (Days)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final cust = CustomerModel(
                id: customer?.id,
                customerName: nameCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                city: cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
                state: stateCtrl.text.trim(),
                stateCode: stateCodeCtrl.text.trim(),
                gstin: gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                creditLimit: double.tryParse(creditLimitCtrl.text.trim()) ?? 0.0,
                paymentTerms: int.tryParse(termsCtrl.text.trim()) ?? 30,
                isEstimate: isEstimateVal,
              );

              final provider = context.read<CustomerProvider>();
              bool success = customer == null
                  ? await provider.createCustomer(cust)
                  : await provider.updateCustomer(customer.id!, cust);

              if (mounted) {
                if (success) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(customer == null ? 'Customer added!' : 'Customer updated!'), backgroundColor: AppColors.success),
                  );
                } else if (provider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: Text(customer == null ? 'Save Customer' : 'Update Customer'),
          ),
        ],
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerProvider>();
    final customers = provider.customers;

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
                  Text('Customer Master', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Manage customer accounts, credit limits, advance balances, and state codes', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCustomerDialog(),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add Customer'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: AppDataTable(
              isLoading: provider.isLoading,
              data: customers,
              emptyMessage: 'No customers added yet',
              columns: [
                AppTableColumn(
                  title: 'Customer Name',
                  builder: (c) => Row(
                    children: [
                      Text(c.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (c.isEstimate) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.amber.shade700)),
                          child: const Text('ESTIMATE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                        ),
                      ],
                    ],
                  ),
                ),
                AppTableColumn(title: 'City / State', builder: (c) => Text('${c.city ?? "-"}, ${c.state} (${c.stateCode})')),
                AppTableColumn(title: 'GSTIN', builder: (c) => Text(c.gstin ?? '-')),
                AppTableColumn(title: 'Phone / Email', builder: (c) => Text('${c.phone ?? "-"}\n${c.email ?? "-"}', style: const TextStyle(fontSize: 12))),
                AppTableColumn(title: 'Credit Limit', builder: (c) => Text(Formatters.formatCurrency(c.creditLimit))),
                AppTableColumn(
                  title: 'Advance Credit',
                  builder: (c) => Text(
                    Formatters.formatCurrency(c.advanceBalance),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: c.advanceBalance > 0 ? AppColors.success : AppColors.textPrimary,
                    ),
                  ),
                ),
                AppTableColumn(
                  title: 'Actions',
                  builder: (c) => IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                    onPressed: () => _showCustomerDialog(c),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
