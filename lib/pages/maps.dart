import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:smarthome/components/mapkey.dart';
//import 'package:smarthome/main.dart';

class MapPage extends StatefulWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  const MapPage({super.key, required this.flutterLocalNotificationsPlugin});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Location _locationController = Location();
  final Completer<GoogleMapController> _mapController =
      Completer<GoogleMapController>();
  final LatLng _kigaliCenter = const LatLng(-1.9927888144909813, 30.06829847347846);
  static const LatLng _pGooglePlex =
      LatLng(-1.9927888144909813, 30.06829847347846);
  static const LatLng _pApplePark =
      LatLng(-1.9927888144909813, 30.06829847347846);
  LatLng? _currentP;
  Map<PolylineId, Polyline> polylines = {};
  final Map<PolygonId, Polygon> _polygons = {};
  StreamSubscription<LocationData>? _locationSubscription;
  bool _notificationSentOutSide = false;
  bool _notificationSentInSide = false;

  @override
  void initState() {
    super.initState();
    getLocationUpdates().then(
      (_) => {
        getPolylinePoints().then((coordinates) => {
              generatePolyLineFromPoints(coordinates),
            }),
      },
    );
    _createGeofence();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.hintColor,
        title: Text(
          'Your Location',
          style: TextStyle(color: theme.primaryColor),
        ),
        iconTheme: IconThemeData(
          color: theme.primaryColor,
        ),
      ),
      body: _currentP == null
          ? const Center(
              child: Text("Loading..."),
            )
          : GoogleMap(
              onMapCreated: ((GoogleMapController controller) =>
                  _mapController.complete(controller)),
              initialCameraPosition: CameraPosition(
                target: _kigaliCenter,
                zoom: 13,
              ),
              polygons: Set<Polygon>.of(_polygons.values),
              markers: {
                Marker(
                  markerId: const MarkerId("_currentLocation"),
                  icon: BitmapDescriptor.defaultMarker,
                  position: _currentP!,
                ),
                const Marker(
                    markerId: MarkerId("_sourceLocation"),
                    icon: BitmapDescriptor.defaultMarker,
                    position: _pGooglePlex),
                const Marker(
                    markerId: MarkerId("_destionationLocation"),
                    icon: BitmapDescriptor.defaultMarker,
                    position: _pApplePark)
              },
              polylines: Set<Polyline>.of(polylines.values),
            ),
    );
  }

  void _triggerInSideNotification() async {
    if (!_notificationSentInSide) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'Map_channel',
        'Map Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      await widget.flutterLocalNotificationsPlugin.show(
        0,
        'Hello!',
        'Inside Geographical Boundaries of Kigali',
        platformChannelSpecifics,
      );
      print('Inside geofence notification sent');
      _notificationSentInSide = true;
      _notificationSentOutSide = false;
    }
  }

  void _triggerOutSideNotification() async {
    if (!_notificationSentOutSide) {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'Map_channel',
        'Map Notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);
      await widget.flutterLocalNotificationsPlugin.show(
        0,
        'Hello!',
        'Outside Geographical Boundaries of Kigali',
        platformChannelSpecifics,
      );
      print('Outside geofence notification sent');
      _notificationSentOutSide = true;
      _notificationSentInSide = false;
    }
  }

  void _createGeofence() {
    List<LatLng> kigaliBoundaries = [
      const LatLng(-1.9927888144909813, 30.06829847347846),
      const LatLng(-1.9927888144909813, 30.06829847347846),
      const LatLng(-1.9927888144909813, 30.06829847347846),
      const LatLng(-1.9927888144909813, 30.06829847347846),
    ];

    PolygonId polygonId = const PolygonId('kigali');
    Polygon polygon = Polygon(
      polygonId: polygonId,
      points: kigaliBoundaries,
      strokeWidth: 2,
      strokeColor: Colors.blue,
      fillColor: Colors.blue.withOpacity(0.3),
    );

    setState(() {
      _polygons[polygonId] = polygon;
    });

    _startLocationUpdates();
  }

  void _startLocationUpdates() async {
    _locationSubscription = _locationController.onLocationChanged
        .listen((LocationData currentLocation) {
      bool insideGeofence = _isLocationInsideGeofence(
          currentLocation.latitude!, currentLocation.longitude!);

      if (insideGeofence && !_notificationSentInSide) {
        _triggerInSideNotification();
        _notificationSentInSide = true;
        _notificationSentOutSide = false;
      } else if (!insideGeofence && !_notificationSentOutSide) {
        _triggerOutSideNotification();
        _notificationSentOutSide = true;
        _notificationSentInSide = false;
      }
    });
  }

  bool _isLocationInsideGeofence(double latitude, double longitude) {
    bool isInside = false;
    List<LatLng> kigaliBoundaries = [
      const LatLng(-1.9927888144909813, 30.06829847347846),
      const LatLng(-1.9927888144909813, 30.06829847347846),
      const LatLng(-1.9927888144909813, 30.06829847347846),
      const LatLng(-1.9927888144909813, 30.06829847347846),
    ];

    int i, j = kigaliBoundaries.length - 1;
    for (i = 0; i < kigaliBoundaries.length; i++) {
      if ((kigaliBoundaries[i].latitude < latitude &&
                  kigaliBoundaries[j].latitude >= latitude ||
              kigaliBoundaries[j].latitude < latitude &&
                  kigaliBoundaries[i].latitude >= latitude) &&
          (kigaliBoundaries[i].longitude <= longitude ||
              kigaliBoundaries[j].longitude <= longitude)) {
        if (kigaliBoundaries[i].longitude +
                (latitude - kigaliBoundaries[i].latitude) /
                    (kigaliBoundaries[j].latitude -
                        kigaliBoundaries[i].latitude) *
                    (kigaliBoundaries[j].longitude -
                        kigaliBoundaries[i].longitude) <
            longitude) {
          isInside = !isInside;
        }
      }
      j = i;
    }
    return isInside;
  }

  Future<void> _cameraToPosition(LatLng pos) async {
    final GoogleMapController controller = await _mapController.future;
    CameraPosition newCameraPosition = CameraPosition(
      target: pos,
      zoom: 13,
    );
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(newCameraPosition),
    );
  }

  Future<void> getLocationUpdates() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _locationController.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationController.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _locationController.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationController.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationSubscription = _locationController.onLocationChanged
        .listen((LocationData currentLocation) {
      if (currentLocation.latitude != null &&
          currentLocation.longitude != null) {
        LatLng newLocation =
            LatLng(currentLocation.latitude!, currentLocation.longitude!);

        updateMarkerAndCircle(newLocation);

        addLocationToPolyline(newLocation);

        _cameraToPosition(newLocation);
      }
    });
  }

  void updateMarkerAndCircle(LatLng newLocation) {
    setState(() {
      _currentP = newLocation;
    });
  }

  void addLocationToPolyline(LatLng newLocation) {
    setState(() {
      if (polylines.containsKey(const PolylineId("path"))) {
        final polyline = polylines[const PolylineId("path")]!;
        final updatedPoints = List<LatLng>.from(polyline.points)
          ..add(newLocation);
        polylines[const PolylineId("path")] =
            polyline.copyWith(pointsParam: updatedPoints);
      } else {
        polylines[const PolylineId("path")] = Polyline(
          polylineId: const PolylineId("path"),
          color: Colors.blue,
          points: [newLocation],
          width: 5,
        );
      }
    });
  }

  Future<List<LatLng>> getPolylinePoints() async {
    List<LatLng> polylineCoordinates = [];
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      GOOGLE_MAPS_API_KEY,
      PointLatLng(_pGooglePlex.latitude, _pGooglePlex.longitude),
      PointLatLng(_pApplePark.latitude, _pApplePark.longitude),
      travelMode: TravelMode.driving,
    );
    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    } else {
      print(result.errorMessage);
    }
    return polylineCoordinates;
  }

  void generatePolyLineFromPoints(List<LatLng> polylineCoordinates) async {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
        polylineId: id,
        color: Colors.black,
        points: polylineCoordinates,
        width: 8);
    setState(() {
      polylines[id] = polyline;
    });
  }
}
