// CHANGE-2026-09-07: Created Configurable Rate Master Screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/rate_model.dart';
import '../providers/paper_provider.dart';
import '../widgets/app_data_table.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({super.key});

  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaperProvider>().fetchRates();
      context.read<PaperProvider>().fetchPapers();
      context.read<PaperProvider>().fetchPrintoutTypes();
    });
  }

  void _showRateDialog([RateModel? rate]) {
    final provider = context.read<PaperProvider>();
    final formKey = GlobalKey<FormState>();

    int? selectedPaperId = rate?.paperId ?? (provider.papers.isNotEmpty ? provider.papers.first.id : null);
    int? selectedPrintoutTypeId = rate?.printoutTypeId ?? (provider.printoutTypes.isNotEmpty ? provider.printoutTypes.first.id : null);

    final firstRateCtrl = TextEditingController(text: (rate?.firstCopyRate ?? 5.0).toString());
    final addRateCtrl = TextEditingController(text: (rate?.additionalCopyRate ?? 2.0).toString());

    if (selectedPaperId == null || selectedPrintoutTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please ensure Papers and Printout Types exist before defining rates!'), backgroundColor: AppColors.error),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(rate == null ? 'Configure New Rate' : 'Edit Rate'),
          content: SingleChildScrollView(
            child: Container(
              width: 500,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: selectedPaperId,
                      decoration: const InputDecoration(labelText: 'Paper Master *'),
                      items: provider.papers
                          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.paperName)))
                          .toList(),
                      onChanged: rate != null ? null : (v) => setDialogState(() => selectedPaperId = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int>(
                      value: selectedPrintoutTypeId,
                      decoration: const InputDecoration(labelText: 'Printout Type *'),
                      items: provider.printoutTypes
                          .map((pt) => DropdownMenuItem(value: pt.id, child: Text('${pt.name} (${pt.sides}, ${pt.colorMode})')))
                          .toList(),
                      onChanged: rate != null ? null : (v) => setDialogState(() => selectedPrintoutTypeId = v),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: firstRateCtrl,
                            decoration: const InputDecoration(labelText: 'First Copy Rate (₹) *'),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Rate is required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: addRateCtrl,
                            decoration: const InputDecoration(labelText: 'Additional Copy Rate (₹) *'),
                            keyboardType: TextInputType.number,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Rate is required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Rate formula: Qty = 1 => First Rate. Qty > 1 => First Rate + (Qty - 1) * Additional Rate.',
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
                final rateModel = RateModel(
                  id: rate?.id,
                  paperId: selectedPaperId!,
                  printoutTypeId: selectedPrintoutTypeId!,
                  firstCopyRate: double.tryParse(firstRateCtrl.text.trim()) ?? 0.0,
                  additionalCopyRate: double.tryParse(addRateCtrl.text.trim()) ?? 0.0,
                );

                bool success = rate == null
                    ? await provider.createRate(rateModel)
                    : await provider.createRate(rateModel); // Provider handles update/create

                if (mounted) {
                  if (success) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rate configuration saved!'), backgroundColor: AppColors.success),
                    );
                  } else if (provider.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: Text(rate == null ? 'Save Rate' : 'Update Rate'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaperProvider>();
    final rates = provider.rates;

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
                  Text('Rate Master', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Database-driven pricing rates for Paper + Printout Type combinations', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showRateDialog(),
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: const Text('Add / Configure Rate'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: AppDataTable(
              isLoading: provider.isLoading,
              data: rates,
              emptyMessage: 'No rates configured in Rate Master',
              columns: [
                AppTableColumn(title: 'Paper Name', builder: (r) => Text(r.paperName ?? 'Paper', style: const TextStyle(fontWeight: FontWeight.bold))),
                AppTableColumn(title: 'Printout Type', builder: (r) => Text(r.printoutTypeName ?? 'Printout Type')),
                AppTableColumn(title: 'First Copy Rate', builder: (r) => Text(Formatters.formatCurrency(r.firstCopyRate), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary))),
                AppTableColumn(title: 'Additional Copy Rate', builder: (r) => Text(Formatters.formatCurrency(r.additionalCopyRate), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary))),
                AppTableColumn(
                  title: 'Actions',
                  builder: (r) => IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                    onPressed: () => _showRateDialog(r),
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
