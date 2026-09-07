// CHANGE-2026-09-07: Created & Updated Printout Type Master Screen supporting Add & Edit actions.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/printout_type_model.dart';
import '../providers/paper_provider.dart';
import '../widgets/app_data_table.dart';

class PrintoutTypeScreen extends StatefulWidget {
  const PrintoutTypeScreen({super.key});

  @override
  State<PrintoutTypeScreen> createState() => _PrintoutTypeScreenState();
}

class _PrintoutTypeScreenState extends State<PrintoutTypeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaperProvider>().fetchPrintoutTypes();
    });
  }

  void _showPrintoutTypeDialog([PrintoutTypeModel? printoutType]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: printoutType?.name ?? '');
    final descCtrl = TextEditingController(text: printoutType?.description ?? '');
    String sides = printoutType?.sides ?? 'Single';
    String colorMode = printoutType?.colorMode ?? 'B/W';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(printoutType == null ? 'Add Configurable Printout Type' : 'Edit Printout Type'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 450,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Printout Type Name *', hintText: 'e.g. Front & Back - Color'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: sides,
                      decoration: const InputDecoration(labelText: 'Sides *'),
                      items: const [
                        DropdownMenuItem(value: 'Single', child: Text('Single Side (Front)')),
                        DropdownMenuItem(value: 'Double', child: Text('Double Side (Front & Back)')),
                      ],
                      onChanged: (v) => setDialogState(() => sides = v!),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: colorMode,
                      decoration: const InputDecoration(labelText: 'Color Mode *'),
                      items: const [
                        DropdownMenuItem(value: 'B/W', child: Text('Black & White')),
                        DropdownMenuItem(value: 'Color', child: Text('Color')),
                      ],
                      onChanged: (v) => setDialogState(() => colorMode = v!),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
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
                final pt = PrintoutTypeModel(
                  id: printoutType?.id,
                  name: nameCtrl.text.trim(),
                  sides: sides,
                  colorMode: colorMode,
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                );

                final provider = context.read<PaperProvider>();
                bool success = printoutType == null
                    ? await provider.createPrintoutType(pt)
                    : await provider.updatePrintoutType(printoutType.id!, pt);

                if (mounted) {
                  if (success) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(printoutType == null ? 'Printout type created!' : 'Printout type updated!'), backgroundColor: AppColors.success),
                    );
                  } else if (provider.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: Text(printoutType == null ? 'Save Printout Type' : 'Update Printout Type'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaperProvider>();
    final types = provider.printoutTypes;

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
                  Text('Printout Type Master', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Configure printout options (Front / Front & Back, Color / B/W) without changing code', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showPrintoutTypeDialog(),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Add Printout Type'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Expanded(
            child: AppDataTable(
              isLoading: provider.isLoading,
              data: types,
              emptyMessage: 'No printout types configured yet',
              columns: [
                AppTableColumn(title: 'Printout Type', builder: (pt) => Text(pt.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                AppTableColumn(title: 'Sides', builder: (pt) => Text(pt.sides)),
                AppTableColumn(title: 'Color Mode', builder: (pt) => Text(pt.colorMode)),
                AppTableColumn(title: 'Description', builder: (pt) => Text(pt.description ?? '-')),
                AppTableColumn(
                  title: 'Actions',
                  builder: (pt) => IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                    onPressed: () => _showPrintoutTypeDialog(pt),
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
