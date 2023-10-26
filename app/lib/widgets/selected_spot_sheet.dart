import 'package:app/providers/spots_provider.dart';
import 'package:app/widgets/selected_spot_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectedSpotSheet extends StatefulWidget {
  const SelectedSpotSheet({
    super.key,
  });

  @override
  State<SelectedSpotSheet> createState() => _SelectedSpotSheetState();
}

class _SelectedSpotSheetState extends State<SelectedSpotSheet> {
  final DraggableScrollableController _draggableScrollableController =
      DraggableScrollableController();

  String? previousSelectedSpotId;

  @override
  void initState() {
    super.initState();
    _draggableScrollableController.addListener(() {
      if (_draggableScrollableController.size == 0.0) {
        context.read<SpotsProvider>().handleUnselectSpot();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<SpotsProvider, String?>(
      selector: (_, provider) => provider.selectedSpotId,
      builder: (context, selectedSpotId, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (selectedSpotId != null &&
              selectedSpotId != previousSelectedSpotId) {
            _draggableScrollableController.animateTo(
              0.33,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          } else if (selectedSpotId == null && previousSelectedSpotId != null) {
            _draggableScrollableController.animateTo(
              0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
          previousSelectedSpotId = selectedSpotId;
        });
        return DraggableScrollableSheet(
            controller: _draggableScrollableController,
            initialChildSize: 0,
            minChildSize: 0,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0, 0.33, 0.95],
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
                    Consumer<SpotsProvider>(
                      builder: (context, provider, _) {
                        final spot = provider.selectedSpot ??
                            provider.allSpots?[previousSelectedSpotId];
                        if (spot == null) return Container();
                        return SelectedSpotCard(
                          spot: spot,
                        );
                      },
                    ),
                  ],
                ),
              );
            });
      },
    );
  }
}
