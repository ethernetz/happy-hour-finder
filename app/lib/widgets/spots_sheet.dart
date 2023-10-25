import 'package:app/providers/map_visible_region_places_provider.dart';
import 'package:app/spot_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SpotsSheet extends StatelessWidget {
  const SpotsSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MapVisibleRegionPlacesProvider>(
        builder: (context, provider, child) {
      final spots = provider.spotsInCamera;
      return DraggableScrollableSheet(
        initialChildSize: 0.33,
        minChildSize: 0.1,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.1, 0.33, 1.0],
        builder: (BuildContext context, ScrollController scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
              ),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.only(top: 10.0),
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                ),
                // List items
                ...spots.map((spot) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: SpotCard(
                        spot: spot,
                      ),
                    )),
              ],
            ),
          );
        },
      );
    });
  }
}
