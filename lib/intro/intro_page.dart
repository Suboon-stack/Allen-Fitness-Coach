import 'package:allen/pallete.dart';
import 'package:flutter/material.dart';

class IntroPage extends StatelessWidget {
  final VoidCallback onContinue;

  const IntroPage({super.key, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pallete.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Pallete.primaryAccent,
                    width: 2,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 60,
                  backgroundColor: Pallete.cardColor,
                  child: Icon(
                    Icons.fitness_center_rounded,
                    size: 60,
                    color: Pallete.primaryAccent,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'A L L E N',
                style: TextStyle(
                  color: Pallete.mainFontColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your AI Fitness Coach',
                style: TextStyle(
                  color: Pallete.subFontColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Pallete.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Pallete.borderColor),
                ),
                child: Column(
                  children: [
                    _featureRow(
                      Icons.fitness_center_rounded,
                      'AI Workout Generator',
                    ),
                    const SizedBox(height: 12),
                    _featureRow(
                      Icons.restaurant_rounded,
                      'Personalized Meal Plans',
                    ),
                    const SizedBox(height: 12),
                    _featureRow(
                      Icons.trending_up_rounded,
                      'Progress Tracking',
                    ),
                    const SizedBox(height: 12),
                    _featureRow(
                      Icons.chat_bubble_outline_rounded,
                      'AI Coach Chat',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onContinue,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Pallete.primaryAccent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        color: Pallete.backgroundColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Pallete.primaryAccent, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Pallete.mainFontColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
