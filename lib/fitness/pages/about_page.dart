import 'package:flutter/material.dart';
import '../widgets/profile_components.dart';
import '../widgets/chat_widgets.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const ProfileScaffold(title: 'About Allen', children: [
        SizedBox(height: 16),
        Center(child: AllenSparkle()),
        SizedBox(height: 16),
        Center(
            child: Text('Allen',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
        Center(child: Text('AI Fitness Coach · Version 1.0.0')),
        ProfileSection('Fitness, on your terms.'),
        Text(
            'Allen brings workout planning, nutrition tools, progress tracking and AI fitness guidance together. The application is in active development.'),
        ProfileSection('AI guidance'),
        Text(
            'Gemini responses and photo-based nutrition values can be inaccurate. Review suggestions and estimates before using or saving them.'),
        ProfileSection('Your records'),
        Text(
            'Fitness records are stored locally on this device. Firebase manages authentication. See Data & Privacy for account ownership, export and shared-water limitations.'),
      ]);
}
