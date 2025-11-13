import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(const RagaQuizApp());

class RagaQuizApp extends StatelessWidget {
  const RagaQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raga Quiz',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const LevelSelectionScreen(),
    );
  }
}

class Raga {
  final String name;
  final String type;
  final int? melakarta;
  final String arohanam;
  final String avarohanam;
  final String audioArohanam;
  final String audioAvarohanam;

  Raga({
    required this.name,
    required this.type,
    this.melakarta,
    required this.arohanam,
    required this.avarohanam,
    required this.audioArohanam,
    required this.audioAvarohanam,
  });

  factory Raga.fromJson(Map<String, dynamic> json) => Raga(
        name: json['name'],
        type: json['type'],
        melakarta: json['melakarta'],
        arohanam: json['arohanam'],
        avarohanam: json['avarohanam'],
        audioArohanam: json['audio_arohanam'],
        audioAvarohanam: json['audio_avarohanam'],
      );
}

class LevelSelectionScreen extends StatelessWidget {
  const LevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Choose Level")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.music_note),
              label: const Text("Melakartha Ragas"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(level: "Melakartha"),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.library_music),
              label: const Text("Janya Ragas"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizScreen(level: "Janya"),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String level;
  const QuizScreen({super.key, required this.level});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Raga> allRagas = [];
  List<Raga> quizRagas = [];
  Raga? currentRaga;
  List<String> options = [];
  final AudioPlayer _player = AudioPlayer();
  int score = 0;
  bool showInfo = false;
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    loadRagas();
  }

  Future<void> loadRagas() async {
    final data = await rootBundle.loadString('assets/ragas.json');
    final jsonResult = json.decode(data);
    final List<Raga> loadedRagas =
        (jsonResult['ragas'] as List).map((e) => Raga.fromJson(e)).toList();

    setState(() {
      allRagas = loadedRagas;
      quizRagas = loadedRagas
          .where((r) => r.type == widget.level)
          .toList();
    });
    generateQuestion();
  }

  void generateQuestion() {
    setState(() {
      showInfo = false;
      isPlaying = false;
    });
    if (quizRagas.isEmpty) return;
    quizRagas.shuffle();
    final selected = quizRagas.first;
    final wrongOptions = quizRagas
        .where((r) => r.name != selected.name)
        .take(3)
        .map((r) => r.name)
        .toList();
    options = [...wrongOptions, selected.name]..shuffle();
    currentRaga = selected;
  }

  Future<void> playRagaSequence() async {
    if (isPlaying || currentRaga == null) return;

    setState(() => isPlaying = true);

    final arohanamPath = 'audio/${currentRaga!.audioArohanam}';
    final avarohanamPath = 'audio/${currentRaga!.audioAvarohanam}';

    try {
      await _player.play(AssetSource(arohanamPath));
      // wait for clip to play (clips are short)
      await Future.delayed(const Duration(milliseconds: 1700));
      await _player.stop();

      await Future.delayed(const Duration(milliseconds: 350)); // short pause
      await _player.play(AssetSource(avarohanamPath));
      await Future.delayed(const Duration(milliseconds: 1700));
      await _player.stop();
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }

    setState(() => isPlaying = false);
  }

  void checkAnswer(String ans) {
    final correct = ans == currentRaga!.name;
    setState(() {
      if (correct) score++;
      showInfo = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            correct ? '✅ Correct! ${currentRaga!.name}' : '❌ Wrong! It was ${currentRaga!.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentRaga == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.level} Quiz"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(child: Text("Score: $score")),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: isPlaying
                  ? const Icon(Icons.pause_circle_filled)
                  : const Icon(Icons.play_circle_fill),
              label: Text(isPlaying ? "Playing..." : "Play Raga"),
              onPressed: playRagaSequence,
            ),
            const SizedBox(height: 25),
            ...options.map((opt) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: ElevatedButton(
                    onPressed: () => checkAnswer(opt),
                    child: Text(opt),
                  ),
                )),
            const SizedBox(height: 20),
            if (showInfo) ragaInfoCard(currentRaga!),
            const SizedBox(height: 10),
            if (showInfo)
              OutlinedButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: const Text("Next Question"),
                onPressed: generateQuestion,
              ),
          ],
        ),
      ),
    );
  }

  Widget ragaInfoCard(Raga raga) {
    return Card(
      elevation: 3,
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(raga.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Type: ${raga.type}"),
            if (raga.melakarta != null)
              Text("Melakartha No: ${raga.melakarta}"),
            const SizedBox(height: 4),
            Text("Ārōhaṇam: ${raga.arohanam}"),
            Text("Avarōhaṇam: ${raga.avarohanam}"),
          ],
        ),
      ),
    );
  }
}
