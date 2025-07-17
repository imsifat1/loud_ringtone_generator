import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
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
  Set<int> downloading = {};
  Set<int> success = {};

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

    try {
      final response = await Dio().get(url);
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> data = json.decode(response.data.toString());
        setState(() {
          ringtones = data;
        });
      }
    } catch (e) {
      log("Failed to load ringtones: $e");

      // Show a friendly error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load ringtone list. Please check your internet or try again later.'),
          ),
        );
      }
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

  Future<void> downloadAndSetRingtone(String url, String fileName, int index) async {
    setState(() {
      downloading.add(index);
      success.remove(index);
    });

    final canWrite = await platform.invokeMethod<bool>('canWriteSettings');
    if (canWrite != true) {
      await openWriteSettingsPermission();
      setState(() => downloading.remove(index));
      return;
    }

    final status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      final requestResult = await Permission.manageExternalStorage.request();
      if (!requestResult.isGranted) {
        setState(() => downloading.remove(index));
        return;
      }
    }

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

    setState(() {
      downloading.remove(index);
      if (result == true) success.add(index);
    });
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
          if(ringtones.isEmpty) return const Center(child: Text('No ringtone found'));
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
                    icon: downloading.contains(index)
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Icon(
                      success.contains(index)
                          ? Icons.check_circle
                          : Icons.download_rounded,
                      color: success.contains(index) ? Colors.blue : Colors.green,
                    ),
                    onPressed: downloading.contains(index)
                        ? null
                        : () => downloadAndSetRingtone(item['url'], '${item['title']}.mp3', index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> openWriteSettingsPermission() async {
    const platform = MethodChannel('com.example.set_ringtone');
    await platform.invokeMethod('openWriteSettings');
  }
}