// CHANGE-2026-09-07: Created Printer Configuration Screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/printer_settings_model.dart';
import '../providers/printer_provider.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _printerEnabled;
  late TextEditingController _ipController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _printerEnabled = false;
    _ipController = TextEditingController();
    _portController = TextEditingController(text: '9100');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<PrinterProvider>();
      await provider.fetchPrinterSettings();
      if (provider.settings != null) {
        setState(() {
          _printerEnabled = provider.settings!.printerEnabled;
          _ipController.text = provider.settings!.printerIp;
          _portController.text = provider.settings!.printerPort.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_printerEnabled && !_formKey.currentState!.validate()) return;

    final newSettings = PrinterSettingsModel(
      printerEnabled: _printerEnabled,
      printerIp: _ipController.text.trim(),
      printerPort: int.tryParse(_portController.text.trim()) ?? 9100,
    );

    final provider = context.read<PrinterProvider>();
    final success = await provider.savePrinterSettings(newSettings);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printer Configuration saved successfully!'), backgroundColor: AppColors.success),
        );
      } else if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage!), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _runTestPrint() async {
    if (!_printerEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer is currently DISABLED. Please enable printer and save configuration first.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final provider = context.read<PrinterProvider>();
    final success = await provider.testPrinter();

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test print sent successfully to thermal printer!'), backgroundColor: AppColors.success),
        );
      } else if (provider.errorMessage != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.print_disabled, color: AppColors.error),
                SizedBox(width: 8),
                Text('Test Print Failed'),
              ],
            ),
            content: Text(provider.errorMessage!),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrinterProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Printer Configuration', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Configure 3-inch ESC/POS thermal receipt printer settings for local network TCP printing', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          Card(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enable ON / OFF Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _printerEnabled ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _printerEnabled ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(_printerEnabled ? Icons.print : Icons.print_disabled, color: _printerEnabled ? AppColors.success : AppColors.error),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Thermal Printer Enabled', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                  Text(
                                    _printerEnabled ? 'Receipt printing is ACTIVE' : 'Receipt printing is DISABLED',
                                    style: TextStyle(fontSize: 12, color: _printerEnabled ? AppColors.success : AppColors.error),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Switch(
                            value: _printerEnabled,
                            activeColor: AppColors.success,
                            onChanged: (val) => setState(() => _printerEnabled = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Printer IP Input
                    TextFormField(
                      controller: _ipController,
                      enabled: _printerEnabled,
                      decoration: const InputDecoration(
                        labelText: 'Printer IP Address *',
                        hintText: 'e.g. 192.168.1.100',
                        prefixIcon: Icon(Icons.lan, size: 20),
                      ),
                      validator: (v) {
                        if (_printerEnabled && (v == null || v.trim().isEmpty)) {
                          return 'Printer IP Address is required when Printer is Enabled';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Printer Port Input
                    TextFormField(
                      controller: _portController,
                      enabled: _printerEnabled,
                      decoration: const InputDecoration(
                        labelText: 'Printer TCP Port *',
                        hintText: 'Default: 9100',
                        prefixIcon: Icon(Icons.settings_ethernet, size: 20),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (_printerEnabled) {
                          if (v == null || v.trim().isEmpty) return 'Printer TCP Port is required';
                          final p = int.tryParse(v.trim());
                          if (p == null || p <= 0 || p > 65535) return 'Valid port number between 1 and 65535 required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: provider.isLoading ? null : _saveSettings,
                            icon: const Icon(Icons.save),
                            label: Text(provider.isLoading ? 'Saving...' : 'Save Configuration'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (provider.isLoading || !_printerEnabled) ? null : _runTestPrint,
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('Test Print'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
