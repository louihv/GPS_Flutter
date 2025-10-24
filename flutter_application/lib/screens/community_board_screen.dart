import 'package:flutter/material.dart';

class CommunityBoardScreen extends StatelessWidget {
  const CommunityBoardScreen({super.key}); 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community Board')),
      body: const Center(child: Text('Community Boarde - Add your content here')),
      
    );
  }
}