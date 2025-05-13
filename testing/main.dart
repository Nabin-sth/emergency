import 'package:emergency/location_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;

  // Initialize the Socket.IO connection
  void initSocket() {
    socket = IO.io('http://192.168.16.101:10000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.onConnect((_) {
      print('Connected to Socket.IO server');
    });

    socket.onDisconnect((_) {
      print('Disconnected from Socket.IO server');
    });

    socket.onError((error) {
      print('Socket.IO error: $error');
    });
  }

  // Listen for real-time updates
  void listenForUpdates(Function(dynamic) onUpdate) {
    socket.on('getData', (data) {
      onUpdate(data);
    });
  }
  // void listenForLogs(Function(dynamic) onUpdate) {
  //   socket.on('getData', (data) {
  //     onUpdate(data);
  //   });
  // }

  // Disconnect the socket
  void disconnect() {
    socket.disconnect();
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GPS Location App',
      home: LocationScreen(),
    );
  }
}

class LocationScreen extends StatefulWidget {
  @override
  _LocationScreenState createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  double latitude = 37.7749;
  double longitude = -122.4194;
  bool isLoading = true;
  double zoomLevel = 5.0;
  final MapController _mapController = MapController();
  LatLng? userLocation;
  Position? _currentPosition;
  String lastFetchTime = 'Not fetched yet';
  List<Map<String, dynamic>> logs = [];

  final String apiUrl = 'http://192.168.16.101:10000/api/v1/gps-data';
  final String logsUrl = 'http://192.168.16.101:10000/api/v1/logs';
  Timer? timer;

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    fetchLocationData();
    // startPeriodicFetch();
    _getCurrentLocation();
    _initNotifications();
    fetchLogs(); // Fetch logs when the app starts
    // Initialize Socket.IO
    _socketService.initSocket();

    // Listen for real-time updates
    _socketService.listenForUpdates((data) {
      setState(() {
        latitude = double.parse(data['latitude']); // Convert string to double
        longitude = double.parse(data['longitude']); // Convert string to double
        lastFetchTime = DateTime.now().toString();
      });
      _mapController.move(LatLng(latitude, longitude), zoomLevel);
      Vibration.vibrate(duration: 500);
      _showNotification();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _socketService
        .disconnect(); // Disconnect the socket when the widget is disposed

    super.dispose();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'your_channel_id',
          'your_channel_name',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      'Location Updated',
      'New location fetched from the server.',
      platformChannelSpecifics,
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return Future.error('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return Future.error('Location permissions are permanently denied');
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        userLocation = LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  void startPeriodicFetch() {
    timer = Timer.periodic(Duration(seconds: 10), (Timer t) {
      print("fetched");
      fetchLocationData();
    });
  }

  Future<void> fetchLocationData() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          latitude = double.parse(data['latitude']);
          longitude = double.parse(data['longitude']);
          isLoading = false;
          lastFetchTime = DateTime.now().toString();
        });
        print(latitude);
        print(longitude);
        _mapController.move(LatLng(latitude, longitude), zoomLevel);
        Vibration.vibrate(duration: 500);
        _showNotification();
      } else {
        throw Exception('Failed to fetch data from API');
      }
    } catch (e) {
      print("Error while fetching data: ${e}");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchLogs() async {
    try {
      final response = await http.get(Uri.parse(logsUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print(data);
        setState(() {
          logs = data.map((log) => log as Map<String, dynamic>).toList();
        });
      } else {
        throw Exception('Failed to fetch logs from API');
      }
    } catch (e) {
      print("Error fetching logs: $e");
    }
  }

  void _zoomIn() {
    setState(() {
      zoomLevel = (zoomLevel + 1).clamp(3.0, 18.0);
      _mapController.move(_mapController.camera.center, zoomLevel);
    });
  }

  void _zoomOut() {
    setState(() {
      zoomLevel = (zoomLevel - 1).clamp(3.0, 18.0);
      _mapController.move(_mapController.camera.center, zoomLevel);
    });
  }

  void _navigateToLogsScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => LogsScreen(logs: logs)));
  }

  void navigateToWeatherScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) =>
                WeatherScreen(latitude: latitude, longitude: longitude),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS Location'),
        actions: [
          Hero(
            tag: 'refresh_button', // Unique tag
            child: IconButton(
              icon: Icon(Icons.refresh),
              onPressed: fetchLocationData,
            ),
          ),
          Hero(
            tag: 'history_button', // Unique tag
            child: IconButton(
              icon: Icon(Icons.history),
              onPressed: _navigateToLogsScreen,
            ),
          ),
          Hero(
            tag: 'weather_buttton', // Unique tag
            child: IconButton(
              icon: Icon(Icons.sunny),
              onPressed: navigateToWeatherScreen,
            ),
          ),
        ],
      ),
      body:
          isLoading
              ? Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(latitude, longitude),
                      initialZoom: zoomLevel,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                      interactionOptions: InteractionOptions(
                        flags:
                            InteractiveFlag.pinchZoom |
                            InteractiveFlag.drag |
                            InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(latitude, longitude),
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                          if (userLocation != null)
                            Marker(
                              point: userLocation!,
                              width: 80,
                              height: 80,
                              child: const Icon(
                                Icons.person_pin_circle,
                                size: 40,
                                color: Colors.blue,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  // Positioned(
                  //   bottom: 20,
                  //   right: 20,
                  //   child: Column(
                  //     children: [
                  //       Hero(
                  //         tag: "zoomIn",
                  //         child: FloatingActionButton(
                  //           onPressed: _zoomIn,
                  //           mini: true,
                  //           child: Icon(Icons.zoom_in),
                  //         ),
                  //       ),
                  //       SizedBox(height: 10),
                  //       Hero(
                  //         tag: "zoomOut",
                  //         child: FloatingActionButton(
                  //           onPressed: _zoomOut,
                  //           child: Icon(Icons.zoom_out),
                  //           mini: true,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Last Fetch: $lastFetchTime'),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}

class LogsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> logs;

  LogsScreen({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Incident History & Logs')),
      body: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          final time = DateTime.parse(log['createdAt']);
          final formattedTime = DateFormat('h:mm a, MMMM d, y').format(time);

          print(formattedTime);

          return ListTile(
            title: Text(
              'Latitude: ${log["latitude"]}, Longitude: ${log['longitude']}',
            ),
            subtitle: Text('Time: $formattedTime'),
          );
        },
      ),
    );
  }
}
