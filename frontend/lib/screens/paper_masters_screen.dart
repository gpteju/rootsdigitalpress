// CHANGE-2026-09-07: Updated Paper Masters Screen adding Add/Edit dialogs and actions for Paper Types, GSM Values, and Paper Sizes.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/paper_models.dart';
import '../providers/paper_provider.dart';
import '../widgets/app_data_table.dart';

class PaperMastersScreen extends StatefulWidget {
  final int initialTabIndex;
  const PaperMastersScreen({super.key, this.initialTabIndex = 0});

  @override
  State<PaperMastersScreen> createState() => _PaperMastersScreenState();
}

class _PaperMastersScreenState extends State<PaperMastersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaperProvider>().fetchAllMasters();
    });
  }

  @override
  void didUpdateWidget(PaperMastersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showPaperTypeDialog([PaperTypeModel? paperType]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: paperType?.name ?? '');
    final descCtrl = TextEditingController(text: paperType?.description ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Text(paperType == null ? 'Add New Paper Type' : 'Edit Paper Type'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Paper Type Name *', hintText: 'e.g. Maplitho, Art Paper, Glossy, Matt'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Paper Type Name is required' : null,
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final typeModel = PaperTypeModel(
                id: paperType?.id,
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );

              final provider = context.read<PaperProvider>();
              bool success = paperType == null
                  ? await provider.createPaperType(typeModel)
                  : await provider.updatePaperType(paperType.id!, typeModel);

              if (mounted) {
                if (success) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(paperType == null ? 'Paper Type created!' : 'Paper Type updated!'), backgroundColor: AppColors.success),
                  );
                } else if (provider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: Text(paperType == null ? 'Save Paper Type' : 'Update Paper Type'),
          ),
        ],
      ),
    );
  }

  void _showGsmDialog([PaperGsmModel? gsm]) {
    final formKey = GlobalKey<FormState>();
    final valCtrl = TextEditingController(text: gsm?.gsmValue.toString() ?? '');
    final descCtrl = TextEditingController(text: gsm?.description ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Text(gsm == null ? 'Add New GSM Value' : 'Edit GSM Value'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: valCtrl,
                  decoration: const InputDecoration(labelText: 'GSM Value (Numeric) *', hintText: 'e.g. 70, 80, 100, 120, 150'),
                  keyboardType: TextInputType.number,
                  validator: (v) => (v == null || v.trim().isEmpty || int.tryParse(v.trim()) == null) ? 'Valid integer GSM is required' : null,
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final gsmModel = PaperGsmModel(
                id: gsm?.id,
                gsmValue: int.parse(valCtrl.text.trim()),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );

              final provider = context.read<PaperProvider>();
              bool success = gsm == null
                  ? await provider.createPaperGsm(gsmModel)
                  : await provider.updatePaperGsm(gsm.id!, gsmModel);

              if (mounted) {
                if (success) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(gsm == null ? 'GSM value created!' : 'GSM value updated!'), backgroundColor: AppColors.success),
                  );
                } else if (provider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: Text(gsm == null ? 'Save GSM' : 'Update GSM'),
          ),
        ],
      ),
    );
  }

  void _showPaperSizeDialog([PaperSizeModel? paperSize]) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: paperSize?.name ?? '');
    final descCtrl = TextEditingController(text: paperSize?.description ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Text(paperSize == null ? 'Add New Paper Size' : 'Edit Paper Size'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Paper Size Name *', hintText: 'e.g. A4, A3, A5, Legal, Letter'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Paper Size Name is required' : null,
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final sizeModel = PaperSizeModel(
                id: paperSize?.id,
                name: nameCtrl.text.trim(),
                description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );

              final provider = context.read<PaperProvider>();
              bool success = paperSize == null
                  ? await provider.createPaperSize(sizeModel)
                  : await provider.updatePaperSize(paperSize.id!, sizeModel);

              if (mounted) {
                if (success) {
                  Navigator.pop(dialogCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(paperSize == null ? 'Paper Size created!' : 'Paper Size updated!'), backgroundColor: AppColors.success),
                  );
                } else if (provider.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: Text(paperSize == null ? 'Save Paper Size' : 'Update Paper Size'),
          ),
        ],
      ),
    );
  }

  void _showPaperDialog() {
    final provider = context.read<PaperProvider>();
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'Sheet');
    final openStockCtrl = TextEditingController(text: '0');
    final reorderCtrl = TextEditingController(text: '100');

    int? selectedTypeId = provider.paperTypes.isNotEmpty ? provider.paperTypes.first.id : null;
    int? selectedGsmId = provider.paperGsms.isNotEmpty ? provider.paperGsms.first.id : null;
    int? selectedSizeId = provider.paperSizes.isNotEmpty ? provider.paperSizes.first.id : null;

    if (selectedTypeId == null || selectedGsmId == null || selectedSizeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please ensure Paper Type, GSM, and Paper Size entries exist before creating a Paper!'), backgroundColor: AppColors.error),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Unified Paper'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Paper Display Name *', hintText: 'e.g. Maplitho 80 GSM A4'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Paper Name is required' : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int>(
                      initialValue: selectedTypeId,
                      decoration: const InputDecoration(labelText: 'Paper Type *'),
                      items: provider.paperTypes
                          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedTypeId = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int>(
                      initialValue: selectedGsmId,
                      decoration: const InputDecoration(labelText: 'GSM Value *'),
                      items: provider.paperGsms
                          .map((g) => DropdownMenuItem(value: g.id, child: Text('${g.gsmValue} GSM')))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedGsmId = v),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<int>(
                      initialValue: selectedSizeId,
                      decoration: const InputDecoration(labelText: 'Paper Size *'),
                      items: provider.paperSizes
                          .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedSizeId = v),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: unitCtrl,
                            decoration: const InputDecoration(labelText: 'Purchase Unit *'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Unit required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: openStockCtrl,
                            decoration: const InputDecoration(labelText: 'Opening Stock'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: reorderCtrl,
                            decoration: const InputDecoration(labelText: 'Reorder Level'),
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
                final paper = PaperModel(
                  paperName: nameCtrl.text.trim(),
                  paperTypeId: selectedTypeId!,
                  paperGsmId: selectedGsmId!,
                  paperSizeId: selectedSizeId!,
                  purchaseUnit: unitCtrl.text.trim(),
                  openingStock: double.tryParse(openStockCtrl.text.trim()) ?? 0.0,
                  reorderLevel: double.tryParse(reorderCtrl.text.trim()) ?? 100.0,
                );

                bool success = await provider.createPaper(paper);
                if (mounted) {
                  if (success) {
                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paper master created!'), backgroundColor: AppColors.success),
                    );
                  } else if (provider.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Create Paper'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaperProvider>();

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
                  Text('Paper Masters', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Database-driven Paper Types, GSM values, Sizes, and Unified Papers', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showPaperTypeDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Paper Type'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showGsmDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add GSM'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showPaperSizeDialog(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Paper Size'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showPaperDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Unified Paper'),
                  ),
                ],
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
              Tab(text: 'Unified Papers'),
              Tab(text: 'Paper Types'),
              Tab(text: 'GSM Values'),
              Tab(text: 'Paper Sizes'),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Papers
                AppDataTable(
                  isLoading: provider.isLoading,
                  data: provider.papers,
                  emptyMessage: 'No papers registered',
                  columns: [
                    AppTableColumn(title: 'Paper Name', builder: (p) => Text(p.paperName, style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Type', builder: (p) => Text(p.paperTypeName ?? '-')),
                    AppTableColumn(title: 'GSM', builder: (p) => Text('${p.gsmValue ?? "-"} GSM')),
                    AppTableColumn(title: 'Size', builder: (p) => Text(p.paperSizeName ?? '-')),
                    AppTableColumn(title: 'Unit', builder: (p) => Text(p.purchaseUnit)),
                    AppTableColumn(title: 'Current Stock', builder: (p) => Text('${p.currentStock}', style: TextStyle(fontWeight: FontWeight.bold, color: p.currentStock <= p.reorderLevel ? AppColors.error : AppColors.success))),
                    AppTableColumn(title: 'Reorder Threshold', builder: (p) => Text('${p.reorderLevel}')),
                  ],
                ),

                // Tab 2: Paper Types
                AppDataTable(
                  isLoading: provider.isLoading,
                  data: provider.paperTypes,
                  emptyMessage: 'No paper types configured',
                  columns: [
                    AppTableColumn(title: 'ID', builder: (pt) => Text('${pt.id}')),
                    AppTableColumn(title: 'Type Name', builder: (pt) => Text(pt.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Description', builder: (pt) => Text(pt.description ?? '-')),
                    AppTableColumn(
                      title: 'Actions',
                      builder: (pt) => IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                        onPressed: () => _showPaperTypeDialog(pt),
                      ),
                    ),
                  ],
                ),

                // Tab 3: GSM Values
                AppDataTable(
                  isLoading: provider.isLoading,
                  data: provider.paperGsms,
                  emptyMessage: 'No GSM values configured',
                  columns: [
                    AppTableColumn(title: 'ID', builder: (g) => Text('${g.id}')),
                    AppTableColumn(title: 'GSM Value', builder: (g) => Text('${g.gsmValue} GSM', style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Description', builder: (g) => Text(g.description ?? '-')),
                    AppTableColumn(
                      title: 'Actions',
                      builder: (g) => IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                        onPressed: () => _showGsmDialog(g),
                      ),
                    ),
                  ],
                ),

                // Tab 4: Paper Sizes
                AppDataTable(
                  isLoading: provider.isLoading,
                  data: provider.paperSizes,
                  emptyMessage: 'No paper sizes configured',
                  columns: [
                    AppTableColumn(title: 'ID', builder: (s) => Text('${s.id}')),
                    AppTableColumn(title: 'Size Name', builder: (s) => Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    AppTableColumn(title: 'Description', builder: (s) => Text(s.description ?? '-')),
                    AppTableColumn(
                      title: 'Actions',
                      builder: (s) => IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                        onPressed: () => _showPaperSizeDialog(s),
                      ),
                    ),
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
