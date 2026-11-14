import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_utils.dart';
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
            content: Text('Error selecting file: $e'),
            backgroundColor: AppColors.failed,
          ),
        );
      }
    }
  }

  /// Helper to generate a dummy 50MB test catalog file directly on device
  Future<void> _create50MbDummyCatalog() async {
    setState(() => _isGeneratingDummy = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final dummyPath = '${tempDir.path}/pos_catalog_50mb.csv';
      final file = File(dummyPath);

      final sink = file.openWrite();
      sink.writeln(
        'SKU,BARCODE,PRODUCT_NAME,CATEGORY,PRICE,STOCK_QTY,TAX_RATE',
      );
      final chunk = List.filled(1024 * 1024, 'X').join('');
      for (int i = 0; i < 50; i++) {
        sink.write(chunk);
      }
      await sink.flush();
      await sink.close();

      final length = await file.length();
      setState(() {
        _selectedFilePath = dummyPath;
        _selectedFileName = 'pos_catalog_50mb.csv';
        _selectedFileSize = length;
        _isGeneratingDummy = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Generated 50MB POS Test Catalog File!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isGeneratingDummy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating test file: $e'),
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

    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileSize = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Upload queued into background engine! Continues if minimized.',
        ),
        backgroundColor: AppColors.posAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      builder: (context, state) {
        final activeUploads = state.tasks
            .where(
              (t) => t.isUpload && (t.isRunning || t.isPaused || t.isQueued),
            )
            .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // POS Section Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.posDarkHeader,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CATALOG & INVENTORY INGESTION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Bulk import product SKU catalogs, inventory dumps & media (>50MB)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // POS INGESTION CONTROL CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header & Specs
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: AppColors.posAccent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'TRANSMISSION SPECS: Multipart/Form-Data • Background Stream Buffer',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Two POS Action Buttons (Pick file / Generate 50MB)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.folder_open_rounded,
                                size: 18,
                              ),
                              label: const Text('SELECT LOCAL FILE'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: _pickFile,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                  : const Icon(
                                      Icons.flash_on_rounded,
                                      size: 18,
                                    ),
                              label: const Text('QUICK 50MB DUMMY'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.posOrange,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: _isGeneratingDummy
                                  ? null
                                  : _create50MbDummyCatalog,
                            ),
                          ),
                        ],
                      ),

                      // Selected File Inspector Box
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.posOnline,
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.posOnline,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'STAGED FOR TRANSMISSION',
                                    style: TextStyle(
                                      color: AppColors.posOnline,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    FileUtils.formatBytes(_selectedFileSize),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedFileName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.send_rounded, size: 18),
                                label: const Text(
                                  'TRANSMIT TO POS SAAS SERVER',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.posDarkHeader,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _startUpload,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ACTIVE POS INGESTION STREAM
                if (activeUploads.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.posAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ACTIVE TRANSMISSIONS (${activeUploads.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...activeUploads.map((task) => TransferItemTile(task: task)),
                  const SizedBox(height: 16),
                ],

                // POS INGESTION LOG / HISTORY TABLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'INGESTION AUDIT HISTORY',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'TOTAL: ${state.tasks.where((t) => t.isUpload).length} JOBS',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (state.tasks.where((t) => t.isUpload).isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'No catalog ingestion jobs executed yet.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                else
                  ...state.tasks
                      .where((t) => t.isUpload)
                      .map((task) => TransferItemTile(task: task)),
              ],
            ),
          ),
        );
      },
    );
  }
}
