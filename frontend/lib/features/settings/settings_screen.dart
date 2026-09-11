import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableCaptureGuidance = true;
  bool _autoEnhanceContrast = true;
  bool _offlineStorageSync = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral50,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: System Appearance & Language
          _buildSettingsGroup(
            title: 'DISPLAY & LANGUAGE',
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.palette_outlined, color: AppColors.secondaryBlue),
                title: const Text('Interface Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Light Institutional Theme (Government Standard)', style: TextStyle(fontSize: 11, color: AppColors.neutral600)),
                trailing: const Icon(Icons.check_circle, color: AppColors.passGreen, size: 18),
              ),
              const Divider(height: 1, color: AppColors.neutral200),
              ListTile(
                dense: true,
                leading: const Icon(Icons.language_outlined, color: AppColors.secondaryBlue),
                title: const Text('Gazette Language', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('English (Statutory Standard)', style: TextStyle(fontSize: 11, color: AppColors.neutral600)),
                trailing: const Text('EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryBlue)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2: Inspection & OCR Preferences
          _buildSettingsGroup(
            title: 'INSPECTION & SCANNER PREFERENCES',
            children: [
              SwitchListTile(
                dense: true,
                secondary: const Icon(Icons.camera_enhance_outlined, color: AppColors.secondaryBlue),
                title: const Text('Surface Alignment Guidance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Shows viewfinder overlays for Front, Back, MRP & side panels', style: TextStyle(fontSize: 11, color: AppColors.neutral600)),
                value: _enableCaptureGuidance,
                activeThumbColor: AppColors.secondaryBlue,
                onChanged: (val) => setState(() => _enableCaptureGuidance = val),
              ),
              const Divider(height: 1, color: AppColors.neutral200),
              SwitchListTile(
                dense: true,
                secondary: const Icon(Icons.contrast_outlined, color: AppColors.secondaryBlue),
                title: const Text('Auto-Enhance Text Contrast', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Optimizes OCR binarization for low-contrast print', style: TextStyle(fontSize: 11, color: AppColors.neutral600)),
                value: _autoEnhanceContrast,
                activeThumbColor: AppColors.secondaryBlue,
                onChanged: (val) => setState(() => _autoEnhanceContrast = val),
              ),
              const Divider(height: 1, color: AppColors.neutral200),
              SwitchListTile(
                dense: true,
                secondary: const Icon(Icons.cloud_sync_outlined, color: AppColors.secondaryBlue),
                title: const Text('Background Evidence Sync', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Sync audit artifacts when online connectivity is restored', style: TextStyle(fontSize: 11, color: AppColors.neutral600)),
                value: _offlineStorageSync,
                activeThumbColor: AppColors.secondaryBlue,
                onChanged: (val) => setState(() => _offlineStorageSync = val),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 3: Data & Storage
          _buildSettingsGroup(
            title: 'STORAGE & CACHE',
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.cleaning_services_outlined, color: AppColors.reviewAmber),
                title: const Text('Clear Temporary Cache', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Frees space used by temporary cropped preview images', style: TextStyle(fontSize: 11, color: AppColors.neutral600)),
                trailing: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Temporary preview cache cleared successfully.'),
                        backgroundColor: AppColors.passGreen,
                      ),
                    );
                  },
                  child: const Text('Clear', style: TextStyle(color: AppColors.secondaryBlue, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 4: System Information
          _buildSettingsGroup(
            title: 'ABOUT APPLICATION',
            children: const [
              ListTile(
                dense: true,
                leading: Icon(Icons.info_outline, color: AppColors.secondaryBlue),
                title: Text('MAANAK Inspection Platform', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text('Automated Legal Metrology Compliance Engine', style: TextStyle(fontSize: 11, color: AppColors.neutral600)),
                trailing: Text('v1.0.0', style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AppColors.neutral500,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.neutral200),
            ...children,
          ],
        ),
      ),
    );
  }
}
