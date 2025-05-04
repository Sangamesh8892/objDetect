import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:object_detection_realtime_flutter/features/object_detection/presentation/widgets/bounding_boxes.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'package:flutter_tts/flutter_tts.dart';

class RealTimeObjectDetection extends StatefulWidget {
  final List<CameraDescription> cameras;

  const RealTimeObjectDetection({super.key, required this.cameras});

  @override
  RealTimeObjectDetectionState createState() => RealTimeObjectDetectionState();
}

class RealTimeObjectDetectionState extends State<RealTimeObjectDetection> {
  late CameraController _controller;
  bool isModelLoaded = false;
  List<dynamic>? recognitions;
  int imageHeight = 0;
  int imageWidth = 0;

  // Speech related variables
  final FlutterTts flutterTts = FlutterTts();
  bool isSpeechEnabled = false;
  String lastSpokenObject = '';
  int _lastSpeechTime = 0;

  @override
  void initState() {
    super.initState();
    loadModel();
    initializeCamera(null);
    _initTts();
  }

  // Initialize text to speech
  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    flutterTts.stop();
    super.dispose();
  }

  // Speak the detected object name
  Future<void> _speakDetectedObject(String objectName) async {
    // Prevent speaking the same object repeatedly in a short time interval
    final now = DateTime.now().millisecondsSinceEpoch;
    if (objectName != lastSpokenObject || (now - _lastSpeechTime > 3000)) {
      await flutterTts.speak(objectName);
      lastSpokenObject = objectName;
      _lastSpeechTime = now;
    }
  }

  Future<void> loadModel() async {
    String? res = await Tflite.loadModel(
      model: 'assets/ssd_mobilenet.tflite',
      labels: 'assets/ssd_mobilenet.txt',
    );
    setState(() {
      isModelLoaded = res != null;
    });
  }

  void toggleCamera() {
    final lensDirection = _controller.description.lensDirection;
    CameraDescription newDescription;
    if (lensDirection == CameraLensDirection.front) {
      newDescription = widget.cameras.firstWhere((description) =>
          description.lensDirection == CameraLensDirection.back);
    } else {
      newDescription = widget.cameras.firstWhere((description) =>
          description.lensDirection == CameraLensDirection.front);
    }

    initializeCamera(newDescription);
  }

  void initializeCamera(description) async {
    if (description == null) {
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
    } else {
      _controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
    }

    await _controller.initialize();

    if (!mounted) {
      return;
    }
    _controller.startImageStream((CameraImage image) {
      if (isModelLoaded) {
        runModel(image);
      }
    });
    setState(() {});
  }

  void runModel(CameraImage image) async {
    if (image.planes.isEmpty) return;

    var recognitions = await Tflite.detectObjectOnFrame(
      bytesList: image.planes.map((plane) => plane.bytes).toList(),
      model: 'SSDMobileNet',
      imageHeight: image.height,
      imageWidth: image.width,
      imageMean: 127.5,
      imageStd: 127.5,
      numResultsPerClass: 1,
      threshold: 0.65,
    );

    setState(() {
      this.recognitions = recognitions;

      // Speak the detected object if speech is enabled and there are recognitions
      if (isSpeechEnabled && recognitions != null && recognitions.isNotEmpty) {
        final topDetection = recognitions[0];
        final detectedClass = topDetection['detectedClass'] as String;
        _speakDetectedObject(detectedClass);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Object Detection',
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height *
                0.75, // Adjusted to make room for controls
            child: Stack(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: CameraPreview(_controller),
                ),
                if (recognitions != null)
                  BoundingBoxes(
                    recognitions: recognitions!,
                    previewH: imageHeight.toDouble(),
                    previewW: imageWidth.toDouble(),
                    screenH: MediaQuery.of(context).size.height * 0.75,
                    screenW: MediaQuery.of(context).size.width,
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      toggleCamera();
                    },
                    icon: Icon(
                      _controller.description.lensDirection ==
                              CameraLensDirection.back
                          ? Icons.camera_front
                          : Icons.camera_rear,
                      size: 30,
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Speech Output',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: isSpeechEnabled,
                        onChanged: (value) {
                          setState(() {
                            isSpeechEnabled = value;
                          });
                        },
                        activeColor: Colors.deepPurple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
