import 'package:app/widgets/map.dart';
import 'package:app/widgets/spots_sheet.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Stack(
        children: [
          Map(),
          SpotsSheet(),
        ],
      ),
    );
  }
}
