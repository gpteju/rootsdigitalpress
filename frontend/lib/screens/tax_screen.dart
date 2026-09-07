// CHANGE-2026-09-07: Created Tax Master Screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/tax_model.dart';
import '../providers/paper_provider.dart';
import '../widgets/app_data_table.dart';

class TaxScreen extends StatefulWidget {
  const TaxScreen({super.key});

  @override
  State<TaxScreen> createState() => _TaxScreenState();
}

class _TaxScreenState extends State<TaxScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaperProvider>().fetchTaxes();
    });
  }

  void _showTaxDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final pctCtrl = TextEditingController(text: '18');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Add Tax Master Record'),
        content: SingleChildScrollView(
          child: Container(
            width: 450,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Tax Name *', hintText: 'e.g. GST 18%'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Tax Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: pctCtrl,
                    decoration: const InputDecoration(labelText: 'Total Tax Percentage (%) *'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Percentage is required' : null,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sub-taxes (CGST, SGST, IGST) will be created automatically based on state evaluation.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
              final double pct = double.tryParse(pctCtrl.text.trim()) ?? 0.0;
              final double halfPct = pct / 2.0;

              final tax = TaxModel(
                taxName: nameCtrl.text.trim(),
                taxPercentage: pct,
                subTaxes: [
                  SubTaxModel(subTaxName: 'CGST', ratePercentage: halfPct, taxType: 'INTRA_STATE'),
                  SubTaxModel(subTaxName: 'SGST', ratePercentage: halfPct, taxType: 'INTRA_STATE'),
                  SubTaxModel(subTaxName: 'IGST', ratePercentage: pct, taxType: 'INTER_STATE'),
                ],
              );

              final provider = context.read<PaperProvider>();
              bool success = await provider.createTax(tax);

              if (mounted) {
                if (success) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tax Master record saved!'), backgroundColor: AppColors.success),
                  );
                } else if (provider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Save Tax Master'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaperProvider>();
    final taxes = provider.taxes;

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
                  Text('Tax Master', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Configurable tax percentages and sub-taxes (CGST / SGST / IGST)', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showTaxDialog,
                icon: const Icon(Icons.account_balance, size: 18),
                label: const Text('Add Tax Master'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: AppDataTable(
              isLoading: provider.isLoading,
              data: taxes,
              emptyMessage: 'No tax master records defined yet',
              columns: [
                AppTableColumn(title: 'Tax Name', builder: (t) => Text(t.taxName, style: const TextStyle(fontWeight: FontWeight.bold))),
                AppTableColumn(title: 'Total Percentage', builder: (t) => Text('${t.taxPercentage}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                AppTableColumn(
                  title: 'Sub Taxes breakdown',
                  builder: (t) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: t.subTaxes.map<Widget>((st) => Text('${st.subTaxName}: ${st.ratePercentage}% (${st.taxType})', style: const TextStyle(fontSize: 12))).toList(),
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
