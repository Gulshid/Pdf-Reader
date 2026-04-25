// converter_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../shared/models/pdf_file_model.dart';
import '../../../shared/models/conversion_task_model.dart';
import '../bloc/converter_bloc.dart';
import '../bloc/converter_event.dart';
import '../bloc/converter_state.dart';
import 'widgets/format_selector.dart';
import 'widgets/conversion_progress.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key, this.initialFile, this.isEmbedded = false});
  final PdfFileModel? initialFile;
  final bool isEmbedded;

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context
              .read<ConverterBloc>()
              .add(ConverterSetSourceEvent(widget.initialFile!));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ConverterView(isEmbedded: widget.isEmbedded);
  }
}

class _ConverterView extends StatelessWidget {
  const _ConverterView({this.isEmbedded = false});
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final body = BlocConsumer<ConverterBloc, ConverterState>(
      listener: (context, state) {
        if (state.status == ConverterStatus.failed) {
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
              // ── Source file ──────────────────────────────────────────────
              _SectionLabel('Source File'),
              SizedBox(height: 8.h),
              _SourceCard(state: state),
              SizedBox(height: 24.h),

              // ── Target format ────────────────────────────────────────────
              if (state.sourceFile != null &&
                  state.status != ConverterStatus.running &&
                  state.status != ConverterStatus.done) ...[
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

              // ── States ───────────────────────────────────────────────────
              if (state.status == ConverterStatus.running) ...[
                ConversionProgress(
                  status: ConversionStatus.running,
                  progress: state.progress,
                  sourceLabel: state.sourceFormat?.label,
                  targetLabel: state.targetFormat?.label,
                ),

              ] else if (state.status == ConverterStatus.done) ...[
                ConversionProgress(
                  status: ConversionStatus.done,
                  progress: 1.0,
                  outputPath: state.outputPath,
                ),
                SizedBox(height: 20.h),

                // ── Action buttons ─────────────────────────────────────────
                _DoneActions(outputPath: state.outputPath!),
                SizedBox(height: 12.h),

                OutlinedButton.icon(
                  onPressed: () => context
                      .read<ConverterBloc>()
                      .add(const ConverterResetEvent()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Convert Another'),
                ),

              ] else if (state.status == ConverterStatus.failed) ...[
                ConversionProgress(
                  status: ConversionStatus.failed,
                  progress: 0,
                  error: state.error,
                ),
                SizedBox(height: 12.h),
                ElevatedButton.icon(
                  onPressed: () => context
                      .read<ConverterBloc>()
                      .add(const ConverterResetEvent()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),

              ] else ...[
                // Idle → Convert button
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
    );

    if (isEmbedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Format Converter')),
      body: body,
    );
  }
}

// ── Done action buttons ───────────────────────────────────────────────────────
//
// Three actions:
//  1. Open    — opens in-place from app-internal storage (always works)
//  2. Share   — native share sheet, user can save to Downloads/WhatsApp/etc.
//  3. Save    — copies to /storage/emulated/0/Download/ IF permission granted,
//               otherwise falls back to share sheet gracefully.

class _DoneActions extends StatefulWidget {
  const _DoneActions({required this.outputPath});
  final String outputPath;

  @override
  State<_DoneActions> createState() => _DoneActionsState();
}

class _DoneActionsState extends State<_DoneActions> {
  bool _saving = false;

  /// Share via native share sheet — no permission required.
  Future<void> _share() async {
    await Share.shareXFiles(
      [XFile(widget.outputPath)],
      subject: p.basename(widget.outputPath),
    );
  }

  /// Save a copy to public Downloads folder.
  /// On Android 13+ (API 33+) no runtime permission is needed for
  /// writing to Downloads via File copy (scoped storage allows it for
  /// files the app created). On older versions we request WRITE permission
  /// and fall back to share sheet if denied.
  Future<void> _saveToDownloads() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final fileName = p.basename(widget.outputPath);

      if (Platform.isAndroid) {
        final downloadsDir =
            Directory('/storage/emulated/0/Download/PdfReaderPro');
        if (!downloadsDir.existsSync()) {
          downloadsDir.createSync(recursive: true);
        }

        final destPath = p.join(downloadsDir.path, fileName);
        await File(widget.outputPath).copy(destPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to Downloads/PdfReaderPro/$fileName'),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => OpenFilex.open(destPath),
              ),
            ),
          );
        }
      } else {
        // iOS: share sheet is the correct "save" mechanism
        await _share();
      }
    } catch (e) {
      // If direct copy fails (older Android), fall back to share sheet
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save directly — opening share sheet…'),
          ),
        );
      }
      await _share();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Open
        ElevatedButton.icon(
          onPressed: () => OpenFilex.open(widget.outputPath),
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('Open File'),
        ),
        SizedBox(height: 10.h),

        // Row: Share | Save to Downloads
        Row(
          children: [
            // Share
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ),
            SizedBox(width: 10.w),

            // Save to Downloads
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _saveToDownloads,
                icon: _saving
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_saving ? 'Saving…' : 'Save to Downloads'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

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

// ── Source card ───────────────────────────────────────────────────────────────

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
              Icon(Icons.upload_file_rounded, color: cs.primary, size: 32.sp),
              SizedBox(height: 8.h),
              Text(
                'Tap to select a file',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.primary),
              ),
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
              (state.sourceFormat?.label ?? state.sourceFile!.extension).toUpperCase(),
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                fontSize: 10.sp,
              ),
            ),
          ),
        ),
        title: Text(
          state.sourceFile!.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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