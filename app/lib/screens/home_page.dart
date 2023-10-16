import 'package:app/map.dart';
import 'package:app/providers/map_visible_region_places_provider.dart';
import 'package:app/spot_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Map(),
          Consumer<MapVisibleRegionPlacesProvider>(
              builder: (context, provider, child) {
            final spots = provider.allSpots;
            return DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.1,
              maxChildSize: 1.0,
              snap: true,
              snapSizes: const [0.1, 0.5, 1.0],
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Container(
                  color: Colors.grey[800],
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: spots.length,
                    padding: const EdgeInsets.only(top: 10.0),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: SpotCard(
                          spot: spots[index],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
