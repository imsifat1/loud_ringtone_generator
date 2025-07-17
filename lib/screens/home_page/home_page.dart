import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> ringtones = [];
  final AudioPlayer _player = AudioPlayer();
  int? currentlyPlayingIndex;
  static const platform = MethodChannel('com.example.set_ringtone');

  @override
  void initState() {
    super.initState();
    fetchRingtones();
    _player.onPlayerComplete.listen((event) {
      setState(() {
        currentlyPlayingIndex = null;
      });
    });
  }

  Future<void> fetchRingtones() async {
    const url = 'https://raw.githubusercontent.com/imsifat1/ringtones/main/ringtone_list.json';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      setState(() {
        ringtones = json.decode(response.body);
      });
    }
  }

  void playSound(String url, int index) async {
    if (currentlyPlayingIndex == index) {
      await _player.stop();
      setState(() {
        currentlyPlayingIndex = null;
      });
    } else {
      await _player.stop();
      await _player.play(UrlSource(url));
      setState(() {
        currentlyPlayingIndex = index;
      });
    }
  }

  Future<void> downloadAndSetRingtone(String url, String fileName) async {
    final status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) return;

    Directory? dir = await getExternalStorageDirectory();
    if (dir == null) return;

    final ringtoneDir = Directory('/storage/emulated/0/Ringtones');
    if (!ringtoneDir.existsSync()) {
      ringtoneDir.createSync(recursive: true);
    }

    final savePath = '${ringtoneDir.path}/$fileName';
    await Dio().download(url, savePath);

    final result = await platform.invokeMethod('setRingtone', {'filePath': savePath});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result == true ? 'Ringtone set!' : 'Failed to set ringtone'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loud Ringtone Generator')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: ringtones.length,
        itemBuilder: (context, index) {
          final item = ringtones[index];
          final isPlaying = index == currentlyPlayingIndex;
          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle,
                        size: 30, color: Colors.deepOrange),
                    onPressed: () => playSound(item['url'], index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.green),
                    onPressed: () => downloadAndSetRingtone(item['url'], '${item['title']}.mp3'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}