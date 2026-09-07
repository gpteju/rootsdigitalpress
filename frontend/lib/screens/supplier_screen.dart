// CHANGE-2026-09-07: Created Supplier Master Screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/supplier_model.dart';
import '../providers/supplier_provider.dart';
import '../widgets/app_data_table.dart';

class SupplierScreen extends StatefulWidget {
  const SupplierScreen({super.key});

  @override
  State<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends State<SupplierScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierProvider>().fetchSuppliers();
    });
  }

  void _showSupplierDialog([SupplierModel? supplier]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: supplier?.supplierName ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final cityCtrl = TextEditingController(text: supplier?.city ?? '');
    final stateCtrl = TextEditingController(text: supplier?.state ?? '');
    final stateCodeCtrl = TextEditingController(text: supplier?.stateCode ?? '');
    final gstinCtrl = TextEditingController(text: supplier?.gstin ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final termsCtrl = TextEditingController(text: (supplier?.paymentTerms ?? 30).toString());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Text(supplier == null ? 'Add New Supplier' : 'Edit Supplier'),
        content: SingleChildScrollView(
          child: Container(
            width: 600,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Supplier Name *'),
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
              final supp = SupplierModel(
                id: supplier?.id,
                supplierName: nameCtrl.text.trim(),
                address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                city: cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
                state: stateCtrl.text.trim(),
                stateCode: stateCodeCtrl.text.trim(),
                gstin: gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                paymentTerms: int.tryParse(termsCtrl.text.trim()) ?? 30,
              );

              final provider = context.read<SupplierProvider>();
              bool success = supplier == null
                  ? await provider.createSupplier(supp)
                  : await provider.updateSupplier(supplier.id!, supp);

              if (mounted) {
                if (success) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(supplier == null ? 'Supplier added!' : 'Supplier updated!'), backgroundColor: AppColors.success),
                  );
                } else if (provider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: Text(supplier == null ? 'Save Supplier' : 'Update Supplier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplierProvider>();
    final suppliers = provider.suppliers;

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
                  Text('Supplier Master', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Manage paper suppliers, GSTIN, state codes, and purchase terms', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showSupplierDialog(),
                icon: const Icon(Icons.local_shipping_outlined, size: 18),
                label: const Text('Add Supplier'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: AppDataTable(
              isLoading: provider.isLoading,
              data: suppliers,
              emptyMessage: 'No suppliers registered yet',
              columns: [
                AppTableColumn(title: 'Supplier Name', builder: (s) => Text(s.supplierName, style: const TextStyle(fontWeight: FontWeight.bold))),
                AppTableColumn(title: 'City / State', builder: (s) => Text('${s.city ?? "-"}, ${s.state} (${s.stateCode})')),
                AppTableColumn(title: 'GSTIN', builder: (s) => Text(s.gstin ?? '-')),
                AppTableColumn(title: 'Phone / Email', builder: (s) => Text('${s.phone ?? "-"}\n${s.email ?? "-"}', style: const TextStyle(fontSize: 12))),
                AppTableColumn(title: 'Terms', builder: (s) => Text('${s.paymentTerms} Days')),
                AppTableColumn(
                  title: 'Actions',
                  builder: (s) => IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                    onPressed: () => _showSupplierDialog(s),
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
