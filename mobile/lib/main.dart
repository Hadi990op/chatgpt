import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');

void main() {
  runApp(const RickshawPulseApp());
}

class RickshawPulseApp extends StatelessWidget {
  const RickshawPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rickshaw Pulse',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rickshaw Pulse')),
      body: tab == 0 ? const TravelerScreen() : const DriverScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.route), label: 'Traveler'),
          NavigationDestination(icon: Icon(Icons.drive_eta), label: 'Driver'),
        ],
      ),
    );
  }
}

class TravelerScreen extends StatefulWidget {
  const TravelerScreen({super.key});

  @override
  State<TravelerScreen> createState() => _TravelerScreenState();
}

class _TravelerScreenState extends State<TravelerScreen> {
  final startController = TextEditingController();
  final endController = TextEditingController();
  LatLng? start;
  LatLng? end;
  String availability = '-';
  String eta = '-';
  List<dynamic> saved = [];
  List<dynamic> history = [];
  final travelerId = 'guest-traveler';

  Future<List<dynamic>> _search(String q) async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/geo/search?q=$q'));
    return jsonDecode(res.body) as List<dynamic>;
  }

  Future<void> _pickPoint(bool isStart) async {
    final c = isStart ? startController : endController;
    final results = await _search(c.text);
    if (!mounted || results.isEmpty) return;
    final first = results.first;
    setState(() {
      final point = LatLng(double.parse(first['lat']), double.parse(first['lon']));
      if (isStart) {
        start = point;
      } else {
        end = point;
      }
      c.text = first['display_name'];
    });
  }

  Future<void> checkAvailability() async {
    if (start == null || end == null) return;
    final nowHour = TimeOfDay.now().hour;
    final uri = Uri.parse(
      '$apiBaseUrl/api/availability?startLat=${start!.latitude}&startLon=${start!.longitude}&endLat=${end!.latitude}&endLon=${end!.longitude}&hour=$nowHour',
    );
    final res = await http.get(uri);
    final data = jsonDecode(res.body);
    setState(() {
      availability = data['availability'];
      final candidates = data['candidates'] as List<dynamic>;
      eta = candidates.isNotEmpty
          ? '${candidates.first['eta']['min']}-${candidates.first['eta']['max']} min'
          : 'No active rickshaw nearby';
    });
    await loadHistory();
  }

  Future<void> saveRoute() async {
    if (start == null || end == null) return;
    await http.post(
      Uri.parse('$apiBaseUrl/api/routes/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'travelerId': travelerId,
        'title': 'Daily route',
        'startLat': start!.latitude,
        'startLon': start!.longitude,
        'endLat': end!.latitude,
        'endLon': end!.longitude,
      }),
    );
    await loadSaved();
  }

  Future<void> loadSaved() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/routes/saved/$travelerId'));
    setState(() => saved = jsonDecode(res.body));
  }

  Future<void> loadHistory() async {
    if (start == null || end == null) return;
    final uri = Uri.parse(
      '$apiBaseUrl/api/history?startLat=${start!.latitude}&startLon=${start!.longitude}&endLat=${end!.latitude}&endLon=${end!.longitude}',
    );
    final res = await http.get(uri);
    setState(() => history = (jsonDecode(res.body)['history'] ?? []) as List<dynamic>);
  }

  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    final points = [if (start != null) start!, if (end != null) end!];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        TextField(controller: startController, decoration: const InputDecoration(labelText: 'Start location')),
        ElevatedButton(onPressed: () => _pickPoint(true), child: const Text('Set start from OSM/Nominatim')),
        TextField(controller: endController, decoration: const InputDecoration(labelText: 'End location')),
        ElevatedButton(onPressed: () => _pickPoint(false), child: const Text('Set end from OSM/Nominatim')),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: checkAvailability, child: const Text('Check availability now')),
        OutlinedButton(onPressed: saveRoute, child: const Text('Save daily route')),
        Card(
          child: ListTile(
            title: Text('Availability: $availability'),
            subtitle: Text('Approx ETA: $eta'),
          ),
        ),
        SizedBox(
          height: 220,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: start ?? const LatLng(23.7806, 90.4070),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'community.rickshaw.pulse',
              ),
              if (points.isNotEmpty)
                MarkerLayer(
                  markers: points
                      .map((p) => Marker(
                            point: p,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_on, color: Colors.red),
                          ))
                      .toList(),
                ),
              if (start != null && end != null)
                PolylineLayer(
                  polylines: [
                    Polyline(points: [start!, end!], color: Colors.blue, strokeWidth: 4),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('Saved routes'),
        ...saved.map((r) => ListTile(title: Text(r['title']), subtitle: Text(r['route']))),
        const Divider(),
        const Text('Availability history'),
        ...history.map((h) => ListTile(title: Text('Hour ${h['hour']}'), subtitle: Text('${h['label']} (${h['reports']} reports)'))),
      ],
    );
  }
}

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final vehicleController = TextEditingController();
  final routeController = TextEditingController();
  String? driverId;
  bool active = false;

  Future<void> login() async {
    final prefs = await SharedPreferences.getInstance();
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/drivers/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': nameController.text,
        'phone': phoneController.text,
        'vehicleNo': vehicleController.text,
      }),
    );
    final data = jsonDecode(res.body);
    setState(() => driverId = data['driverId']);
    await prefs.setString('driverId', driverId!);
  }

  Future<void> toggleStatus(bool value) async {
    if (driverId == null) return;
    setState(() => active = value);
    await http.post(
      Uri.parse('$apiBaseUrl/api/drivers/$driverId/status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'active': active,
        'lat': 23.780 + (active ? 0.005 : 0),
        'lon': 90.407 + (active ? 0.005 : 0),
        'route': routeController.text,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Simple driver login (no complex onboarding)'),
        TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone')),
        TextField(controller: vehicleController, decoration: const InputDecoration(labelText: 'Vehicle no (optional)')),
        TextField(controller: routeController, decoration: const InputDecoration(labelText: 'Route key (auto from traveler result)')),
        ElevatedButton(onPressed: login, child: const Text('Login as driver')),
        SwitchListTile(
          title: const Text('I am active on this route now'),
          subtitle: const Text('Only rough location shared while active'),
          value: active,
          onChanged: driverId == null ? null : toggleStatus,
        ),
        if (driverId != null) Text('Logged in driver id: $driverId'),
      ],
    );
  }
}
