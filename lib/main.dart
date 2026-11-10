// Identity: Ayla Nur Ramadhani (NIM: 253307006)
// Tugas Pertemuan 2 - State, Stream & Firebase Integration

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SmartMonitorApp());
}

class SmartMonitorApp extends StatelessWidget {
  const SmartMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Monitor',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
      ),
      home: const DashboardPage(),
    );
  }
}

class DataSensor {
  final double suhu;
  final double kelembapan;

  DataSensor({required this.suhu, required this.kelembapan});

  factory DataSensor.fromMap(Map data) {
    return DataSensor(
      suhu: (data['suhu'] as num).toDouble(),
      kelembapan: (data['kelembapan'] as num).toDouble(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final DatabaseReference _ref =
      FirebaseDatabase.instance.ref('devices/esp32_01');

  late final Stream<DatabaseEvent> _sensorStream = _ref.child('sensor').onValue;
  late final Stream<DatabaseEvent> _ledStream = _ref.child('control/led').onValue;
  late final Stream<DatabaseEvent> _kipasStream = _ref.child('control/kipas').onValue;
  late final Stream<DatabaseEvent> _batasSuhuStream = _ref.child('control/batasSuhu').onValue;

  // Helper penulisan Firebase dengan Timeout 3 detik & SnackBar Error
  Future<void> _setControlValue(String path, dynamic value) async {
    try {
      await _ref.child('control/$path').set(value).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Koneksi terputus / Timeout.');
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui $path: Tidak ada koneksi internet!'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Monitor IoT'),
        centerTitle: true,
        actions: [
          // Navigasi ke Halaman Tentang Perangkat via Constructor
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HalamanTentangPerangkat(
                    namaPerangkat: 'ESP32',
                    deviceId: 'esp32_01',
                    lokasi: 'Laboratorium - PNM',
                    mahasiswa: 'Ayla Nur Ramadhani',
                    nim: '253307006',
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Kartu Identitas Mahasiswa
          Card(
            color: Colors.teal.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.teal.shade200),
            ),
            child: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.teal,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mahasiswa: Ayla Nur Ramadhani',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'NIM: 253307006',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stream Batas Suhu & Data Sensor
          StreamBuilder<DatabaseEvent>(
            stream: _batasSuhuStream,
            builder: (context, snapshotBatas) {
              final double batasSuhu =
                  (snapshotBatas.data?.snapshot.value as num?)?.toDouble() ?? 30.0;

              return StreamBuilder<DatabaseEvent>(
                stream: _sensorStream,
                builder: (context, snapshotSensor) {
                  if (snapshotSensor.hasError) {
                    return Text('Error: ${snapshotSensor.error}');
                  }
                  final value = snapshotSensor.data?.snapshot.value;
                  final data = value is Map ? DataSensor.fromMap(value) : null;

                  return Column(
                    children: [
                      KartuSensor(
                        ikon: Icons.thermostat,
                        label: 'Suhu',
                        nilai: data?.suhu,
                        satuan: '°C',
                        isTemperature: true,
                        batasSuhu: batasSuhu,
                      ),
                      const SizedBox(height: 8),
                      KartuSensor(
                        ikon: Icons.water_drop,
                        label: 'Kelembapan',
                        nilai: data?.kelembapan,
                        satuan: '%',
                        isTemperature: false,
                        batasSuhu: batasSuhu,
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),

          // Control LED
          StreamBuilder<DatabaseEvent>(
            stream: _ledStream,
            builder: (context, snapshot) {
              final bool isLedOn = snapshot.data?.snapshot.value == true;
              return Card(
                child: SwitchListTile(
                  secondary: Icon(
                    Icons.lightbulb,
                    color: isLedOn ? Colors.amber : Colors.grey,
                  ),
                  title: const Text('Lampu LED'),
                  subtitle: Text(isLedOn ? 'Status: Menyala' : 'Status: Mati'),
                  value: isLedOn,
                  onChanged: (val) => _setControlValue('led', val),
                ),
              );
            },
          ),

          // Control Kipas
          StreamBuilder<DatabaseEvent>(
            stream: _kipasStream,
            builder: (context, snapshot) {
              final bool isKipasOn = snapshot.data?.snapshot.value == true;
              return Card(
                child: SwitchListTile(
                  secondary: Icon(
                    Icons.air_rounded,
                    color: isKipasOn ? Colors.blue : Colors.grey,
                  ),
                  title: const Text('Kipas Pendingin'),
                  subtitle: Text(isKipasOn ? 'Status: Menyala' : 'Status: Mati'),
                  value: isKipasOn,
                  onChanged: (val) => _setControlValue('kipas', val),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            label: const Text('Pengaturan Alarm'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HalamanKontrol(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class KartuSensor extends StatelessWidget {
  final IconData ikon;
  final String label;
  final double? nilai;
  final String satuan;
  final bool isTemperature;
  final double batasSuhu;

  const KartuSensor({
    super.key,
    required this.ikon,
    required this.label,
    required this.nilai,
    required this.satuan,
    this.isTemperature = false,
    this.batasSuhu = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    // Penentuan status panas berdasarkan batasSuhu dinamis dari Firebase
    final bool isPanas = isTemperature && (nilai != null && nilai! > batasSuhu);

    return Card(
      color: isPanas ? Colors.red.shade50 : null,
      shape: isPanas
          ? RoundedRectangleBorder(
              side: const BorderSide(color: Colors.red, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: ListTile(
        leading: Icon(
          ikon,
          color: isPanas ? Colors.red : Theme.of(context).primaryColor,
        ),
        title: Row(
          children: [
            Text(label),
            if (isPanas) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Panas (>${batasSuhu.toStringAsFixed(0)}°C)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ]
          ],
        ),
        trailing: nilai == null
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                '${nilai!.toStringAsFixed(1)}$satuan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isPanas ? Colors.red : Colors.black87,
                ),
              ),
      ),
    );
  }
}

class HalamanKontrol extends StatefulWidget {
  const HalamanKontrol({super.key});

  @override
  State<HalamanKontrol> createState() => _HalamanKontrolState();
}

class _HalamanKontrolState extends State<HalamanKontrol> {
  final DatabaseReference _refBatasSuhu =
      FirebaseDatabase.instance.ref('devices/esp32_01/control/batasSuhu');
  double _batasSuhu = 30;

  @override
  void initState() {
    super.initState();
    _refBatasSuhu.get().then((snapshot) {
      if (snapshot.exists && snapshot.value != null) {
        setState(() {
          _batasSuhu = (snapshot.value as num).toDouble();
        });
      }
    });
  }

  Future<void> _simpanBatasSuhu(double val) async {
    try {
      await _refBatasSuhu.set(val).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Timeout menyimpan batas suhu');
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan batas suhu: Perangkat Offline!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Alarm Suhu')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batas Suhu Alarm: ${_batasSuhu.toStringAsFixed(0)} °C',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _batasSuhu,
              min: 20,
              max: 40,
              divisions: 20,
              label: _batasSuhu.toStringAsFixed(0),
              onChanged: (v) => setState(() => _batasSuhu = v),
              onChangeEnd: (v) => _simpanBatasSuhu(v),
            ),
          ],
        ),
      ),
    );
  }
}

// Halaman Tentang Perangkat (Tugas 3 Opsional)
class HalamanTentangPerangkat extends StatelessWidget {
  final String namaPerangkat;
  final String deviceId;
  final String lokasi;
  final String mahasiswa;
  final String nim;

  const HalamanTentangPerangkat({
    super.key,
    required this.namaPerangkat,
    required this.deviceId,
    required this.lokasi,
    required this.mahasiswa,
    required this.nim,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang Perangkat')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: ListTile(
              title: const Text('Nama Perangkat'),
              subtitle: Text(namaPerangkat),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Device ID'),
              subtitle: Text(deviceId),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Lokasi Deployment'),
              subtitle: Text(lokasi),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Mahasiswa'),
              subtitle: Text('$mahasiswa ($nim)'),
            ),
          ),
        ],
      ),
    );
  }
}
