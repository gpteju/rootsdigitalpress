// CHANGE-2026-09-07: Created Company Master Screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/company_model.dart';
import '../providers/company_provider.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _stateCodeController = TextEditingController();
  final _gstinController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _prefixController = TextEditingController();
  final _estimatePrefixController = TextEditingController();
  final _estimateCurrentNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<CompanyProvider>();
      await provider.fetchCompany();
      if (provider.company != null) {
        _populateFields(provider.company!);
      }
    });
  }

  void _populateFields(CompanyModel company) {
    _nameController.text = company.companyName;
    _addressController.text = company.address;
    _cityController.text = company.city;
    _stateController.text = company.state;
    _stateCodeController.text = company.stateCode;
    _gstinController.text = company.gstin ?? '';
    _phoneController.text = company.phone;
    _emailController.text = company.email;
    _prefixController.text = company.invoicePrefix;
    _estimatePrefixController.text = company.estimatePrefix;
    _estimateCurrentNumberController.text = company.estimateCurrentNumber.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _stateCodeController.dispose();
    _gstinController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _prefixController.dispose();
    _estimatePrefixController.dispose();
    _estimateCurrentNumberController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final companyData = CompanyModel(
      companyName: _nameController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      stateCode: _stateCodeController.text.trim(),
      gstin: _gstinController.text.trim().isEmpty ? null : _gstinController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      invoicePrefix: _prefixController.text.trim().isEmpty ? 'INV-' : _prefixController.text.trim(),
      estimatePrefix: _estimatePrefixController.text.trim().isEmpty ? 'JOB-' : _estimatePrefixController.text.trim(),
      estimateCurrentNumber: int.tryParse(_estimateCurrentNumberController.text.trim()) ?? 0,
    );

    final provider = context.read<CompanyProvider>();
    final success = await provider.saveCompany(companyData);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company profile saved successfully!'), backgroundColor: AppColors.success),
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
    final provider = context.watch<CompanyProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business, color: AppColors.primary, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Company Master Configuration',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Store your company profile, state details, and invoice preferences. Dynamic GST evaluation uses this company state.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const Divider(height: 32),

                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Company Name *', hintText: 'e.g. Apex Printouts Pvt Ltd'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Company Name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Street Address *', hintText: 'Address Line'),
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(labelText: 'City *'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'City is required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(labelText: 'State *', hintText: 'e.g. Tamil Nadu'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'State is required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _stateCodeController,
                            decoration: const InputDecoration(labelText: 'State Code *', hintText: 'e.g. 33'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'State Code is required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _gstinController,
                            decoration: const InputDecoration(labelText: 'GSTIN', hintText: 'e.g. 33AAAAA0000A1Z5'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _prefixController,
                            decoration: const InputDecoration(labelText: 'Invoice Number Prefix *', hintText: 'e.g. INV-'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Invoice Prefix is required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _estimatePrefixController,
                            decoration: const InputDecoration(labelText: 'Estimate Number Prefix *', hintText: 'e.g. JOB-'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Estimate Prefix required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _estimateCurrentNumberController,
                            decoration: const InputDecoration(labelText: 'Starting Estimate Sequence Number', hintText: 'e.g. 0'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(labelText: 'Phone Number *'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(labelText: 'Email Address *'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: provider.isLoading ? null : _submitForm,
                        icon: provider.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(provider.isLoading ? 'Saving...' : 'Save Company Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
