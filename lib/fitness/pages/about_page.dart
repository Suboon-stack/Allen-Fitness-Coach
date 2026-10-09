import 'package:allen/pallete.dart';
import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      appBar: AppBar(
        backgroundColor: Pallete.surfaceColor,
        title: const Text('About'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Pallete.borderColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Pallete.primaryAccent, width: 2),
              ),
              child:const  CircleAvatar(
                radius: 50,
                backgroundColor: Pallete.cardColor,
                child: Icon(Icons.fitness_center_rounded,
                    size: 50, color: Pallete.primaryAccent),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'A L L E N',
              style: TextStyle(
                color: Pallete.mainFontColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Pallete.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Pallete.primaryAccent.withValues(alpha: 0.3)),
              ),
              child: const Text('Version 1.0.0',
                  style: TextStyle(
                      color: Pallete.primaryAccent, fontSize: 12)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your AI Fitness Coach',
              style:
                  TextStyle(color: Pallete.subFontColor, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _card(Icons.info_outline_rounded, Pallete.primaryAccent,
                'What is Allen?',
                'Allen is a smart AI fitness coach powered by Google Gemini. Get personalized workouts, meal plans, and fitness advice instantly.'),
            const SizedBox(height: 10),
            _card(Icons.bolt_rounded, Colors.orangeAccent,
                'Powered By',
                'Google Gemini AI for smart responses, Firebase for secure authentication, and Flutter for a smooth cross-platform experience.'),
            const SizedBox(height: 10),
            _card(Icons.star_outline_rounded, Pallete.successColor,
                'Features',
                'AI workout generator, personalized meal planning, progress tracking, and an AI coach chat — all completely free.'),
            const SizedBox(height: 32),
            const Divider(color: Pallete.borderColor),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _chip('Flutter', Icons.phone_android_rounded),
                _chip('Firebase', Icons.local_fire_department_rounded),
                _chip('Gemini AI', Icons.auto_awesome_rounded),
                _chip('Dart', Icons.code_rounded),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              '© 2025 Allen Fitness. All rights reserved.',
              style: TextStyle(
                  color: Pallete.hintColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(IconData icon, Color color, String title, String desc) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Pallete.mainFontColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(desc,
                    style: const TextStyle(
                        color: Pallete.subFontColor,
                        fontSize: 13,
                        height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, IconData icon) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Pallete.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Pallete.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Pallete.subFontColor),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Pallete.subFontColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}