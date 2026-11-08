import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mode_dial.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const OneGoodThingApp());
}

const kForest = Color(0xFF143026);
const kSage = Color(0xFF386641);
const kCream = Color(0xFFFFFDF5);
const kGold = Color(0xFFFFD572);
const kMint = Color(0xFFBCEB84);
const kTerracotta = Color(0xFFE07A5F);

enum BreathRhythm {
  box('Box Breathing', 4, 4, 4, 4, '4-4-4-4 balance & focus'),
  calm('Deep Calm', 4, 7, 8, 0, '4-7-8 parasympathetic release'),
  flow('Gentle Flow', 4, 0, 4, 0, '4-4 coherent natural flow');

  final String title;
  final int inhale;
  final int holdIn;
  final int exhale;
  final int holdOut;
  final String subtitle;

  const BreathRhythm(
    this.title,
    this.inhale,
    this.holdIn,
    this.exhale,
    this.holdOut,
    this.subtitle,
  );

  int get totalDuration => inhale + holdIn + exhale + holdOut;
}

class GoodMemory {
  final String day;
  final String note;
  final int flower;
  const GoodMemory(this.day, this.note, this.flower);

  Map<String, dynamic> toJson() => {
        'day': day,
        'text': note,
        'flower': flower,
      };

  factory GoodMemory.fromJson(Map<String, dynamic> m) => GoodMemory(
        (m['day'] ?? '').toString(),
        (m['text'] ?? m['note'] ?? '').toString(),
        (m['flower'] is num) ? (m['flower'] as num).toInt() : 0,
      );
}

class FlowerInfo {
  final String name;
  final String emoji;
  final String description;
  final Color primaryColor;
  const FlowerInfo(this.name, this.emoji, this.description, this.primaryColor);
}

const List<FlowerInfo> kFlowerTypes = [
  FlowerInfo('Sakura Blossom', '🌸', 'Delicate cherry blossom carrying gentle joy', Color(0xFFFF9EB5)),
  FlowerInfo('Sunburst Sunflower', '🌻', 'Warm and radiant, soaking up bright moments', Color(0xFFFFCC33)),
  FlowerInfo('Velvet Rose', '🌹', 'Deep gratitude and heartfelt appreciation', Color(0xFFE63946)),
  FlowerInfo('Wild Chamomile', '🌼', 'Crisp white petals of calm and inner peace', Color(0xFFFFF4D0)),
  FlowerInfo('Royal Lavender', '💜', 'Soothing serenity and quiet reflection', Color(0xFFA58FE3)),
  FlowerInfo('Sacred Lotus', '🪷', 'Pure blooming wisdom rising from stillness', Color(0xFFFF85A1)),
];

class OneGoodThingApp extends StatelessWidget {
  const OneGoodThingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bloom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'sans-serif',
        colorScheme: ColorScheme.fromSeed(
          seedColor: kForest,
          brightness: Brightness.dark,
        ),
      ),
      home: const GardenScreen(),
    );
  }
}

class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> with TickerProviderStateMixin {
  final List<GoodMemory> memories = [];
  final AudioPlayer _ambientPlayer = AudioPlayer();
  final AudioPlayer _rainPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  late final AnimationController _ambientController;
  late final AnimationController _plantingController;
  late final AnimationController _gustController;
  late final AnimationController _breathController;
  late final AnimationController _hudOpacityController;

  AtmosphereMood _mood = AtmosphereMood.emerald;
  late final ValueNotifier<double> _moodProgressNotifier;
  bool _rainEnabled = false;
  bool _breathPacerEnabled = false;
  BreathRhythm _breathRhythm = BreathRhythm.calm;
  bool _sound = true;
  bool _ready = false;
  int? _growingIndex;
  int? _selectedMemoryIndex;
  Offset? _ripple;
  double _koiScarePhase = 0.0;
  Timer? _hudTimer;

  String get today {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int get todayIndex => memories.indexWhere((m) => m.day == today);

  @override
  void initState() {
    super.initState();
    _moodProgressNotifier = ValueNotifier<double>(_mood.index.toDouble());

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();

    _plantingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _gustController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _breathController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _breathRhythm.totalDuration),
    );

    _hudOpacityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.28,
      upperBound: 1.0,
      value: 1.0,
    );

    _initAudio();
    _load();
    _resetHudTimer();
  }

  void _resetHudTimer() {
    _hudTimer?.cancel();
    if (_hudOpacityController.value < 1.0) {
      _hudOpacityController.forward();
    }
    _hudTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        _hudOpacityController.reverse();
      }
    });
  }

  Future<void> _initAudio() async {
    try {
      await _ambientPlayer.setReleaseMode(ReleaseMode.loop);
      await _rainPlayer.setReleaseMode(ReleaseMode.loop);
      if (_sound) {
        await _playAmbientLoop();
      }
    } catch (_) {}
  }

  Future<void> _playAmbientLoop() async {
    if (!_sound) return;
    try {
      await _ambientPlayer.setVolume(0.32);
      await _ambientPlayer.play(AssetSource(_mood.audioAsset));
      if (_rainEnabled) {
        await _rainPlayer.setVolume(0.28);
        await _rainPlayer.play(AssetSource('audio/ambient_rain.wav'));
      } else {
        await _rainPlayer.stop();
      }
    } catch (_) {}
  }

  Future<void> _toggleSound() async {
    _resetHudTimer();
    HapticFeedback.selectionClick();
    setState(() => _sound = !_sound);
    if (_sound) {
      await _playAmbientLoop();
      _playSfx('tap.wav', 0.5);
      _showGardenToast('🔊', 'Sanctuary soundscape enabled', accentColor: _mood.primaryColor);
    } else {
      await _ambientPlayer.stop();
      await _rainPlayer.stop();
      _showGardenToast('🔇', 'Sanctuary muted', accentColor: Colors.white54);
    }
  }

  Future<void> _toggleRain() async {
    _resetHudTimer();
    HapticFeedback.selectionClick();
    setState(() => _rainEnabled = !_rainEnabled);
    _playSfx('tap.wav', 0.45);
    if (_sound) {
      if (_rainEnabled) {
        await _rainPlayer.setVolume(0.28);
        await _rainPlayer.play(AssetSource('audio/ambient_rain.wav'));
      } else {
        await _rainPlayer.stop();
      }
    }
    _showGardenToast(
      _rainEnabled ? '🌧️' : '✨',
      _rainEnabled ? 'Gentle Zen Rain layered over ${_mood.displayName}' : 'Rain cleared',
      accentColor: const Color(0xFF80D8FF),
    );
  }

  void _toggleBreathPacer() {
    _resetHudTimer();
    HapticFeedback.selectionClick();
    setState(() {
      _breathPacerEnabled = !_breathPacerEnabled;
      if (_breathPacerEnabled) {
        _breathController.duration = Duration(seconds: _breathRhythm.totalDuration);
        _breathController.repeat();
      } else {
        _breathController.stop();
        _breathController.reset();
      }
    });
    _playSfx('whisper_tone.mp3', 0.35);
    _showGardenToast(
      '🧘',
      _breathPacerEnabled
          ? '${_breathRhythm.title} (${_breathRhythm.subtitle})'
          : 'Breath Pacer paused',
      accentColor: _mood.primaryColor,
    );
  }

  (double, String) _calculateBreathState() {
    if (!_breathPacerEnabled) return (0.0, '');
    final total = _breathRhythm.totalDuration.toDouble();
    final sec = _breathController.value * total;
    final inhaleEnd = _breathRhythm.inhale.toDouble();
    final holdInEnd = inhaleEnd + _breathRhythm.holdIn;
    final exhaleEnd = holdInEnd + _breathRhythm.exhale;

    if (sec <= inhaleEnd) {
      final t = (sec / inhaleEnd).clamp(0.0, 1.0);
      return (Curves.easeInOut.transform(t), 'INHALE');
    } else if (sec <= holdInEnd) {
      return (1.0, 'HOLD');
    } else if (sec <= exhaleEnd) {
      final t = ((sec - holdInEnd) / _breathRhythm.exhale).clamp(0.0, 1.0);
      return (1.0 - Curves.easeInOut.transform(t), 'EXHALE');
    } else {
      return (0.0, 'REST');
    }
  }

  Future<void> _setMood(AtmosphereMood newMood) async {
    _resetHudTimer();
    _moodProgressNotifier.value = newMood.index.toDouble();
    if (_mood == newMood) return;
    HapticFeedback.selectionClick();
    setState(() => _mood = newMood);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('atmosphere_mood', newMood.index);
    if (_sound) {
      await _playAmbientLoop();
    }
    _showGardenToast(
      '✨',
      '${newMood.displayName} • ${newMood.subtitle}',
      accentColor: newMood.primaryColor,
    );
  }

  Future<void> _openOrbitSelector() async {
    _resetHudTimer();
    HapticFeedback.selectionClick();
    _playSfx('whisper_tone.mp3', 0.30);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetContext) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF070E14).withValues(alpha: 0.90),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.blur_on_rounded,
                          size: 16,
                          color: _mood.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CELESTIAL ORBIT ATMOSPHERE',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3.2,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ModeDial(
                      selectedMood: _mood,
                      onProgressChanged: (val) {
                        _moodProgressNotifier.value = val;
                      },
                      onMoodChanged: (m) {
                        _setMood(m);
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      alignment: WrapAlignment.center,
                      children: BreathRhythm.values.map((r) {
                        final selected = _breathPacerEnabled && _breathRhythm == r;
                        return ChoiceChip(
                          label: Text(r.title),
                          selected: selected,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            color: selected ? const Color(0xFF051E19) : Colors.white70,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          selectedColor: _mood.primaryColor,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          side: BorderSide(
                            color: selected
                                ? _mood.primaryColor
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _breathRhythm = r;
                              _breathPacerEnabled = true;
                              _breathController.duration = Duration(seconds: r.totalDuration);
                              _breathController.repeat();
                            });
                            setSheetState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMood = prefs.getInt('atmosphere_mood');
      if (savedMood != null && savedMood >= 0 && savedMood < AtmosphereMood.values.length) {
        _mood = AtmosphereMood.values[savedMood];
        _moodProgressNotifier.value = _mood.index.toDouble();
      }
      final raw = prefs.getString('memories');
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        memories.clear();
        memories.addAll(decoded.map((e) => GoodMemory.fromJson(Map<String, dynamic>.from(e))));
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _ready = true);
      if (_sound) _playAmbientLoop();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('memories', jsonEncode(memories.map((e) => e.toJson()).toList()));
  }

  Future<void> _playSfx(String fileName, [double volume = 0.5]) async {
    if (!_sound) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('audio/$fileName'), volume: volume);
    } catch (_) {}
  }

  void _showGardenToast(String icon, String message, {Color? accentColor}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 2200),
        margin: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + 86,
          left: 20,
          right: 20,
        ),
        padding: EdgeInsets.zero,
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1B18).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (accentColor ?? _mood.primaryColor).withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: (accentColor ?? _mood.primaryColor).withValues(alpha: 0.20),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: kCream,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _triggerTreeBlossomShower() {
    _resetHudTimer();
    HapticFeedback.mediumImpact();
    _gustController.forward(from: 0);
    _playSfx('chime_gust.wav', 0.65);
    _showGardenToast(
      '🌸',
      'A gentle breeze showers sakura petals across the lake...',
      accentColor: const Color(0xFFFFB7B2),
    );
  }

  Future<void> _openPlantSheet([int? editIndex]) async {
    _resetHudTimer();
    HapticFeedback.lightImpact();
    final isEditing = editIndex != null;
    final targetIndex = isEditing ? editIndex : todayIndex;
    final initialText = targetIndex >= 0 ? memories[targetIndex].note : '';
    final initialFlower = targetIndex >= 0 ? memories[targetIndex].flower : (memories.length % kFlowerTypes.length);

    final result = await showModalBottomSheet<PlantResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlantSheet(
        initial: initialText,
        initialFlower: initialFlower,
        isEditing: targetIndex >= 0,
      ),
    );

    if (result == null || !mounted) return;

    HapticFeedback.mediumImpact();

    setState(() {
      if (targetIndex >= 0) {
        memories[targetIndex] = GoodMemory(memories[targetIndex].day, result.note, result.flower);
        _selectedMemoryIndex = targetIndex;
      } else {
        memories.add(GoodMemory(today, result.note, result.flower));
        _growingIndex = memories.length - 1;
        _selectedMemoryIndex = _growingIndex;
        _plantingController.forward(from: 0);
      }
    });

    await _save();
    await _playSfx(targetIndex < 0 ? 'bloom.wav' : 'tap.wav', targetIndex < 0 ? 0.75 : 0.45);
    _showGardenToast(
      targetIndex < 0 ? '🌱' : '🌸',
      targetIndex < 0 ? 'Planted in your sanctuary! Watch it bloom ✨' : 'Today’s memory gently updated ✨',
      accentColor: _mood.primaryColor,
    );
  }

  void _inspectMemory(int index) {
    _resetHudTimer();
    if (index < 0 || index >= memories.length) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedMemoryIndex = index);
    _playSfx('whisper_tone.mp3', 0.45);

    final m = memories[index];
    final flowerInfo = kFlowerTypes[m.flower % kFlowerTypes.length];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1D1A).withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: flowerInfo.primaryColor.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: flowerInfo.primaryColor.withValues(alpha: 0.16),
                      border: Border.all(color: flowerInfo.primaryColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(flowerInfo.emoji, style: const TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          flowerInfo.name,
                          style: const TextStyle(
                            color: kCream,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: kMint),
                            const SizedBox(width: 6),
                            Text(
                              m.day,
                              style: const TextStyle(
                                color: kMint,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Memory #${index + 1}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openPostcardModal(index);
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      foregroundColor: kGold,
                    ),
                    icon: const Icon(Icons.photo_camera_back_rounded, size: 20),
                    tooltip: 'Postcard Snapshot',
                  ),
                  if (index == todayIndex) ...[
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openPlantSheet(index);
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: kMint.withValues(alpha: 0.2),
                        foregroundColor: kMint,
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      tooltip: 'Edit Memory',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  '“${m.note}”',
                  style: const TextStyle(
                    color: kCream,
                    fontSize: 17,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                flowerInfo.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPostcardModal(int index) {
    final m = memories[index];
    final flowerInfo = kFlowerTypes[m.flower % kFlowerTypes.length];

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F4238), Color(0xFF0E231D)],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: kGold.withValues(alpha: 0.45), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF6EB),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'BLOOM',
                          style: TextStyle(
                            color: Color(0xFF6B7F73),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6E1D3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'SPECIMEN #${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF4A5C52),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Color(0xFFDCD6C5), height: 26, thickness: 1),
                    Container(
                      width: 100,
                      height: 100,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            flowerInfo.primaryColor.withValues(alpha: 0.35),
                            flowerInfo.primaryColor.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: flowerInfo.primaryColor.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        flowerInfo.emoji,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      flowerInfo.name.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF2C3E35),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.day,
                      style: const TextStyle(
                        color: Color(0xFF819388),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EDE0),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE0DACB)),
                      ),
                      child: Text(
                        '“${m.note}”',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1E3027),
                          fontSize: 16,
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: '“${m.note}” (${m.day})'));
                        HapticFeedback.selectionClick();
                        Navigator.pop(ctx);
                        _showGardenToast('📋', 'Memory quote copied to clipboard!', accentColor: kMint);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: kMint,
                        foregroundColor: const Color(0xFF10261F),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Quote', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filled(
                    onPressed: () => Navigator.pop(ctx),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMemoriesSheet() {
    _resetHudTimer();
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollController) => BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A1D19).withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Blooming Memories 🌸',
                              style: TextStyle(
                                color: kCream,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Every flower holds a moment of goodness',
                              style: TextStyle(color: Color(0xFF8BA59B), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _mood.primaryColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _mood.primaryColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          '${memories.length} planted',
                          style: TextStyle(
                            color: _mood.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: memories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🌱', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              const Text(
                                'Your garden is waiting for its first seed',
                                style: TextStyle(color: kCream, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _openPlantSheet();
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: _mood.primaryColor,
                                  foregroundColor: const Color(0xFF062019),
                                ),
                                icon: const Icon(Icons.spa_rounded),
                                label: const Text('Plant Now', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          itemCount: memories.length,
                          itemBuilder: (_, j) {
                            final i = memories.length - j - 1;
                            final m = memories[i];
                            final flower = kFlowerTypes[m.flower % kFlowerTypes.length];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: flower.primaryColor.withValues(alpha: 0.16),
                                  ),
                                  child: Text(flower.emoji, style: const TextStyle(fontSize: 26)),
                                ),
                                title: Text(
                                  m.note,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kCream,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${m.day} • ${flower.name}',
                                    style: const TextStyle(color: Color(0xFF7E9D90), fontSize: 11.5),
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.photo_camera_back_rounded, color: kGold, size: 20),
                                  tooltip: 'View Postcard',
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openPostcardModal(i);
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _inspectMemory(i);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _moodProgressNotifier.dispose();
    _ambientController.dispose();
    _plantingController.dispose();
    _gustController.dispose();
    _breathController.dispose();
    _hudOpacityController.dispose();
    _ambientPlayer.dispose();
    _rainPlayer.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040D0C),
      body: Listener(
        onPointerDown: (_) => _resetHudTimer(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. 100% PROCEDURAL FULL-SCREEN LIVING SANCTUARY CANVAS (ZERO IMAGE ASSETS)
            Positioned.fill(
              child: LayoutBuilder(
                builder: (sceneContext, sceneConstraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    _resetHudTimer();
                    final sceneSize = sceneConstraints.biggest;
                    final point = details.localPosition;

                    // 1. Sakura Tree Tap (Triggers blossom shower flurry)
                    final treeRect = Rect.fromLTWH(
                      0,
                      sceneSize.height * 0.24,
                      sceneSize.width * 0.44,
                      sceneSize.height * 0.36,
                    );
                    if (treeRect.contains(point)) {
                      _triggerTreeBlossomShower();
                      return;
                    }

                    // 2. Hit test user's REAL memory flowers only
                    final positions = MasterpieceGardenPainter.flowerPositions(memories.length, sceneSize);
                    for (var i = positions.length - 1; i >= 0; i--) {
                      final base = positions[i];
                      final head = base - const Offset(0, 32);
                      if ((base - point).distance < 42 || (head - point).distance < 42) {
                        _inspectMemory(i);
                        return;
                      }
                    }

                    // 3. Pond tap (Scare / ripple koi fish)
                    final pondCenter = Offset(sceneSize.width * 0.58, sceneSize.height * 0.855);
                    if ((point - pondCenter).distance < 78) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _koiScarePhase = 1.0;
                        _ripple = point;
                      });
                      _playSfx('ripple.wav', 0.5);
                      return;
                    }

                    // 4. General water / lake / ground tap
                    HapticFeedback.selectionClick();
                    setState(() => _ripple = point);
                    _playSfx('ripple.wav', 0.38);
                  },
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _ambientController,
                      _plantingController,
                      _gustController,
                      _breathController,
                      _moodProgressNotifier,
                    ]),
                    builder: (_, __) {
                      final (breathProg, breathLabel) = _calculateBreathState();
                      return CustomPaint(
                        painter: MasterpieceGardenPainter(
                          t: _ambientController.value,
                          moodProgress: _moodProgressNotifier.value,
                          rainEnabled: _rainEnabled,
                          breathActive: _breathPacerEnabled,
                          breathProgress: breathProg,
                          breathLabel: breathLabel,
                          memories: memories,
                          growingIndex: _growingIndex,
                          growth: _plantingController.value,
                          gustProgress: _gustController.value,
                          ripple: _ripple,
                          selectedFlowerIndex: _selectedMemoryIndex,
                          koiScarePhase: _koiScarePhase,
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
              ),
            ),

            // 2. FLOATING AUTO-DIMMING BOTTOM CONTROLS (NO NAVBAR, NO TOP TEXT, ZERO OVERFLOW)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.paddingOf(context).bottom + 14,
              child: FadeTransition(
                opacity: _hudOpacityController,
                child: Row(
                  children: [
                    // Memories Pill (Book + count)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: InkWell(
                          onTap: _openMemoriesSheet,
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF091614).withValues(alpha: 0.68),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_stories_rounded, color: _mood.primaryColor, size: 17),
                                const SizedBox(width: 5),
                                Text(
                                  '${memories.length}',
                                  style: const TextStyle(
                                    color: kCream,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // STILL Celestial Orbit Mode Pill (Procedural Planet Orb + Mood Name)
                    Expanded(
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: InkWell(
                              onTap: _openOrbitSelector,
                              borderRadius: BorderRadius.circular(26),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF071116).withValues(alpha: 0.72),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                    color: _mood.primaryColor.withValues(alpha: 0.48),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _mood.glowColor.withValues(alpha: 0.22),
                                      blurRadius: 14,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ProceduralPlanetSphere(
                                        mood: _mood,
                                        size: 18,
                                        activeAmount: 1.0,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _mood.displayName.toUpperCase(),
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: _mood.primaryColor,
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.6,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.expand_less_rounded,
                                        size: 15,
                                        color: _mood.primaryColor.withValues(alpha: 0.8),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Plant / Bloom Today's Memory Orb
                    GestureDetector(
                      onTap: _ready ? () => _openPlantSheet(todayIndex >= 0 ? todayIndex : null) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _mood.primaryColor,
                              Color.lerp(_mood.primaryColor, const Color(0xFF96E6A1), 0.5)!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _mood.primaryColor.withValues(alpha: 0.45),
                              blurRadius: 16,
                              spreadRadius: 1.5,
                            ),
                          ],
                        ),
                        child: Icon(
                          todayIndex < 0 ? Icons.add_rounded : Icons.spa_rounded,
                          color: const Color(0xFF061E17),
                          size: 26,
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Sensory Capsule (Breath Pacer + Rain + Sound)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF091614).withValues(alpha: 0.68),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Guided Breath Pacer',
                                onPressed: _toggleBreathPacer,
                                icon: Icon(
                                  _breathPacerEnabled ? Icons.self_improvement_rounded : Icons.spa_outlined,
                                  color: _breathPacerEnabled ? _mood.primaryColor : Colors.white60,
                                  size: 18,
                                ),
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 34),
                                padding: EdgeInsets.zero,
                              ),
                              IconButton(
                                tooltip: 'Zen Rain Overlay',
                                onPressed: _toggleRain,
                                icon: Icon(
                                  _rainEnabled ? Icons.water_drop_rounded : Icons.water_drop_outlined,
                                  color: _rainEnabled ? const Color(0xFF80D8FF) : Colors.white60,
                                  size: 17,
                                ),
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 34),
                                padding: EdgeInsets.zero,
                              ),
                              IconButton(
                                tooltip: _sound ? 'Mute' : 'Enable Sound',
                                onPressed: _toggleSound,
                                icon: Icon(
                                  _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                  color: _sound ? _mood.primaryColor : Colors.white38,
                                  size: 18,
                                ),
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(minWidth: 30, minHeight: 34),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlantResult {
  final String note;
  final int flower;
  const PlantResult(this.note, this.flower);
}

class PlantSheet extends StatefulWidget {
  final String initial;
  final int initialFlower;
  final bool isEditing;
  const PlantSheet({
    super.key,
    required this.initial,
    required this.initialFlower,
    this.isEditing = false,
  });

  @override
  State<PlantSheet> createState() => _PlantSheetState();
}

class _PlantSheetState extends State<PlantSheet> {
  late final TextEditingController _controller;
  late int _flower;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
    _flower = widget.initialFlower;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF0C211D).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      widget.isEditing ? 'Update Today’s Bloom 🌿' : 'Plant One Good Thing 🌱',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kCream,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white60),
                    ),
                  ],
                ),
                const Text(
                  'What small moment brought you peace or gratitude today?',
                  style: TextStyle(color: Color(0xFF9AB5AA), fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  maxLines: 3,
                  maxLength: 180,
                  autofocus: true,
                  style: const TextStyle(color: kCream, fontSize: 16, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'e.g., A quiet cup of warm tea while watching the sky...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.28),
                    counterStyle: const TextStyle(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: kMint, width: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose your blooming flower species',
                  style: TextStyle(color: kCream, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < kFlowerTypes.length; i++) ...[
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _flower = i);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _flower == i ? kMint.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                color: _flower == i ? kMint : Colors.white.withValues(alpha: 0.12),
                                width: _flower == i ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Text(kFlowerTypes[i].emoji, style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 8),
                                Text(
                                  kFlowerTypes[i].name.split(' ').first,
                                  style: TextStyle(
                                    color: _flower == i ? kMint : Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      final note = _controller.text.trim();
                      if (note.isNotEmpty) {
                        Navigator.pop(context, PlantResult(note, _flower));
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: kMint,
                      foregroundColor: const Color(0xFF0E251E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                    label: Text(
                      widget.isEditing ? 'Save & Rebloom ✨' : 'Let It Bloom In The Garden ✨',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// STILL Procedural Palette for smooth continuous interpolation across all 6 realms.
class _AtmospherePalette {
  final Color skyTop;
  final Color skyMiddle;
  final Color skyHorizon;
  final Color light;
  final Color coronaColor;
  final Color farMountain;
  final Color nearMountain;
  final Color waterTop;
  final Color waterMiddle;
  final Color waterBottom;
  final Color meadowBack;
  final Color meadowFront;
  final Color accent;
  final double auroraIntensity;
  final double starAlpha;
  final bool isEclipse;

  const _AtmospherePalette({
    required this.skyTop,
    required this.skyMiddle,
    required this.skyHorizon,
    required this.light,
    required this.coronaColor,
    required this.farMountain,
    required this.nearMountain,
    required this.waterTop,
    required this.waterMiddle,
    required this.waterBottom,
    required this.meadowBack,
    required this.meadowFront,
    required this.accent,
    required this.auroraIntensity,
    required this.starAlpha,
    required this.isEclipse,
  });

  static _AtmospherePalette forMood(AtmosphereMood mood) {
    switch (mood) {
      case AtmosphereMood.dusk:
        return const _AtmospherePalette(
          skyTop: Color(0xFF140D1E),
          skyMiddle: Color(0xFF47233C),
          skyHorizon: Color(0xFFD9603B),
          light: Color(0xFFFFE0B2),
          coronaColor: Color(0xFFFF6D2E),
          farMountain: Color(0xFF3E223A),
          nearMountain: Color(0xFF231326),
          waterTop: Color(0xFF6B353E),
          waterMiddle: Color(0xFF2E1B2E),
          waterBottom: Color(0xFF120C18),
          meadowBack: Color(0xFF4F312E),
          meadowFront: Color(0xFF29181C),
          accent: Color(0xFFFF5E1E),
          auroraIntensity: 0.0,
          starAlpha: 0.25,
          isEclipse: false,
        );
      case AtmosphereMood.midnight:
        return const _AtmospherePalette(
          skyTop: Color(0xFF030714),
          skyMiddle: Color(0xFF0D1B38),
          skyHorizon: Color(0xFF1F3666),
          light: Color(0xFFE3F0FF),
          coronaColor: Color(0xFF528BFF),
          farMountain: Color(0xFF16284C),
          nearMountain: Color(0xFF0B162C),
          waterTop: Color(0xFF1D3562),
          waterMiddle: Color(0xFF0E1D3A),
          waterBottom: Color(0xFF050B18),
          meadowBack: Color(0xFF153642),
          meadowFront: Color(0xFF091B24),
          accent: Color(0xFF6B9FFF),
          auroraIntensity: 0.30,
          starAlpha: 0.90,
          isEclipse: false,
        );
      case AtmosphereMood.eclipse:
        return const _AtmospherePalette(
          skyTop: Color(0xFF05030A),
          skyMiddle: Color(0xFF180E29),
          skyHorizon: Color(0xFF3B1E54),
          light: Color(0xFFF3E5FF),
          coronaColor: Color(0xFFB356FF),
          farMountain: Color(0xFF251438),
          nearMountain: Color(0xFF130920),
          waterTop: Color(0xFF311B47),
          waterMiddle: Color(0xFF190D29),
          waterBottom: Color(0xFF090412),
          meadowBack: Color(0xFF281A3B),
          meadowFront: Color(0xFF120B1D),
          accent: Color(0xFFC06AFF),
          auroraIntensity: 0.20,
          starAlpha: 0.95,
          isEclipse: true,
        );
      case AtmosphereMood.emerald:
        return const _AtmospherePalette(
          skyTop: Color(0xFF04120E),
          skyMiddle: Color(0xFF0C2E24),
          skyHorizon: Color(0xFF1E5C47),
          light: Color(0xFFD8FFEE),
          coronaColor: Color(0xFF2EEDB0),
          farMountain: Color(0xFF133D30),
          nearMountain: Color(0xFF09241C),
          waterTop: Color(0xFF1B5945),
          waterMiddle: Color(0xFF0D362A),
          waterBottom: Color(0xFF041712),
          meadowBack: Color(0xFF1E5942),
          meadowFront: Color(0xFF0B2B20),
          accent: Color(0xFF2EEDB0),
          auroraIntensity: 0.85,
          starAlpha: 0.65,
          isEclipse: false,
        );
      case AtmosphereMood.aurora:
        return const _AtmospherePalette(
          skyTop: Color(0xFF030E14),
          skyMiddle: Color(0xFF082832),
          skyHorizon: Color(0xFF15525C),
          light: Color(0xFF9EFFFF),
          coronaColor: Color(0xFF26E6E6),
          farMountain: Color(0xFF103842),
          nearMountain: Color(0xFF082026),
          waterTop: Color(0xFF144E57),
          waterMiddle: Color(0xFF0A2E36),
          waterBottom: Color(0xFF041418),
          meadowBack: Color(0xFF184A52),
          meadowFront: Color(0xFF092429),
          accent: Color(0xFF26E6E6),
          auroraIntensity: 1.0,
          starAlpha: 0.80,
          isEclipse: false,
        );
      case AtmosphereMood.dawn:
        return const _AtmospherePalette(
          skyTop: Color(0xFF1C3554),
          skyMiddle: Color(0xFF577B96),
          skyHorizon: Color(0xFFFFB870),
          light: Color(0xFFFFF5D6),
          coronaColor: Color(0xFFFF9E3B),
          farMountain: Color(0xFF475C72),
          nearMountain: Color(0xFF293B4D),
          waterTop: Color(0xFF527D8C),
          waterMiddle: Color(0xFF264E63),
          waterBottom: Color(0xFF0F2634),
          meadowBack: Color(0xFF4B874B),
          meadowFront: Color(0xFF1E4F2F),
          accent: Color(0xFFFFB338),
          auroraIntensity: 0.0,
          starAlpha: 0.12,
          isEclipse: false,
        );
    }
  }

  static _AtmospherePalette resolve(double progress) {
    final moods = AtmosphereMood.values;
    final clamped = progress.clamp(0.0, moods.length - 1.0);
    final idx = clamped.floor();
    final rem = clamped - idx;
    final p1 = forMood(moods[idx]);
    if (rem <= 0.001 || idx >= moods.length - 1) return p1;
    final p2 = forMood(moods[idx + 1]);

    return _AtmospherePalette(
      skyTop: Color.lerp(p1.skyTop, p2.skyTop, rem)!,
      skyMiddle: Color.lerp(p1.skyMiddle, p2.skyMiddle, rem)!,
      skyHorizon: Color.lerp(p1.skyHorizon, p2.skyHorizon, rem)!,
      light: Color.lerp(p1.light, p2.light, rem)!,
      coronaColor: Color.lerp(p1.coronaColor, p2.coronaColor, rem)!,
      farMountain: Color.lerp(p1.farMountain, p2.farMountain, rem)!,
      nearMountain: Color.lerp(p1.nearMountain, p2.nearMountain, rem)!,
      waterTop: Color.lerp(p1.waterTop, p2.waterTop, rem)!,
      waterMiddle: Color.lerp(p1.waterMiddle, p2.waterMiddle, rem)!,
      waterBottom: Color.lerp(p1.waterBottom, p2.waterBottom, rem)!,
      meadowBack: Color.lerp(p1.meadowBack, p2.meadowBack, rem)!,
      meadowFront: Color.lerp(p1.meadowFront, p2.meadowFront, rem)!,
      accent: Color.lerp(p1.accent, p2.accent, rem)!,
      auroraIntensity: p1.auroraIntensity + (p2.auroraIntensity - p1.auroraIntensity) * rem,
      starAlpha: p1.starAlpha + (p2.starAlpha - p1.starAlpha) * rem,
      isEclipse: rem > 0.5 ? p2.isEclipse : p1.isEclipse,
    );
  }
}

/// 100% Procedural Masterpiece Living Garden + STILL Celestial Water Sanctuary Painter.
class MasterpieceGardenPainter extends CustomPainter {
  final double t;
  final double moodProgress;
  final bool rainEnabled;
  final bool breathActive;
  final double breathProgress;
  final String breathLabel;
  final List<GoodMemory> memories;
  final int? growingIndex;
  final double growth;
  final double gustProgress;
  final Offset? ripple;
  final int? selectedFlowerIndex;
  final double koiScarePhase;

  MasterpieceGardenPainter({
    required this.t,
    required this.moodProgress,
    required this.rainEnabled,
    required this.breathActive,
    required this.breathProgress,
    required this.breathLabel,
    required this.memories,
    required this.growingIndex,
    required this.growth,
    required this.gustProgress,
    required this.ripple,
    this.selectedFlowerIndex,
    this.koiScarePhase = 0.0,
  });

  static List<Offset> flowerPositions(int count, Size s) {
    final positions = <Offset>[];
    if (count == 0) return positions;

    final w = s.width;
    final h = s.height;

    // 40 spacious, well-distributed spots across 3 lush garden terraces
    // (avoiding the stream channel x ~0.55..0.67 and koi pond at bottom center)
    const spots = [
      // Tier 1: Prime Mid-Meadow Sanctuary
      Offset(0.42, 0.725), // 0: Center-left prime spot
      Offset(0.26, 0.745), // 1: Left meadow glade
      Offset(0.76, 0.735), // 2: Right stream terrace
      Offset(0.34, 0.665), // 3: Upper-mid hillside
      Offset(0.84, 0.675), // 4: Right hillside overlook
      Offset(0.16, 0.785), // 5: Lower-left lawn
      Offset(0.48, 0.655), // 6: Near upper stream bank
      Offset(0.74, 0.805), // 7: Right lower bank
      Offset(0.28, 0.825), // 8: Front-left meadow
      Offset(0.88, 0.760), // 9: Far-right mid slope

      // Tier 2: Upper Hillside & Under-Canopy Terrace (y: 0.56 .. 0.65)
      Offset(0.41, 0.595), // 10: High hillside center-left
      Offset(0.76, 0.605), // 11: High hillside right
      Offset(0.24, 0.625), // 12: Beneath sakura canopy
      Offset(0.51, 0.585), // 13: Lakefront ridge left
      Offset(0.86, 0.610), // 14: Far right ridge
      Offset(0.12, 0.650), // 15: Far left tree roots
      Offset(0.69, 0.575), // 16: East waterfall crest
      Offset(0.32, 0.575), // 17: High sakura knoll
      Offset(0.18, 0.700), // 18: Mid-left grove
      Offset(0.91, 0.695), // 19: Far-right terrace

      // Tier 3: Expansive Foreground & Midground Fill (y: 0.68 .. 0.89)
      Offset(0.37, 0.790), // 20: Lower-mid left
      Offset(0.82, 0.845), // 21: Lower-right foreground
      Offset(0.18, 0.860), // 22: Deep left foreground
      Offset(0.45, 0.815), // 23: Pond-side left bank
      Offset(0.71, 0.700), // 24: East stream bank
      Offset(0.10, 0.735), // 25: West border glade
      Offset(0.92, 0.815), // 26: East border lawn
      Offset(0.29, 0.695), // 27: Inner sakura glade
      Offset(0.79, 0.640), // 28: Upper-east slope
      Offset(0.36, 0.875), // 29: Front-left edge
      Offset(0.75, 0.880), // 30: Front-right edge
      Offset(0.11, 0.825), // 31: Far-left foreground
      Offset(0.46, 0.755), // 32: Central stone path edge
      Offset(0.69, 0.765), // 33: East stepping-stone edge
      Offset(0.22, 0.765), // 34: West mid-lawn
      Offset(0.85, 0.720), // 35: East mid-lawn
      Offset(0.39, 0.630), // 36: Upper-mid knoll
      Offset(0.14, 0.595), // 37: West high knoll
      Offset(0.90, 0.875), // 38: Far-right corner
      Offset(0.25, 0.885), // 39: Front-west lawn
    ];

    for (var i = 0; i < count; i++) {
      if (i < spots.length) {
        positions.add(Offset(spots[i].dx * w, spots[i].dy * h));
      } else {
        final seed = math.Random(i * 137 + 19);
        double x = 0.08 + (seed.nextDouble() * 0.84);
        final y = 0.57 + (seed.nextDouble() * 0.32);
        // Keep clear of the central stream and pond channel
        if (x > 0.51 && x < 0.68 && y > 0.60) {
          x = (i.isEven) ? (x - 0.16).clamp(0.08, 0.49) : (x + 0.16).clamp(0.69, 0.92);
        }
        positions.add(Offset(x * w, y * h));
      }
    }
    return positions;
  }

  Paint solid(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final p = _AtmospherePalette.resolve(moodProgress);

    _paintProceduralSkyAndCosmos(canvas, size, p);
    if (breathActive) {
      _paintBreathPacerRing(canvas, size, p);
    }
    _paintProceduralMountainsAndLake(canvas, size, p);
    _paintForegroundMeadowHills(canvas, size, p);
    _paintMilestoneFootbridge(canvas, size);
    _paintWaterfallAndStream(canvas, size, p);
    _paintMilestoneSteppingStones(canvas, size);
    _paintKoiFish(canvas, size);
    _paintLivingTree(canvas, size, p);
    _paintMilestoneLantern(canvas, size, p);
    _paintMeadowGrass(canvas, size, p);
    _paintFallingPetalsAndGust(canvas, size, p);
    if (rainEnabled) {
      _paintRainfall(canvas, size);
    }
    _paintMemoryFlowers(canvas, size, p);
    _paintWildlife(canvas, size, p);

    if (ripple != null) {
      _paintWaterRipple(canvas, ripple!, p);
    }

    canvas.restore();
  }

  void _paintProceduralSkyAndCosmos(Canvas c, Size s, _AtmospherePalette p) {
    final w = s.width, h = s.height;
    final horizon = h * 0.38;

    // 1. Deep multi-stop atmospheric sky gradient
    c.drawRect(
      Rect.fromLTWH(0, 0, w, horizon + 20),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, horizon),
          [p.skyTop, p.skyMiddle, p.skyHorizon],
          [0.0, 0.62, 1.0],
        ),
    );

    // 2. Shimmering Aurora Borealis Ribbons (STILL signature)
    if (p.auroraIntensity > 0.05) {
      for (int i = 0; i < 3; i++) {
        final phase = t * math.pi * 2 * 0.8 + i * 1.9;
        final path = Path()..moveTo(0, 0);
        for (double x = 0; x <= w; x += 18) {
          final wave = math.sin(x * 0.009 + phase) * 20 +
              math.cos(x * 0.016 - phase * 0.7) * 14;
          final y = horizon * (0.28 + i * 0.11) + wave;
          path.lineTo(x, y);
        }
        path.lineTo(w, 0);
        path.close();

        final ribbonColor = i == 0
            ? p.accent
            : (i == 1 ? const Color(0xFF7B2CBF) : const Color(0xFF00F5D4));

        c.drawPath(
          path,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset.zero,
              Offset(0, horizon * 0.78),
              [
                Colors.transparent,
                ribbonColor.withValues(alpha: 0.18 * p.auroraIntensity),
                ribbonColor.withValues(alpha: 0.05 * p.auroraIntensity),
                Colors.transparent,
              ],
              [0.0, 0.45, 0.80, 1.0],
            ),
        );
      }
    }

    // 3. Twinkling Stars & Shooting Stars
    if (p.starAlpha > 0.04) {
      final rand = math.Random(43);
      for (var i = 0; i < 65; i++) {
        final sx = rand.nextDouble() * w;
        final sy = (0.02 + rand.nextDouble() * 0.32) * h;
        final twinkle = 0.55 + 0.45 * math.sin(t * math.pi * 2 * (1.5 + (i % 4)) + i * 2.1);
        final r = (i % 9 == 0) ? 1.9 : ((i % 3 == 0) ? 1.2 : 0.75);

        c.drawCircle(
          Offset(sx, sy),
          r,
          solid(const Color(0xFFF4F1EA).withValues(alpha: p.starAlpha * twinkle)),
        );
      }

      // Periodic Shooting Star
      final cycle = (t * 2.5) % 1.0;
      if (cycle < 0.20) {
        final prog = cycle / 0.20;
        final ssStartX = w * 0.20 + prog * (w * 0.42);
        final ssStartY = h * 0.05 + prog * (h * 0.11);
        final ssLen = 46.0 * math.sin(prog * math.pi);
        c.drawLine(
          Offset(ssStartX - ssLen, ssStartY - ssLen * 0.42),
          Offset(ssStartX, ssStartY),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(ssStartX - ssLen, ssStartY - ssLen * 0.42),
              Offset(ssStartX, ssStartY),
              [Colors.transparent, Colors.white.withValues(alpha: 0.9 * p.starAlpha)],
              [0.0, 1.0],
            )
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // 4. Celestial Orb (Sun / Moon / Solar Eclipse Corona from STILL)
    final orbCenter = Offset(w * 0.64, h * 0.17);
    // Wide atmospheric corona halo
    c.drawCircle(
      orbCenter,
      w * 0.48,
      Paint()
        ..shader = ui.Gradient.radial(
          orbCenter,
          w * 0.48,
          [
            p.coronaColor.withValues(alpha: 0.26),
            p.coronaColor.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          [0.0, 0.45, 1.0],
        ),
    );
    // Inner glow
    c.drawCircle(
      orbCenter,
      w * 0.15,
      Paint()
        ..shader = ui.Gradient.radial(
          orbCenter,
          w * 0.15,
          [
            p.light.withValues(alpha: 0.42),
            p.coronaColor.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          [0.0, 0.55, 1.0],
        ),
    );

    if (p.isEclipse) {
      // Solar Eclipse Corona Ring + Obsidian Core
      c.drawCircle(
        orbCenter,
        w * 0.078,
        Paint()
          ..shader = ui.Gradient.radial(
            orbCenter,
            w * 0.078,
            [
              Colors.transparent,
              p.coronaColor.withValues(alpha: 0.85),
              Colors.white,
            ],
            [0.74, 0.92, 1.0],
          ),
      );
      c.drawCircle(orbCenter, w * 0.069, solid(const Color(0xFF06050A)));
    } else {
      c.drawCircle(
        orbCenter,
        w * 0.068,
        Paint()
          ..shader = ui.Gradient.radial(
            orbCenter,
            w * 0.068,
            [Colors.white, p.light],
            [0.0, 1.0],
          ),
      );
    }
  }

  void _paintBreathPacerRing(Canvas c, Size s, _AtmospherePalette p) {
    final center = Offset(s.width * 0.64, s.height * 0.17);
    final minR = s.width * 0.085;
    final maxR = s.width * 0.21;
    final radius = minR + (maxR - minR) * breathProgress;

    c.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            p.accent.withValues(alpha: 0.16 * breathProgress),
            Colors.transparent,
          ],
          [0.0, 1.0],
        ),
    );

    c.drawCircle(
      center,
      radius,
      Paint()
        ..color = p.light.withValues(alpha: 0.30 + 0.40 * breathProgress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: breathLabel,
        style: TextStyle(
          color: kCream.withValues(alpha: 0.92),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 4.5,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(c, Offset(center.dx - tp.width * 0.5, center.dy + maxR + 12));
  }

  void _paintProceduralMountainsAndLake(Canvas c, Size s, _AtmospherePalette p) {
    final w = s.width, h = s.height;
    final horizon = h * 0.38;

    // 1. Far Alpine Peaks
    final farPeaks = Path()
      ..moveTo(0, horizon)
      ..lineTo(0, horizon - h * 0.08)
      ..lineTo(w * 0.14, horizon - h * 0.14)
      ..lineTo(w * 0.27, horizon - h * 0.07)
      ..lineTo(w * 0.44, horizon - h * 0.17)
      ..lineTo(w * 0.60, horizon - h * 0.06)
      ..lineTo(w * 0.78, horizon - h * 0.15)
      ..lineTo(w * 0.91, horizon - h * 0.08)
      ..lineTo(w, horizon - h * 0.12)
      ..lineTo(w, horizon)
      ..close();

    c.drawPath(
      farPeaks,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizon - h * 0.17),
          Offset(0, horizon),
          [
            Color.lerp(p.farMountain, p.light, 0.22)!,
            p.farMountain,
          ],
          [0.0, 1.0],
        ),
    );

    // 2. Near Mountain Ridges
    final nearRidge = Path()
      ..moveTo(0, horizon)
      ..lineTo(0, horizon - h * 0.035)
      ..cubicTo(
        w * 0.18,
        horizon - h * 0.09,
        w * 0.32,
        horizon - h * 0.025,
        w * 0.48,
        horizon - h * 0.065,
      )
      ..cubicTo(
        w * 0.66,
        horizon - h * 0.10,
        w * 0.82,
        horizon - h * 0.025,
        w,
        horizon - h * 0.06,
      )
      ..lineTo(w, horizon)
      ..close();

    c.drawPath(nearRidge, solid(p.nearMountain));

    // 3. Horizon Mist Glow
    c.drawRect(
      Rect.fromLTWH(0, horizon - 20, w, 36),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizon - 20),
          Offset(0, horizon + 16),
          [
            Colors.transparent,
            p.skyHorizon.withValues(alpha: 0.28),
            Colors.transparent,
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // 4. Shimmering Alpine Lake (from horizon 0.38 to 0.55)
    final lakeHeight = h * 0.17;
    final lakeRect = Rect.fromLTWH(0, horizon, w, lakeHeight);
    c.drawRect(
      lakeRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizon),
          Offset(0, horizon + lakeHeight),
          [p.waterTop, p.waterMiddle, p.waterBottom],
          [0.0, 0.45, 1.0],
        ),
    );

    // Reflected Celestial Column on Lake Water (STILL signature)
    final lightX = w * 0.64;
    final reflectedGlow = Rect.fromCenter(
      center: Offset(lightX, horizon + lakeHeight * 0.40),
      width: w * 0.70,
      height: lakeHeight * 0.90,
    );
    c.drawOval(
      reflectedGlow,
      Paint()
        ..shader = ui.Gradient.radial(
          reflectedGlow.center,
          w * 0.35,
          [
            p.light.withValues(alpha: 0.20),
            p.coronaColor.withValues(alpha: 0.06),
            Colors.transparent,
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Shimmering horizontal water reflection lines
    final phase = t * math.pi * 2;
    for (var row = 0; row < 20; row++) {
      final depth = (row + 0.5) / 20;
      final y = horizon + 4 + math.pow(depth, 1.15) * (lakeHeight * 0.84);
      final spread = w * (0.03 + depth * 0.18);
      final waveOffset = math.sin(phase * 0.8 + row * 0.7) * spread * 0.12;
      final center = lightX + waveOffset;
      final length = spread * (0.25 + 0.35 * (0.5 + 0.5 * math.sin(row * 1.6 + phase)));

      c.drawLine(
        Offset(center - length * 0.5, y),
        Offset(center + length * 0.5, y),
        Paint()
          ..color = p.light.withValues(alpha: (0.24 * (1 - depth) + 0.04))
          ..strokeWidth = 0.8 + depth * 0.9
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintForegroundMeadowHills(Canvas c, Size s, _AtmospherePalette p) {
    final w = s.width, h = s.height;

    // Tier 1: Upper Hillside Terrace (starts at h * 0.49 .. 0.53)
    final upperHill = Path()
      ..moveTo(0, h * 0.52)
      ..cubicTo(w * 0.22, h * 0.47, w * 0.42, h * 0.54, w * 0.64, h * 0.51)
      ..cubicTo(w * 0.82, h * 0.48, w * 0.94, h * 0.53, w, h * 0.51)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    c.drawPath(
      upperHill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.47),
          Offset(0, h * 0.72),
          [
            Color.lerp(p.meadowBack, p.light, 0.12)!,
            p.meadowBack,
          ],
          [0.0, 1.0],
        ),
    );

    // Tier 2: Mid Sanctuary Meadow (rolling slope at h * 0.63)
    final midMeadow = Path()
      ..moveTo(0, h * 0.64)
      ..cubicTo(w * 0.26, h * 0.59, w * 0.46, h * 0.66, w * 0.68, h * 0.62)
      ..cubicTo(w * 0.84, h * 0.59, w * 0.95, h * 0.64, w, h * 0.63)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    c.drawPath(
      midMeadow,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.59),
          Offset(0, h * 0.84),
          [
            Color.lerp(p.meadowBack, p.accent, 0.14)!,
            p.meadowFront,
          ],
          [0.0, 1.0],
        ),
    );

    // Tier 3: Foreground Botanical Lawn (h * 0.76 to 1.0)
    final frontMeadow = Path()
      ..moveTo(0, h * 0.77)
      ..cubicTo(w * 0.25, h * 0.72, w * 0.45, h * 0.78, w * 0.70, h * 0.74)
      ..cubicTo(w * 0.85, h * 0.72, w * 0.95, h * 0.76, w, h * 0.75)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    c.drawPath(
      frontMeadow,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.72),
          Offset(0, h),
          [
            Color.lerp(p.meadowBack, p.accent, 0.18)!,
            Color.lerp(p.meadowFront, Colors.black, 0.35)!,
          ],
          [0.0, 1.0],
        ),
    );
  }

  void _paintMilestoneFootbridge(Canvas c, Size s) {
    if (memories.length < 14) return;
    final w = s.width, h = s.height;

    final bridgeStart = Offset(w * 0.56, h * 0.54);
    final bridgeEnd = Offset(w * 0.68, h * 0.54);
    final archPeakY = h * 0.515;

    final arch = Path()
      ..moveTo(bridgeStart.dx, bridgeStart.dy)
      ..quadraticBezierTo((bridgeStart.dx + bridgeEnd.dx) * 0.5, archPeakY, bridgeEnd.dx, bridgeEnd.dy)
      ..lineTo(bridgeEnd.dx, bridgeEnd.dy + 5)
      ..quadraticBezierTo((bridgeStart.dx + bridgeEnd.dx) * 0.5, archPeakY + 5, bridgeStart.dx, bridgeStart.dy + 5)
      ..close();

    c.drawPath(arch, solid(const Color(0xFF543425)));

    for (var i = 0; i <= 4; i++) {
      final prog = i / 4.0;
      final bx = bridgeStart.dx + (bridgeEnd.dx - bridgeStart.dx) * prog;
      final by = bridgeStart.dy + (4 * (archPeakY - bridgeStart.dy) * prog * (1 - prog));
      c.drawLine(
        Offset(bx, by),
        Offset(bx, by - 12),
        solid(const Color(0xFF8B5E3C))..strokeWidth = 2.0,
      );
    }
    final handrail = Path()
      ..moveTo(bridgeStart.dx, bridgeStart.dy - 12)
      ..quadraticBezierTo((bridgeStart.dx + bridgeEnd.dx) * 0.5, archPeakY - 12, bridgeEnd.dx, bridgeEnd.dy - 12);
    c.drawPath(
      handrail,
      Paint()
        ..color = const Color(0xFFC48E59)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
  }

  void _paintWaterfallAndStream(Canvas c, Size s, _AtmospherePalette p) {
    final w = s.width, h = s.height;

    final streamTop = Offset(w * 0.62, h * 0.51);
    final streamMid = Offset(w * 0.60, h * 0.68);
    final streamBottom = Offset(w * 0.58, h * 0.855);

    final streamBed = Path()
      ..moveTo(streamTop.dx - 14, streamTop.dy)
      ..quadraticBezierTo(w * 0.61, h * 0.59, streamMid.dx - 22, streamMid.dy)
      ..quadraticBezierTo(w * 0.58, h * 0.77, streamBottom.dx - 34, streamBottom.dy)
      ..quadraticBezierTo(streamBottom.dx, streamBottom.dy + 20, streamBottom.dx + 34, streamBottom.dy)
      ..quadraticBezierTo(w * 0.64, h * 0.77, streamMid.dx + 22, streamMid.dy)
      ..quadraticBezierTo(w * 0.65, h * 0.59, streamTop.dx + 14, streamTop.dy)
      ..close();

    final waterColors = [
      p.accent.withValues(alpha: 0.85),
      p.waterTop,
      p.waterBottom,
    ];

    c.drawPath(
      streamBed,
      Paint()
        ..shader = ui.Gradient.linear(
          streamTop,
          streamBottom,
          waterColors,
          [0.0, 0.55, 1.0],
        ),
    );

    for (var i = 0; i < 20; i++) {
      final prog = ((t * 2.2 + (i / 20)) % 1.0);
      final cx = streamTop.dx + (streamBottom.dx - streamTop.dx) * prog + math.sin(prog * math.pi * 4) * 6;
      final cy = streamTop.dy + (streamBottom.dy - streamTop.dy) * prog;
      final streakLen = 11.0 + (i % 4) * 4;

      c.drawLine(
        Offset(cx - 2, cy),
        Offset(cx + 2, cy + streakLen),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.32 + 0.28 * math.sin(prog * math.pi))
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    final rockPositions = [
      Offset(w * 0.57, h * 0.53),
      Offset(w * 0.66, h * 0.55),
      Offset(w * 0.56, h * 0.64),
      Offset(w * 0.65, h * 0.67),
      Offset(w * 0.54, h * 0.75),
      Offset(w * 0.64, h * 0.78),
      Offset(w * 0.52, h * 0.83),
      Offset(w * 0.65, h * 0.84),
    ];
    for (var i = 0; i < rockPositions.length; i++) {
      final rp = rockPositions[i];
      final rx = 12.0 + (i % 3) * 4.5;
      final ry = 8.0 + (i % 2) * 3.5;

      c.drawOval(
        Rect.fromCenter(center: rp + const Offset(0, 3), width: rx * 2.2, height: ry * 1.8),
        solid(Colors.black.withValues(alpha: 0.35)),
      );
      c.drawOval(
        Rect.fromCenter(center: rp, width: rx * 2, height: ry * 2),
        Paint()
          ..shader = ui.Gradient.linear(
            rp - Offset(0, ry),
            rp + Offset(0, ry),
            [const Color(0xFF7B8C82), const Color(0xFF42524A)],
            [0.0, 1.0],
          ),
      );
      c.drawOval(
        Rect.fromCenter(center: rp - Offset(0, ry * 0.4), width: rx * 1.5, height: ry * 0.85),
        solid(p.meadowBack.withValues(alpha: 0.85)),
      );
    }

    final pondCenter = Offset(w * 0.58, h * 0.855);
    final pondRect = Rect.fromCenter(center: pondCenter, width: w * 0.38, height: h * 0.072);

    c.drawOval(
      pondRect,
      Paint()
        ..shader = ui.Gradient.radial(
          pondCenter,
          pondRect.width * 0.5,
          waterColors,
          [0.0, 0.55, 1.0],
        ),
    );

    for (var i = 0; i < 4; i++) {
      final rippleProg = ((t * 1.2 + i * 0.25) % 1.0);
      final rWidth = pondRect.width * 0.85 * rippleProg;
      final rHeight = pondRect.height * 0.85 * rippleProg;
      final rippleAlpha = (1.0 - rippleProg).clamp(0.0, 1.0);

      c.drawOval(
        Rect.fromCenter(center: pondCenter, width: rWidth, height: rHeight),
        Paint()
          ..color = p.light.withValues(alpha: rippleAlpha * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _paintMilestoneSteppingStones(Canvas c, Size s) {
    if (memories.length < 3) return;
    final w = s.width, h = s.height;

    final stones = [
      Offset(w * 0.55, h * 0.71),
      Offset(w * 0.60, h * 0.72),
      Offset(w * 0.65, h * 0.73),
    ];

    for (var sp in stones) {
      c.drawOval(
        Rect.fromCenter(center: sp + const Offset(0, 2), width: 18, height: 12),
        solid(Colors.black.withValues(alpha: 0.28)),
      );
      c.drawOval(
        Rect.fromCenter(center: sp, width: 16, height: 10),
        solid(const Color(0xFF7B8B7D)),
      );
      c.drawOval(
        Rect.fromCenter(center: sp - const Offset(1, 1), width: 11, height: 6),
        solid(const Color(0xFF5A854D).withValues(alpha: 0.8)),
      );
    }
  }

  void _paintKoiFish(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final pondCenter = Offset(w * 0.58, h * 0.855);

    final speedMult = 1.0 + koiScarePhase * 2.5;
    final k1Angle = t * math.pi * 2 * 0.3 * speedMult;
    final k1RadiusX = w * 0.11;
    final k1RadiusY = h * 0.020;
    final k1Pos = pondCenter + Offset(math.cos(k1Angle) * k1RadiusX, math.sin(k1Angle) * k1RadiusY);

    _drawSingleKoi(
      c,
      k1Pos,
      k1Angle + math.pi * 0.5,
      bodyColor: const Color(0xFFFFFDF5),
      patchColor: const Color(0xFFFF5400),
      length: 15.0,
    );

    final k2Angle = (t * math.pi * 2 * 0.25 * speedMult) + math.pi;
    final k2RadiusX = w * 0.085;
    final k2RadiusY = h * 0.016;
    final k2Pos = pondCenter + Offset(math.cos(k2Angle) * k2RadiusX, math.sin(k2Angle) * k2RadiusY);

    _drawSingleKoi(
      c,
      k2Pos,
      k2Angle + math.pi * 0.5,
      bodyColor: const Color(0xFFFFD166),
      patchColor: const Color(0xFFFF9E00),
      length: 13.0,
    );
  }

  void _drawSingleKoi(
    Canvas c,
    Offset pos,
    double heading, {
    required Color bodyColor,
    required Color patchColor,
    required double length,
  }) {
    c.save();
    c.translate(pos.dx, pos.dy);
    c.rotate(heading);

    final tailWiggle = math.sin(t * math.pi * 12) * 3.5;

    final body = Path()
      ..moveTo(0, -length * 0.6)
      ..quadraticBezierTo(length * 0.35, -length * 0.1, length * 0.15, length * 0.4)
      ..lineTo(tailWiggle, length * 0.75)
      ..lineTo(-length * 0.15, length * 0.4)
      ..quadraticBezierTo(-length * 0.35, -length * 0.1, 0, -length * 0.6)
      ..close();

    c.drawPath(body, solid(bodyColor.withValues(alpha: 0.88)));

    c.drawOval(
      Rect.fromCenter(center: const Offset(0, -2), width: length * 0.4, height: length * 0.5),
      solid(patchColor.withValues(alpha: 0.9)),
    );
    c.drawCircle(
      Offset(0, -length * 0.35),
      2.0,
      solid(const Color(0xFFE63946)),
    );

    c.drawOval(
      Rect.fromCenter(center: Offset(-length * 0.35, -length * 0.2), width: 6, height: 3),
      solid(Colors.white.withValues(alpha: 0.6)),
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(length * 0.35, -length * 0.2), width: 6, height: 3),
      solid(Colors.white.withValues(alpha: 0.6)),
    );

    c.restore();
  }

  void _paintLivingTree(Canvas c, Size s, _AtmospherePalette p) {
    final w = s.width, h = s.height;

    c.save();
    c.translate(w * 0.18, h * 0.55);
    final treeScale = math.min(w / 380, 1.15);
    c.scale(treeScale);

    final gustSway = math.sin(gustProgress * math.pi * 2) * 5.0;

    final trunk = Path()
      ..moveTo(-20, 20)
      ..cubicTo(-6, -40, -22, -80, 5 + gustSway * 0.3, -118)
      ..cubicTo(20, -145, 45, -165, 38 + gustSway * 0.6, -200)
      ..cubicTo(72, -168, 55, -135, 30 + gustSway * 0.3, -112)
      ..cubicTo(12, -92, 18, -48, 14, 20)
      ..close();

    c.drawPath(
      trunk,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-20, 0),
          const Offset(50, -180),
          [const Color(0xFF2B1810), const Color(0xFF5A3720), const Color(0xFF3E2416)],
          [0.0, 0.6, 1.0],
        ),
    );

    c.drawLine(
      const Offset(-14, 15),
      const Offset(-32, 24),
      solid(const Color(0xFF2B1810))..strokeWidth = 7..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      const Offset(10, 15),
      const Offset(26, 24),
      solid(const Color(0xFF2B1810))..strokeWidth = 6..strokeCap = StrokeCap.round,
    );

    _drawCurvedBranch(c, const Offset(18, -120), Offset(-55 + gustSway, -175), 9);
    _drawCurvedBranch(c, const Offset(36, -155), Offset(115 + gustSway, -195), 8);
    _drawCurvedBranch(c, const Offset(10, -100), Offset(90 + gustSway, -130), 6);
    _drawCurvedBranch(c, const Offset(-20, -150), Offset(-80 + gustSway, -210), 5);
    _drawCurvedBranch(c, const Offset(65, -175), Offset(120 + gustSway, -235), 4);

    final rand = math.Random(42);
    const blossomCount = 92;

    for (var i = 0; i < blossomCount; i++) {
      final angle = rand.nextDouble() * math.pi * 2;
      final rad = math.sqrt(rand.nextDouble());
      final bx = 26 + math.cos(angle) * rad * 110;
      final by = -188 + math.sin(angle) * rad * 60;
      final sway = math.sin(t * math.pi * 2 + i * 0.3) * 2.8 + gustSway;
      final r = 5.0 + rand.nextDouble() * 5.2;

      c.drawCircle(
        Offset(bx + sway, by + 3),
        r + 2.5,
        solid(Colors.black.withValues(alpha: 0.28)),
      );

      final baseBlossomColors = [
        const Color(0xFFFF8FA3),
        const Color(0xFFFFB3C1),
        const Color(0xFFFFCCD5),
      ];
      final flowerColor = Color.lerp(baseBlossomColors[i % 3], p.accent, 0.16)!;
      final center = Offset(bx + sway, by);

      for (var pt = 0; pt < 5; pt++) {
        final pa = pt * math.pi * 2 / 5 + 0.3;
        final po = center + Offset(math.cos(pa) * r * 0.65, math.sin(pa) * r * 0.65);
        c.drawCircle(po, r * 0.6, solid(flowerColor));
      }
      c.drawCircle(center, r * 0.32, solid(const Color(0xFFFFD166)));
    }

    c.restore();
  }

  void _drawCurvedBranch(Canvas c, Offset a, Offset b, double thickness) {
    final ctrl = Offset((a.dx + b.dx) * 0.5 + 8, (a.dy + b.dy) * 0.5 - 14);
    final p = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);

    c.drawPath(
      p,
      Paint()
        ..color = const Color(0xFF3E2416)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintMilestoneLantern(Canvas c, Size s, _AtmospherePalette p) {
    if (memories.length < 7) return;
    final w = s.width, h = s.height;

    final treeAnchor = Offset(w * 0.28, h * 0.45);
    final lanternPos = treeAnchor + const Offset(0, 32);

    c.drawLine(treeAnchor, lanternPos, solid(const Color(0xFF2C1E14))..strokeWidth = 1.2);

    c.drawCircle(
      lanternPos,
      32.0,
      Paint()
        ..color = p.accent.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    c.drawPath(
      Path()
        ..moveTo(lanternPos.dx - 10, lanternPos.dy - 6)
        ..lineTo(lanternPos.dx, lanternPos.dy - 12)
        ..lineTo(lanternPos.dx + 10, lanternPos.dy - 6)
        ..close(),
      solid(const Color(0xFF3B2317)),
    );

    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: lanternPos, width: 14, height: 16),
        const Radius.circular(3),
      ),
      solid(const Color(0xFFFFF275)),
    );

    c.drawRect(
      Rect.fromCenter(center: lanternPos + const Offset(0, 9), width: 12, height: 3),
      solid(const Color(0xFF3B2317)),
    );
  }

  void _paintMeadowGrass(Canvas c, Size s, _AtmospherePalette p) {
    final w = s.width, h = s.height;
    final rand = math.Random(77);

    final grassTint = Color.lerp(const Color(0xFF5FA852), p.accent, 0.25)!;

    for (var i = 0; i < 120; i++) {
      final gx = rand.nextDouble() * w;
      final gy = (0.53 + rand.nextDouble() * 0.44) * h;
      final gLen = 6.0 + rand.nextDouble() * 12.0;
      final wind = math.sin(t * math.pi * 2 + i * 0.4) * 3.5;

      c.drawLine(
        Offset(gx, gy),
        Offset(gx + wind, gy - gLen),
        solid(grassTint.withValues(alpha: 0.48))
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 0; i < 70; i++) {
      final gx = (i / 70) * w + rand.nextDouble() * 8;
      final gy = (0.65 + rand.nextDouble() * 0.32) * h;
      final gLen = 10.0 + rand.nextDouble() * 16.0;
      final wind = math.sin(t * math.pi * 2 + i * 0.6) * 4.5;

      final grassPath = Path()
        ..moveTo(gx, gy)
        ..quadraticBezierTo(gx + wind * 0.5, gy - gLen * 0.6, gx + wind, gy - gLen);

      c.drawPath(
        grassPath,
        Paint()
          ..color = grassTint.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );

      if (i % 6 == 0) {
        c.drawCircle(
          Offset(gx + wind, gy - gLen),
          1.4,
          solid(p.accent.withValues(alpha: 0.75)),
        );
      }
    }
  }

  void _paintFallingPetalsAndGust(Canvas c, Size s, _AtmospherePalette p) {
    final w = s.width, h = s.height;

    const count = 18;
    for (var i = 0; i < count; i++) {
      final prog = ((t * 0.8 + i * (1.0 / count)) % 1.0);
      final px = (w * 0.15) + prog * (w * 0.85) + math.sin(prog * math.pi * 4 + i) * 22;
      final py = (h * 0.32) + prog * (h * 0.62);
      final rot = prog * math.pi * 4 + i * 1.5;

      c.save();
      c.translate(px, py);
      c.rotate(rot);

      final petalColor = Color.lerp(const Color(0xFFFFB7C5), p.accent, 0.2)!;
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 8.5, height: 4.8),
        solid(petalColor.withValues(alpha: 0.75)),
      );
      c.restore();
    }

    if (gustProgress > 0.0 && gustProgress < 1.0) {
      const flurryCount = 35;
      for (var f = 0; f < flurryCount; f++) {
        final prog = (gustProgress + f * (1.0 / flurryCount)) % 1.0;
        final gx = (w * 0.18) + prog * (w * 0.82) + math.sin(prog * math.pi * 6 + f) * 36;
        final gy = (h * 0.35) + prog * (h * 0.58);
        final rot = prog * math.pi * 8 + f * 1.2;

        c.save();
        c.translate(gx, gy);
        c.rotate(rot);

        c.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 10, height: 5.5),
          solid(const Color(0xFFFF85A1).withValues(alpha: (1.0 - gustProgress * 0.5) * 0.85)),
        );
        c.restore();
      }
    }
  }

  void _paintRainfall(Canvas c, Size s) {
    final w = s.width, h = s.height;

    const rainCount = 55;
    for (var r = 0; r < rainCount; r++) {
      final prog = ((t * 3.5 + r * 0.17) % 1.0);
      final rx = (r / rainCount) * w + prog * 18;
      final ry = prog * h;
      final rLen = 16.0 + (r % 4) * 5;

      c.drawLine(
        Offset(rx, ry),
        Offset(rx - 4, ry + rLen),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );

      if (prog > 0.85) {
        final splashProg = (prog - 0.85) / 0.15;
        c.drawOval(
          Rect.fromCenter(
            center: Offset(rx - 4, ry + rLen),
            width: 12 * splashProg,
            height: 4 * splashProg,
          ),
          Paint()
            ..color = Colors.white.withValues(alpha: (1.0 - splashProg) * 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }
  }

  void _paintMemoryFlowers(Canvas c, Size s, _AtmospherePalette p) {
    final positions = flowerPositions(memories.length, s);

    if (memories.isEmpty) {
      final centerSpot = Offset(s.width * 0.42, s.height * 0.725);
      final pulse = (math.sin(t * math.pi * 2) * 0.5 + 0.5);

      c.drawCircle(
        centerSpot,
        28.0 + pulse * 6.0,
        Paint()
          ..color = p.accent.withValues(alpha: 0.20 + pulse * 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      c.drawCircle(
        centerSpot,
        18.0,
        Paint()
          ..color = p.accent.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      c.drawCircle(centerSpot, 6.0, solid(p.accent));
      return;
    }

    // Sort flower indices back-to-front by vertical position (dy) for natural 3D depth overlap
    final drawOrder = List<int>.generate(positions.length, (i) => i)
      ..sort((a, b) => positions[a].dy.compareTo(positions[b].dy));

    for (final i in drawOrder) {
      final m = memories[i];
      final pos = positions[i];
      final isGrowing = (i == growingIndex && growth < 1.0);
      final stage = isGrowing ? Curves.easeOutCubic.transform(growth) : 1.0;
      final isSelected = (i == selectedFlowerIndex);

      // Perspective depth scaling: upper hillside (0.56) is 0.72x, foreground (0.89) is 1.02x
      final depthNorm = ((pos.dy / s.height - 0.55) / 0.35).clamp(0.0, 1.0);
      final depthScale = 0.72 + depthNorm * 0.30;

      c.save();
      c.translate(pos.dx, pos.dy);
      c.scale(depthScale);
      c.translate(-pos.dx, -pos.dy);

      _drawBotanicalFlower(
        c,
        pos,
        m.flower % kFlowerTypes.length,
        i,
        stage,
        isSelected,
      );

      c.restore();

      if (isGrowing) {
        _drawGrowthSparkles(c, pos, growth);
      }
    }
  }

  void _drawBotanicalFlower(
    Canvas c,
    Offset base,
    int type,
    int seed,
    double stage,
    bool isSelected,
  ) {
    if (stage <= 0.01) return;

    c.save();
    c.translate(base.dx, base.dy);

    final sway = math.sin(t * math.pi * 2 + seed * 1.5) * (3.0 + (seed % 3));
    final flowerHeight = (54.0 + (seed % 4) * 6.0) * stage;

    c.drawCircle(
      Offset(sway, -flowerHeight),
      isSelected ? 36.0 : 22.0,
      Paint()
        ..color = (isSelected ? kGold : kFlowerTypes[type].primaryColor)
            .withValues(alpha: isSelected ? 0.35 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    if (isSelected) {
      c.drawCircle(
        Offset(sway, -flowerHeight),
        26.0,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    final stemPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(sway * 0.4 - 3, -flowerHeight * 0.5, sway, -flowerHeight);

    c.drawPath(
      stemPath,
      Paint()
        ..color = const Color(0xFF2D6E3F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );

    if (stage > 0.3) {
      final leafProgress = ((stage - 0.3) / 0.4).clamp(0.0, 1.0);
      c.save();
      c.scale(leafProgress);

      final lCenter = Offset(-10 + sway * 0.3, -flowerHeight * 0.38);
      c.save();
      c.translate(lCenter.dx, lCenter.dy);
      c.rotate(-0.4);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 8),
        solid(const Color(0xFF439A52)),
      );
      c.drawLine(
        const Offset(-9, 0),
        const Offset(9, 0),
        solid(const Color(0xFF72C281))..strokeWidth = 1.0,
      );
      c.restore();

      final rCenter = Offset(10 + sway * 0.5, -flowerHeight * 0.58);
      c.save();
      c.translate(rCenter.dx, rCenter.dy);
      c.rotate(0.35);
      c.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 7.5),
        solid(const Color(0xFF388544)),
      );
      c.drawLine(
        const Offset(-8, 0),
        const Offset(8, 0),
        solid(const Color(0xFF72C281))..strokeWidth = 1.0,
      );
      c.restore();

      c.restore();
    }

    if (stage > 0.5) {
      final bloomProgress = ((stage - 0.5) / 0.5).clamp(0.0, 1.0);
      final bloomScale = Curves.elasticOut.transform(bloomProgress).clamp(0.0, 1.3);

      c.save();
      c.translate(sway, -flowerHeight);
      c.scale(bloomScale);

      switch (type) {
        case 0:
          _drawDetailedSakura(c);
          break;
        case 1:
          _drawDetailedSunflower(c);
          break;
        case 2:
          _drawDetailedRose(c);
          break;
        case 3:
          _drawDetailedDaisy(c);
          break;
        case 4:
          _drawDetailedLavender(c);
          break;
        case 5:
        default:
          _drawDetailedLotus(c);
          break;
      }

      c.restore();
    }

    c.restore();
  }

  void _drawDetailedSakura(Canvas c) {
    const petalCount = 5;
    for (var i = 0; i < petalCount; i++) {
      final angle = i * math.pi * 2 / petalCount;
      c.save();
      c.rotate(angle);
      final petal = Path()
        ..moveTo(0, 0)
        ..cubicTo(-10, -14, -14, -26, -5, -30)
        ..cubicTo(0, -28, 0, -28, 5, -30)
        ..cubicTo(14, -26, 10, -14, 0, 0)
        ..close();
      c.drawPath(
        petal,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(0, -30),
            [const Color(0xFFFF758F), const Color(0xFFFFB3C1), const Color(0xFFFFF0F3)],
            [0.0, 0.5, 1.0],
          ),
      );
      c.restore();
    }
    for (var s = 0; s < 10; s++) {
      final sa = s * math.pi * 2 / 10;
      final sx = math.cos(sa) * 9.0;
      final sy = math.sin(sa) * 9.0;
      c.drawLine(Offset.zero, Offset(sx, sy), solid(const Color(0xFFFF4D6D))..strokeWidth = 1.0);
      c.drawCircle(Offset(sx, sy), 1.6, solid(const Color(0xFFFFD166)));
    }
    c.drawCircle(Offset.zero, 5.0, solid(const Color(0xFFC9184A)));
  }

  void _drawDetailedSunflower(Canvas c) {
    const petals = 16;
    for (var i = 0; i < petals; i++) {
      final a = i * math.pi * 2 / petals;
      c.save();
      c.rotate(a);
      final petal = Path()
        ..moveTo(0, -6)
        ..quadraticBezierTo(-7, -18, 0, -28)
        ..quadraticBezierTo(7, -18, 0, -6);
      c.drawPath(
        petal,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(0, -6),
            const Offset(0, -28),
            [const Color(0xFFFF9E00), const Color(0xFFFFD000), const Color(0xFFFFEA79)],
            [0.0, 0.5, 1.0],
          ),
      );
      c.restore();
    }
    c.drawCircle(
      Offset.zero,
      10.5,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          10.5,
          [const Color(0xFF3D2314), const Color(0xFF5E391F), const Color(0xFF7A4A28)],
          [0.0, 0.5, 1.0],
        ),
    );
    for (var d = 0; d < 12; d++) {
      final da = d * 1.6;
      final dr = 2.0 + (d * 0.65);
      c.drawCircle(Offset(math.cos(da) * dr, math.sin(da) * dr), 1.0, solid(const Color(0xFFFFD166)));
    }
  }

  void _drawDetailedRose(Canvas c) {
    final colors = [
      const Color(0xFF590D22),
      const Color(0xFF800F2F),
      const Color(0xFFA4133C),
      const Color(0xFFC9184A),
      const Color(0xFFFF4D6D),
    ];
    for (var layer = 4; layer >= 0; layer--) {
      final count = 3 + layer;
      final r = 6.0 + layer * 4.5;
      for (var i = 0; i < count; i++) {
        final a = i * math.pi * 2 / count + layer * 0.4;
        c.save();
        c.rotate(a);
        c.drawOval(
          Rect.fromCenter(center: Offset(0, -r), width: r * 1.5, height: r * 1.2),
          solid(colors[layer]),
        );
        c.restore();
      }
    }
    c.drawCircle(Offset.zero, 4.0, solid(const Color(0xFFFF758F)));
  }

  void _drawDetailedDaisy(Canvas c) {
    const petals = 14;
    for (var i = 0; i < petals; i++) {
      final a = i * math.pi * 2 / petals;
      c.save();
      c.rotate(a);
      c.drawOval(
        Rect.fromCenter(center: const Offset(0, -16), width: 7.0, height: 20),
        solid(const Color(0xFFE5EDF0)),
      );
      c.drawOval(
        Rect.fromCenter(center: const Offset(0, -16), width: 5.5, height: 18),
        solid(Colors.white),
      );
      c.restore();
    }
    c.drawCircle(
      Offset.zero,
      7.5,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(-1, -1),
          7.5,
          [const Color(0xFFFFF275), const Color(0xFFFFB703), const Color(0xFFFB8500)],
          [0.0, 0.5, 1.0],
        ),
    );
  }

  void _drawDetailedLavender(Canvas c) {
    const tiers = 6;
    for (var t = 0; t < tiers; t++) {
      final ty = -t * 6.0;
      final spread = 5.0 + (tiers - t) * 1.2;
      c.drawOval(
        Rect.fromCenter(center: Offset(-spread * 0.5, ty), width: 9, height: 6),
        solid(const Color(0xFF7209B7)),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(spread * 0.5, ty), width: 9, height: 6),
        solid(const Color(0xFF9D4EDD)),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(0, ty - 2), width: 8, height: 6),
        solid(const Color(0xFFC77DFF)),
      );
    }
    c.drawCircle(const Offset(0, -tiers * 6.0 - 4), 3.5, solid(const Color(0xFFE0AAFF)));
  }

  void _drawDetailedLotus(Canvas c) {
    const petals = 8;
    for (var i = 0; i < petals; i++) {
      final a = i * math.pi * 2 / petals;
      c.save();
      c.rotate(a);
      final p = Path()
        ..moveTo(0, 0)
        ..cubicTo(-9, -12, -10, -22, 0, -28)
        ..cubicTo(10, -22, 9, -12, 0, 0)
        ..close();
      c.drawPath(
        p,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            const Offset(0, -28),
            [const Color(0xFFFF70A6), const Color(0xFFFF9770), const Color(0xFFFFD670)],
            [0.0, 0.5, 1.0],
          ),
      );
      c.restore();
    }
    c.drawCircle(
      Offset.zero,
      6.0,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          6.0,
          [const Color(0xFFFFF3B0), const Color(0xFFE36414)],
          [0.0, 1.0],
        ),
    );
  }

  void _drawGrowthSparkles(Canvas c, Offset base, double phase) {
    final ease = Curves.easeOut.transform(phase);
    const count = 30;

    for (var i = 0; i < count; i++) {
      final angle = i * math.pi * 2 / count;
      final dist = 12.0 + ease * (34.0 + (i % 6) * 8.0);
      final pos = base + Offset(math.cos(angle) * dist, -32 + math.sin(angle) * dist);
      final r = (1.0 - phase) * (2.4 + (i % 3) * 1.2);

      c.drawCircle(
        pos,
        r,
        solid(const Color(0xFFFFF6A5).withValues(alpha: 1.0 - phase)),
      );
    }

    c.drawCircle(
      base - const Offset(0, 32),
      48.0 * (1.0 - phase),
      Paint()
        ..color = const Color(0xFFFFE57F).withValues(alpha: (1.0 - phase) * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  void _paintWildlife(Canvas c, Size s, _AtmospherePalette p) {
    final w = s.width, h = s.height;

    for (var b = 0; b < 3; b++) {
      final bx = w * (0.28 + b * 0.25) + math.sin(t * math.pi * 2 + b * 2) * 32;
      final by = h * (0.56 + (b % 2) * 0.14) + math.cos(t * math.pi * 3 + b) * 16;
      final wingFlap = (0.25 + 0.75 * math.sin(t * math.pi * 28 + b * 3).abs());

      c.save();
      c.translate(bx, by);
      c.rotate(math.sin(t * math.pi * 2 + b) * 0.2);

      final bColor = (b == 0)
          ? const Color(0xFFFFC300)
          : (b == 1 ? const Color(0xFFFF85A1) : p.accent);

      c.drawOval(
        Rect.fromCenter(center: Offset(-7 * wingFlap, -6), width: 14 * wingFlap, height: 18),
        solid(bColor),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(7 * wingFlap, -6), width: 14 * wingFlap, height: 18),
        solid(bColor),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(-5 * wingFlap, 5), width: 11 * wingFlap, height: 13),
        solid(bColor.withValues(alpha: 0.8)),
      );
      c.drawOval(
        Rect.fromCenter(center: Offset(5 * wingFlap, 5), width: 11 * wingFlap, height: 13),
        solid(bColor.withValues(alpha: 0.8)),
      );
      c.drawLine(
        const Offset(0, -9),
        const Offset(0, 8),
        solid(const Color(0xFF352216))..strokeWidth = 2.0,
      );

      c.restore();
    }

    const particleCount = 34;
    final rand = math.Random(505);

    for (var i = 0; i < particleCount; i++) {
      final px = (rand.nextDouble() * w + math.sin(t * math.pi * 2 + i) * 20);
      final py = (0.45 + rand.nextDouble() * 0.48) * h + math.cos(t * math.pi * 2 + i * 1.5) * 12;
      final flicker = (0.3 + 0.7 * math.sin(t * math.pi * 4 + i * 2).abs());

      c.drawCircle(
        Offset(px, py),
        8.5,
        Paint()
          ..color = p.accent.withValues(alpha: flicker * 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      c.drawCircle(
        Offset(px, py),
        1.8,
        solid(const Color(0xFFFFF9DB).withValues(alpha: flicker)),
      );
    }
  }

  void _paintWaterRipple(Canvas c, Offset point, _AtmospherePalette p) {
    final rippleRadius = 16.0 + (math.sin(t * math.pi * 2) + 1.0) * 10.0;
    for (var i = 0; i < 3; i++) {
      c.drawOval(
        Rect.fromCenter(center: point, width: (rippleRadius + i * 14) * 2, height: (rippleRadius + i * 14) * 0.8),
        Paint()
          ..color = p.accent.withValues(alpha: 0.40 - i * 0.12)
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MasterpieceGardenPainter old) =>
      t != old.t ||
      moodProgress != old.moodProgress ||
      rainEnabled != old.rainEnabled ||
      breathActive != old.breathActive ||
      breathProgress != old.breathProgress ||
      growth != old.growth ||
      gustProgress != old.gustProgress ||
      memories.length != old.memories.length ||
      ripple != old.ripple ||
      selectedFlowerIndex != old.selectedFlowerIndex ||
      koiScarePhase != old.koiScarePhase;
}
