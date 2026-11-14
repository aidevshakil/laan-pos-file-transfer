import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../../domain/entities/transfer_task.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_event.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/transfer_item_tile.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String? _selectedFilePath;
  String? _selectedFileName;
  int _selectedFileSize = 0;
  bool _isGeneratingDummy = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _selectedFilePath = file.path;
            _selectedFileName = file.name;
            _selectedFileSize = file.size;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: AppColors.failed,
          ),
        );
      }
    }
  }

  /// Helper to generate a dummy ~50MB file directly on device storage for testing large transfers
  Future<void> _create50MbDummyFile() async {
    setState(() => _isGeneratingDummy = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final dummyPath = '${tempDir.path}/laan_catalog_50mb.csv';
      final file = File(dummyPath);

      // Write in chunks to create exactly 50 MB
      final sink = file.openWrite();
      final chunk = List.filled(1024 * 1024, 'A').join(''); // 1 MB chunk
      for (int i = 0; i < 50; i++) {
        sink.write(chunk);
      }
      await sink.flush();
      await sink.close();

      final length = await file.length();
      setState(() {
        _selectedFilePath = dummyPath;
        _selectedFileName = 'laan_catalog_50mb.csv';
        _selectedFileSize = length;
        _isGeneratingDummy = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generated 50MB test catalog file!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isGeneratingDummy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating dummy file: $e'),
            backgroundColor: AppColors.failed,
          ),
        );
      }
    }
  }

  void _startUpload() {
    if (_selectedFilePath == null || _selectedFileName == null) return;

    context.read<TransferBloc>().add(
          StartUploadEvent(
            filePath: _selectedFilePath!,
            fileName: _selectedFileName!,
            fileSize: _selectedFileSize,
          ),
        );

    // Reset selection after queuing
    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileSize = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Upload started! Continues even if you navigate away.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('POS Catalog & Report Upload'),
      ),
      body: BlocBuilder<TransferBloc, TransferState>(
        builder: (context, state) {
          // Get the most recent active upload or latest upload
          final activeUploads = state.tasks
              .where((t) => t.isUpload && (t.isRunning || t.isPaused || t.isQueued))
              .toList();

          final latestUpload = activeUploads.isNotEmpty
              ? activeUploads.first
              : state.tasks.where((t) => t.isUpload).firstOrNull;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Upload Box
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_upload_outlined,
                          size: 40,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Upload Large POS Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select product catalogs, inventory CSVs or video logs (>50MB supported). Upload continues in background.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Pick Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.attach_file_rounded, size: 18),
                              label: const Text('Pick File'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _pickFile,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: _isGeneratingDummy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.note_add_rounded, size: 18),
                              label: const Text('Dummy 50MB'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                              onPressed: _isGeneratingDummy ? null : _create50MbDummyFile,
                            ),
                          ),
                        ],
                      ),

                      // Selected File Details Preview
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    FileUtils.getFileIcon(_selectedFileName!),
                                    color: AppColors.accent,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedFileName!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          FileUtils.formatBytes(_selectedFileSize),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _startUpload,
                                child: const Text('Start Multipart Upload'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Live Active Upload Card (if any ongoing)
                if (latestUpload != null && (latestUpload.isRunning || latestUpload.isPaused)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Current Upload Status',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          latestUpload.isRunning ? 'Active' : 'Paused',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: latestUpload.isRunning ? AppColors.running : AppColors.paused,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TransferItemTile(task: latestUpload),
                ],

                // All Recent Uploads Header
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Upload History',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),

                // Upload list
                ...state.tasks.where((t) => t.isUpload).map(
                      (task) => TransferItemTile(task: task),
                    ),

                if (state.tasks.where((t) => t.isUpload).isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'No uploads yet. Pick a file or generate 50MB test file to begin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
