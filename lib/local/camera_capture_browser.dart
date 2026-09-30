import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

Future<XFile?> captureBrowserMedia(BuildContext context, bool video) =>
    showDialog<XFile>(
      context: context,
      builder: (_) => _BrowserCamera(video: video),
    );

class _BrowserCamera extends StatefulWidget {
  const _BrowserCamera({required this.video});
  final bool video;

  @override
  State<_BrowserCamera> createState() => _BrowserCameraState();
}

class _BrowserCameraState extends State<_BrowserCamera> {
  web.HTMLVideoElement? preview;
  web.MediaStream? stream;
  web.MediaRecorder? recorder;
  final chunks = <web.Blob>[];
  Timer? timer;
  bool busy = false;
  bool recording = false;
  bool ready = false;
  bool includeAudio = true;
  int elapsed = 0;
  String? error;

  void stopTracks(web.MediaStream? value) {
    if (value == null) return;
    for (final track in value.getTracks().toDart) {
      track.stop();
    }
  }

  Future<void> startCamera() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!web.window.isSecureContext) {
        throw StateError(
          'Camera capture needs HTTPS or localhost. Open the secure admin address or upload from your gallery.',
        );
      }
      final captured = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              video: {
                'facingMode': {'ideal': 'environment'},
                'width': {'ideal': 1280},
                'height': {'ideal': 720},
              }.jsify()!,
              audio: (widget.video && includeAudio).toJS,
            ),
          )
          .toDart;
      if (!mounted) {
        stopTracks(captured);
        return;
      }
      stream = captured;
      preview!.srcObject = captured;
      await preview!.play().toDart;
      if (mounted) setState(() => ready = true);
    } catch (failure) {
      stopTracks(stream);
      stream = null;
      if (mounted) {
        final detail = '$failure';
        setState(
          () => error = detail.contains('HTTPS')
              ? 'Camera capture needs HTTPS or localhost. Open the secure admin address or upload from your gallery.'
              : 'Camera could not start. Allow camera${widget.video && includeAudio ? ' and microphone' : ''} access in browser settings, check that a camera is connected, then retry or use the gallery.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void takePhoto() {
    final element = preview;
    if (!ready || element == null || element.videoWidth == 0) return;
    try {
      final canvas = web.HTMLCanvasElement()
        ..width = element.videoWidth
        ..height = element.videoHeight;
      final context2d = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      context2d.drawImage(element, 0, 0);
      final data = canvas.toDataURL('image/jpeg', 0.75.toJS);
      Navigator.pop(
        context,
        XFile.fromData(
          base64Decode(data.substring(data.indexOf(',') + 1)),
          name: 'incident-${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        ),
      );
    } catch (_) {
      setState(
        () => error =
            'The photo could not be captured. Retry or upload from your gallery.',
      );
    }
  }

  void startRecording() {
    if (!ready || stream == null || recording || busy) return;
    try {
      final mime = [
        'video/webm;codecs=vp8,opus',
        'video/webm',
        'video/mp4',
      ].where((type) => web.MediaRecorder.isTypeSupported(type)).firstOrNull;
      if (mime == null) {
        setState(
          () => error =
              'Video recording is unavailable in this browser. Use Video from gallery instead.',
        );
        return;
      }
      chunks.clear();
      final capture = web.MediaRecorder(
        stream!,
        web.MediaRecorderOptions(
          mimeType: mime,
          videoBitsPerSecond: 700000,
          audioBitsPerSecond: 48000,
        ),
      );
      recorder = capture;
      capture.ondataavailable = ((web.Event event) {
        final blob = (event as web.BlobEvent).data;
        if (blob.size > 0) chunks.add(blob);
      }).toJS;
      capture.onstop = ((web.Event _) {
        if (mounted) unawaited(finishRecording());
      }).toJS;
      capture.onerror = ((web.Event _) {
        timer?.cancel();
        // An errored recording must never be attached by a later stop event.
        capture.onstop = null;
        capture.ondataavailable = null;
        chunks.clear();
        stopTracks(stream);
        if (mounted) {
          setState(() {
            recording = false;
            busy = false;
            ready = false;
            error =
                'Video recording failed. Close the camera and retry or upload from your gallery.';
          });
        }
      }).toJS;
      capture.start(1000);
      setState(() {
        elapsed = 0;
        error = null;
        recording = true;
      });
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => elapsed++);
        if (elapsed >= 15) stopRecording();
      });
    } catch (_) {
      setState(
        () => error =
            'Video recording is unavailable in this browser. Upload a video from your gallery.',
      );
    }
  }

  void stopRecording() {
    timer?.cancel();
    if (recorder?.state != 'recording') return;
    setState(() {
      recording = false;
      busy = true;
    });
    recorder!.stop();
  }

  Future<void> finishRecording() async {
    try {
      final mime = recorder!.mimeType.split(';').first;
      final blob = web.Blob(chunks.toJS, web.BlobPropertyBag(type: mime));
      if (blob.size == 0) throw StateError('No video recorded');
      final buffer = await blob.arrayBuffer().toDart;
      if (!mounted) return;
      Navigator.pop(
        context,
        XFile.fromData(
          buffer.toDart.asUint8List(),
          name:
              'incident-${DateTime.now().millisecondsSinceEpoch}.${mime == 'video/mp4' ? 'mp4' : 'webm'}',
          mimeType: mime,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error =
              'The video could not be saved. Record again or upload from your gallery.';
        });
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    if (recorder != null) {
      recorder!.onstop = null;
      recorder!.ondataavailable = null;
      recorder!.onerror = null;
      if (recorder!.state != 'inactive') recorder!.stop();
    }
    stopTracks(stream);
    preview?.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.video ? 'Record incident video' : 'Take incident photo'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HtmlElementView.fromTagName(
                      tagName: 'video',
                      onElementCreated: (element) {
                        preview = (element as web.HTMLVideoElement)
                          ..autoplay = true
                          ..muted = true
                          ..playsInline = true;
                        preview!.style
                          ..width = '100%'
                          ..height = '100%'
                          ..objectFit = 'contain'
                          ..pointerEvents = 'none';
                      },
                    ),
                    if (!ready)
                      const Center(
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              recording
                  ? 'Recording: $elapsed / 15 seconds'
                  : widget.video
                  ? 'Start the camera, then record up to 15 seconds. The video is attached to your report for review.'
                  : 'Start the camera and take a photo to attach to your report.',
            ),
            if (widget.video && !ready)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include microphone audio'),
                value: includeAudio,
                onChanged: busy
                    ? null
                    : (value) => setState(() => includeAudio = value),
              ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (!ready)
        FilledButton.icon(
          onPressed: busy ? null : startCamera,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Start camera'),
        )
      else if (!widget.video)
        FilledButton.icon(
          onPressed: takePhoto,
          icon: const Icon(Icons.camera),
          label: const Text('Capture photo'),
        )
      else
        FilledButton.icon(
          onPressed: busy
              ? null
              : recording
              ? stopRecording
              : startRecording,
          icon: Icon(recording ? Icons.stop : Icons.videocam_outlined),
          label: Text(
            busy
                ? 'Preparing video...'
                : recording
                ? 'Stop and attach video'
                : 'Start recording',
          ),
        ),
    ],
  );
}
