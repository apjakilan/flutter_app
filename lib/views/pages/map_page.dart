import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final title = 'Home Page';

  late GoogleMapController mapController;

  final LatLng _center = const LatLng(14.5995, 120.9842);

  void _onMapCreated(GoogleMapController controller)
  {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(onMapCreated: _onMapCreated,initialCameraPosition: CameraPosition(target:  _center, zoom: 11.0));
  }
}