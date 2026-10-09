import 'dart:io';
import 'package:allen/fitness/services/ai_service.dart';
import 'package:allen/pallete.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CalorieScannerPage extends StatefulWidget {
  const CalorieScannerPage({super.key});

  @override
  State<CalorieScannerPage> createState() => _CalorieScannerPageState();
}

class _CalorieScannerPageState extends State<CalorieScannerPage> {
  final AiService _aiService = AiService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  bool _loading = false;
  Map<String, String>? _result;
  // ignore: unused_field
  String? _rawResult;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _result = null;
        _rawResult = null;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    final response = await _aiService.analyzeFood(_selectedImage!);

    // Parse the response
    final parsed = _parseResult(response);

    setState(() {
      _result = parsed;
      _rawResult = response;
      _loading = false;
    });
  }

  Map<String, String> _parseResult(String response) {
    final result = <String, String>{};
    final lines = response.split('\n');

    for (final line in lines) {
      if (line.startsWith('FOOD:')) {
        result['food'] = line.replaceFirst('FOOD:', '').trim();
      } else if (line.startsWith('CALORIES:')) {
        result['calories'] = line.replaceFirst('CALORIES:', '').trim();
      } else if (line.startsWith('PROTEIN:')) {
        result['protein'] = line.replaceFirst('PROTEIN:', '').trim();
      } else if (line.startsWith('CARBS:')) {
        result['carbs'] = line.replaceFirst('CARBS:', '').trim();
      } else if (line.startsWith('FAT:')) {
        result['fat'] = line.replaceFirst('FAT:', '').trim();
      } else if (line.startsWith('TIP:')) {
        result['tip'] = line.replaceFirst('TIP:', '').trim();
      }
    }

    return result;
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Pallete.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Pallete.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Choose Image Source',
              style: TextStyle(
                color: Pallete.mainFontColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _sourceOption(
              icon: Icons.camera_alt_rounded,
              label: 'Take a Photo',
              subtitle: 'Use your camera',
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            _sourceOption(
              icon: Icons.photo_library_rounded,
              label: 'Choose from Gallery',
              subtitle: 'Pick an existing photo',
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      appBar: AppBar(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('Calorie Scanner'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Pallete.borderColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Pallete.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Pallete.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Pallete.primaryAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Pallete.primaryAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Food Analyzer',
                          style: TextStyle(
                            color: Pallete.mainFontColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Take or upload a photo of your food',
                          style: TextStyle(
                            color: Pallete.subFontColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Image picker area
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: Pallete.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedImage != null
                        ? Pallete.primaryAccent
                        : Pallete.borderColor,
                    width: _selectedImage != null ? 1.5 : 1,
                  ),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Pallete.backgroundColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Tap to change',
                                  style: TextStyle(
                                    color: Pallete.mainFontColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 50,
                            color: Pallete.primaryAccent.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tap to add food photo',
                            style: TextStyle(
                              color: Pallete.subFontColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Camera or Gallery',
                            style: TextStyle(
                              color: Pallete.hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Analyze button
            if (_selectedImage != null)
              GestureDetector(
                onTap: _loading ? null : _analyzeImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _loading ? Pallete.cardColor : Pallete.primaryAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _loading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Pallete.primaryAccent,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Analyzing food...',
                                style: TextStyle(
                                  color: Pallete.subFontColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            '🔍 Analyze Calories',
                            style: TextStyle(
                              color: Pallete.backgroundColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Results
            if (_result != null && _result!.isNotEmpty) ...[
              const Text(
                'ANALYSIS RESULT',
                style: TextStyle(
                  color: Pallete.subFontColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),

              // Food name
              if (_result!['food'] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Pallete.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Pallete.borderColor),
                  ),
                  child: Row(
                    children: [
                      const Text('🍽', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Food Detected',
                              style: TextStyle(
                                color: Pallete.subFontColor,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _result!['food']!,
                              style: const TextStyle(
                                color: Pallete.mainFontColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Calories big card
              if (_result!['calories'] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Pallete.primaryAccent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Pallete.primaryAccent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _result!['calories']!,
                        style: const TextStyle(
                          color: Pallete.primaryAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Estimated Calories',
                        style: TextStyle(
                          color: Pallete.subFontColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

              // Macros row
              Row(
                children: [
                  _macroCard(
                    '🥩',
                    'Protein',
                    _result!['protein'] ?? '--',
                    Pallete.successColor,
                  ),
                  const SizedBox(width: 8),
                  _macroCard(
                    '🌾',
                    'Carbs',
                    _result!['carbs'] ?? '--',
                    Colors.orangeAccent,
                  ),
                  const SizedBox(width: 8),
                  _macroCard(
                    '🧈',
                    'Fat',
                    _result!['fat'] ?? '--',
                    Colors.blueAccent,
                  ),
                ],
              ),

              // Tip
              if (_result!['tip'] != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Pallete.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Pallete.borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Health Tip',
                              style: TextStyle(
                                color: Pallete.subFontColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _result!['tip']!,
                              style: const TextStyle(
                                color: Pallete.mainFontColor,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Disclaimer
              const Text(
                '⚠️ These are estimates only. Actual values may vary based on portion size and preparation.',
                style: TextStyle(
                  color: Pallete.hintColor,
                  fontSize: 11,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _macroCard(String emoji, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Pallete.subFontColor,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Pallete.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Pallete.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Pallete.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Pallete.primaryAccent, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Pallete.mainFontColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Pallete.subFontColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
