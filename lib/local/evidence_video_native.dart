import 'dart:io';
import 'dart:typed_data';
import 'package:video_player/video_player.dart';

VideoPlayerController attachmentVideoController(
  String path,
  Uint8List bytes,
  String mime,
) => VideoPlayerController.file(File(path));
