import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/models/conversion_task_model.dart';

class FormatSelector extends StatelessWidget {
  const FormatSelector({
    super.key,
    required this.formats,
    required this.selected,
    required this.onSelected,
  });

  final List<SupportedFormat> formats;
  final SupportedFormat? selected;
  final ValueChanged<SupportedFormat> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: formats.map((f) {
        final isSelected = f == selected;
        return GestureDetector(
          onTap: () => onSelected(f),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isSelected ? cs.primary : cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isSelected ? cs.primary : Colors.transparent,
              ),
            ),
            child: Text(
              f.label,
              style: TextStyle(
                color: isSelected ? Colors.white : cs.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}