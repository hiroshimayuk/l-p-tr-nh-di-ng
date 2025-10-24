import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/vocab.dart';

class FlashcardPage extends StatefulWidget {
  final List<Vocab> all;
  const FlashcardPage({super.key, required this.all});
  @override
  State<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends State<FlashcardPage> {
  late List<Vocab> _cards;
  int _index = 0;
  bool _showBack = false;
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  bool _autoplay = false;

  @override
  void initState() {
    super.initState();
    _cards = List.from(widget.all);
    _cards.shuffle();
    _initTts();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.45);
      _tts.setStartHandler(() {
        if (mounted) setState(() => _speaking = true);
      });
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      _tts.setCancelHandler(() {
        if (mounted) setState(() => _speaking = false);
      });
      _tts.setErrorHandler((msg) {
        if (mounted) setState(() => _speaking = false);
      });
    } catch (_) {
      // ignore init errors; TTS may be unavailable on some emulators
    }
  }

  void _next() => setState(() {
    if (_cards.isEmpty) return;
    _index = (_index + 1) % _cards.length;
    _showBack = false;
    if (_autoplay) _speakEnCurrent();
  });

  void _prev() => setState(() {
    if (_cards.isEmpty) return;
    _index = (_index - 1 + _cards.length) % _cards.length;
    _showBack = false;
    if (_autoplay) _speakEnCurrent();
  });

  void _flip() {
    setState(() {
      _showBack = !_showBack;
      if (_showBack && _autoplay) _speakEnCurrent();
    });
  }

  Future<void> _speakEnCurrent() async {
    if (_cards.isEmpty) return;
    final text = _cards[_index].en;
    if (text.isEmpty) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.speak(text);
    } catch (_) {
      try {
        await _tts.speak(text);
      } catch (_) {}
    }
  }

  Future<void> _stopSpeak() async {
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _speaking = false);
  }

  void _toggleAutoplay() {
    setState(() {
      _autoplay = !_autoplay;
      if (_autoplay) _speakEnCurrent();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcards')),
        body: const Center(child: Text('Không có thẻ')),
      );
    }

    final card = _cards[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcards ${_index + 1}/${_cards.length}'),
        actions: [
          IconButton(
            icon: Icon(_autoplay ? Icons.play_circle_fill : Icons.play_circle_outline),
            tooltip: _autoplay ? 'Autoplay on' : 'Autoplay off',
            onPressed: _toggleAutoplay,
          ),
          IconButton(
            icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
            tooltip: _speaking ? 'Stop' : 'Play pronunciation',
            onPressed: _speaking ? _stopSpeak : _speakEnCurrent,
          ),
        ],
      ),
      body: Center(
        child: GestureDetector(
          onTap: _flip,
          child: Card(
            elevation: 6,
            margin: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              height: 360,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showBack ? card.vi : card.en,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (!_showBack)
                    TextButton.icon(
                      onPressed: _speakEnCurrent,
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Phát âm EN'),
                    )
                  else
                    TextButton.icon(
                      onPressed: () async {
                        try {
                          await _tts.setLanguage('vi-VN');
                          await _tts.speak(card.vi);
                        } catch (_) {
                          try {
                            await _tts.speak(card.vi);
                          } catch (_) {}
                        }
                      },
                      icon: const Icon(Icons.record_voice_over),
                      label: const Text('Phát âm VI'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(onPressed: _prev, icon: const Icon(Icons.arrow_back), label: const Text('Prev')),
            ElevatedButton.icon(onPressed: _next, icon: const Icon(Icons.arrow_forward), label: const Text('Next')),
          ],
        ),
      ),
    );
  }
}
