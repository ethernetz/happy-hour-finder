import 'package:app/providers/map_visible_region_places_provider.dart';
import 'package:app/widgets/spot_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SpotsSheet extends StatefulWidget {
  const SpotsSheet({
    super.key,
  });

  @override
  State<SpotsSheet> createState() => _SpotsSheetState();
}

class _SpotsSheetState extends State<SpotsSheet> {
  final DraggableScrollableController _draggableScrollableController =
      DraggableScrollableController();

  @override
  Widget build(BuildContext context) {
    return Selector<MapVisibleRegionPlacesProvider, String?>(
        selector: (_, provider) => provider.selectedSpotId,
        builder: (context, selectedSpotId, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (selectedSpotId != null) {
              _draggableScrollableController.animateTo(0.33,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut);
            }
          });
          return DraggableScrollableSheet(
            controller: _draggableScrollableController,
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
                child: Consumer<MapVisibleRegionPlacesProvider>(
                    builder: (context, provider, child) {
                  final spots = provider.spotsInCamera;
                  return ListView(
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
                      ...spots.map(
                        (spot) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: SpotCard(
                            spot: spot,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              );
            },
          );
        });
  }
}
