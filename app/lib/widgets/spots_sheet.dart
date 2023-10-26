import 'package:app/providers/spots_provider.dart';
import 'package:app/widgets/spot_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

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

  double previousDraggableScrollableSize = 0.33;
  String? previousSelectedSpotId;

  @override
  Widget build(BuildContext context) {
    return Selector<SpotsProvider, String?>(
        selector: (_, provider) => provider.selectedSpotId,
        builder: (context, selectedSpotId, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (selectedSpotId != null &&
                selectedSpotId != previousSelectedSpotId) {
              previousDraggableScrollableSize =
                  _draggableScrollableController.size;
              _draggableScrollableController.animateTo(
                0.33,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            } else if (selectedSpotId == null &&
                previousSelectedSpotId != null) {
              _draggableScrollableController.animateTo(
                previousDraggableScrollableSize,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
            previousSelectedSpotId = selectedSpotId;
          });
          return DraggableScrollableSheet(
            controller: _draggableScrollableController,
            initialChildSize: 0.33,
            minChildSize: 0.1,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [0.1, 0.33, 0.95],
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16.0),
                    topRight: Radius.circular(16.0),
                  ),
                ),
                child: Consumer<SpotsProvider>(
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
                      if (spots == null)
                        Container(
                          padding: const EdgeInsets.only(top: 30),
                          child: const Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center, // Center vertically
                            crossAxisAlignment: CrossAxisAlignment
                                .center, // Center horizontally
                            children: [
                              SpinKitWave(
                                color: Colors.white,
                                type: SpinKitWaveType.start,
                                duration: Duration(milliseconds: 1000),
                                size: 40,
                              ),
                              SizedBox(
                                height: 10,
                              ), // Add a small gap between spinner and text
                              Text(
                                'Finding your happy hours',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
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
