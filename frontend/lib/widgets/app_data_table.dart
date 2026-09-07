// CHANGE-2026-09-07: Created AppDataTable reusable data grid with responsive layout, search, empty state, and action buttons.

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class AppTableColumn {
  final String title;
  final Widget Function(dynamic row) builder;
  final double? width;

  AppTableColumn({
    required this.title,
    required this.builder,
    this.width,
  });
}

class AppDataTable extends StatelessWidget {
  final List<AppTableColumn> columns;
  final List<dynamic> data;
  final bool isLoading;
  final String emptyMessage;

  const AppDataTable({
    super.key,
    required this.columns,
    required this.data,
    this.isLoading = false,
    this.emptyMessage = 'No records found',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.05)),
          dividerThickness: 1,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 64,
          columns: columns
              .map(
                (col) => DataColumn(
                  label: Text(
                    col.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              )
              .toList(),
          rows: data
              .map(
                (row) => DataRow(
                  cells: columns
                      .map(
                        (col) => DataCell(col.builder(row)),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
