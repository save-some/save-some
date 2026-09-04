import 'package:flutter/material.dart';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    /*
    final token = dotenv.env['MAPBOX_TOKEN'];

    if (token == null) {
      throw Exception("MAPBOX_TOKEN not found in .env");
    }
    */

    const token = String.fromEnvironment('MAPBOX_TOKEN');
    MapboxOptions.setAccessToken(token);

    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    CameraOptions camera = CameraOptions(
      center: Point(coordinates: Position(-98.0, 39.5)),
      zoom: 2,
      bearing: 0,
      pitch: 0,
    );


    // Starting implementation here ...
    return Scaffold(
      body: MapWidget(
        cameraOptions: camera,
        onMapCreated: (mapboxMap) async {
          // await mapboxMap.location.
          mapboxMap.location.updateSettings(
            LocationComponentSettings(
              locationPuck: LocationPuck(
                // locationPuck2D: LocationPuck2D(),
                locationPuck3D: LocationPuck3D(
                  modelUri:
                      "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Embedded/Duck.gltf",
                ),
                
              ),
              enabled: true,
            ),
          );
    
        },
      ),
    );
  }
}
