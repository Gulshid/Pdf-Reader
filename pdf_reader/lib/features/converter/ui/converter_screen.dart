import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_filex/open_filex.dart';

import '../../../shared/models/pdf_file_model.dart';
import '../bloc/converter_bloc.dart';
import '../bloc/converter_event.dart';
import '../bloc/converter_state.dart';
import 'widgets/format_selector.dart';

class ConverterScreen extends StatelessWidget {
  const ConverterScreen({super.key, this.initialFile});
  final PdfFileModel? initialFile;

  @override
  Widget build(BuildContext context) {
    if (initialFile != null) {
      context
          .read<ConverterBloc>()
          .add(ConverterSetSourceEvent(initialFile!));
    }

    return const _ConverterView();
  }
}

class _ConverterView extends StatelessWidget {
  const _ConverterView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Format Converter')),
      body: BlocConsumer<ConverterBloc, ConverterState>(
        listener: (context, state) {
          if (state.status == ConverterStatus.done) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved to ${state.outputPath}'),
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () => OpenFilex.open(state.outputPath!),
                ),
              ),
            );
          }
          if (state.status == ConverterStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error ?? 'Conversion failed'),
                backgroundColor: cs.error,
              ),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Source file card
                _SectionLabel('Source File'),
                SizedBox(height: 8.h),
                _SourceCard(state: state),
                SizedBox(height: 24.h),

                // Target format
                if (state.sourceFile != null) ...[
                  _SectionLabel('Convert To'),
                  SizedBox(height: 8.h),
                  FormatSelector(
                    formats: state.availableTargets,
                    selected: state.targetFormat,
                    onSelected: (f) => context
                        .read<ConverterBloc>()
                        .add(ConverterSetTargetFormatEvent(f)),
                  ),
                  SizedBox(height: 32.h),
                ],

                // Progress / Convert button
                if (state.status == ConverterStatus.running) ...[
                  Column(
                    children: [
                      LinearProgressIndicator(value: state.progress),
                      SizedBox(height: 8.h),
                      Text(
                        '${(state.progress * 100).toInt()}%',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ] else if (state.status == ConverterStatus.done) ...[
                  Icon(Icons.check_circle_rounded,
                      color: const Color(0xFF2E7D32), size: 48.sp),
                  SizedBox(height: 8.h),
                  Text('Conversion complete!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context
                              .read<ConverterBloc>()
                              .add(const ConverterResetEvent()),
                          child: const Text('Convert Another'),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => OpenFilex.open(state.outputPath!),
                          child: const Text('Open File'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: state.canConvert
                        ? () => context
                            .read<ConverterBloc>()
                            .add(const ConverterStartEvent())
                        : null,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Convert'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontSize: 16.sp),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.state});
  final ConverterState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (state.sourceFile == null) {
      return InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () => context
            .read<ConverterBloc>()
            .add(const ConverterPickSourceEvent()),
        child: Container(
          height: 100.h,
          decoration: BoxDecoration(
            border: Border.all(color: cs.primary, width: 2),
            borderRadius: BorderRadius.circular(16.r),
            color: cs.primary.withOpacity(0.05),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file_rounded,
                  color: cs.primary, size: 32.sp),
              SizedBox(height: 8.h),
              Text('Tap to select a file',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.primary)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Center(
            child: Text(
              state.sourceFile!.extension,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                fontSize: 10.sp,
              ),
            ),
          ),
        ),
        title: Text(state.sourceFile!.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(state.sourceFile!.sizeFormatted),
        trailing: TextButton(
          onPressed: () => context
              .read<ConverterBloc>()
              .add(const ConverterPickSourceEvent()),
          child: const Text('Change'),
        ),
      ),
    );
  }
}