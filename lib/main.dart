import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VoiceLabApp());
}

const Color bg = Color(0xFF090911);
const Color panel = Color(0xFF141422);
const Color purple = Color(0xFF9B6DFF);
const Color blue = Color(0xFF4B8DFF);

class VoiceLabApp extends StatelessWidget {
  const VoiceLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: purple,
          brightness: Brightness.dark,
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: purple,
          inactiveTrackColor: Color(0xFF303044),
          thumbColor: Colors.white,
          overlayColor: Color(0x339B6DFF),
        ),
      ),
      home: const VoiceHome(),
    );
  }
}

class VoiceHome extends StatefulWidget {
  const VoiceHome({super.key});

  @override
  State<VoiceHome> createState() => _VoiceHomeState();
}

class _VoiceHomeState extends State<VoiceHome>
    with SingleTickerProviderStateMixin {
  static const audio = MethodChannel('voice_changer/audio');

  late final AnimationController waveController;

  bool enabled = false;
  bool busy = false;
  String status = 'พร้อมเริ่มต้น';
  String preset = 'Natural';

  double pitch = 0;
  double robot = 0;
  double echo = 0;
  double gain = 1;

  final List<String> presets = [
    'Natural',
    'Deep',
    'High',
    'Robot',
    'Radio',
  ];

  @override
  void initState() {
    super.initState();
    waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    waveController.dispose();
    super.dispose();
  }

  Future<void> invokeAudio(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    try {
      await audio.invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => status = e.message ?? 'เกิดข้อผิดพลาด');
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => status = 'ยังไม่ได้ติดตั้งระบบเสียง Native');
      }
    }
  }

  Future<void> toggleAudio() async {
    if (busy) return;

    setState(() => busy = true);

    try {
      if (enabled) {
        await invokeAudio('stopAudio');
        if (mounted) {
          setState(() {
            enabled = false;
            status = 'ปิดระบบเสียงแล้ว';
          });
        }
      } else {
        await audio.invokeMethod('startAudio');
        if (mounted) {
          setState(() {
            enabled = true;
            status = 'กำลังประมวลผลเสียง';
          });
          await sendSettings();
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          enabled = false;
          status = e.message ?? 'เปิดไมโครโฟนไม่สำเร็จ';
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          enabled = false;
          status = 'ยังไม่ได้เชื่อมต่อระบบเสียง Native';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> sendSettings() async {
    await invokeAudio('setEffects', {
      'pitch': pitch,
      'robot': robot,
      'echo': echo,
      'gain': gain,
    });
  }

  void applyPreset(String value) {
    setState(() {
      preset = value;

      switch (value) {
        case 'Deep':
          pitch = -5;
          robot = 0;
          echo = 0;
          gain = 1;
          break;
        case 'High':
          pitch = 5;
          robot = 0;
          echo = 0;
          gain = 1;
          break;
        case 'Robot':
          pitch = 0;
          robot = 80;
          echo = 10;
          gain = 1;
          break;
        case 'Radio':
          pitch = -1;
          robot = 15;
          echo = 5;
          gain = 0.8;
          break;
        default:
          pitch = 0;
          robot = 0;
          echo = 0;
          gain = 1;
      }
    });

    if (enabled) sendSettings();
  }

  Widget buildWaveform() {
    return AnimatedBuilder(
      animation: waveController,
      builder: (context, child) {
        return CustomPaint(
          painter: WavePainter(waveController.value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget sectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget effectSlider({
    required String title,
    required String description,
    required double value,
    required double min,
    required double max,
    required String valueText,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 8),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  color: purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (next) {
              onChanged(next);
              if (enabled) sendSettings();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: buildWaveform()),
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: purple.withValues(alpha: 0.13),
                    blurRadius: 120,
                    spreadRadius: 35,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: const LinearGradient(
                                colors: [purple, blue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              color: Colors.white,
                              size: 27,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VOICE LAB',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'OFFLINE VOICE EFFECTS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white54,
                                    letterSpacing: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF191927),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  size: 13,
                                  color: Color(0xFF7CDAAF),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'OFFLINE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      const Text(
                        'YOUR VOICE,',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3,
                        ),
                      ),
                      const Text(
                        'YOUR STYLE.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: purple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ปรับแต่งเสียงในแบบที่เป็นคุณ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 25),
                      Center(
                        child: GestureDetector(
                          onTap: toggleAudio,
                          child: SizedBox(
                            width: 205,
                            height: 205,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 205,
                                  height: 205,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: purple.withValues(alpha: 0.12),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 175,
                                  height: 175,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: purple.withValues(alpha: 0.23),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 145,
                                  height: 145,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: enabled
                                          ? const [
                                              Color(0xFF7D50E8),
                                              Color(0xFF356FE7),
                                            ]
                                          : const [
                                              Color(0xFF25203D),
                                              Color(0xFF171B32),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (enabled ? blue : purple)
                                            .withValues(alpha: 0.25),
                                        blurRadius: 35,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                    ),
                                  ),
                                  child: busy
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : Icon(
                                          enabled
                                              ? Icons.graphic_eq_rounded
                                              : Icons.power_settings_new_rounded,
                                          size: 54,
                                          color: Colors.white,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        enabled ? 'VOICE ENGINE ACTIVE' : 'TAP TO ACTIVATE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                          color: enabled ? const Color(0xFF7CDAAF) : Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 30),
                      sectionTitle('เสียงสำเร็จรูป', 'เลือกโทนเสียงที่ต้องการ'),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: presets.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 9),
                          itemBuilder: (context, index) {
                            final item = presets[index];
                            final selected = preset == item;
                            return GestureDetector(
                              onTap: () => applyPreset(item),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  gradient: selected
                                      ? const LinearGradient(
                                          colors: [purple, blue],
                                        )
                                      : null,
                                  color: selected ? null : panel,
                                  border: Border.all(
                                    color: selected
                                        ? Colors.transparent
                                        : Colors.white.withValues(alpha: 0.07),
                                  ),
                                ),
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),
                      sectionTitle('ปรับแต่งเสียง', 'ควบคุมเอฟเฟกต์ด้วยตัวเอง'),
                      effectSlider(
                        title: 'Pitch / Tone',
                        description: 'ปรับเสียงให้ทุ้มหรือแหลม',
                        value: pitch,
                        min: -10,
                        max: 10,
                        valueText: pitch.toStringAsFixed(1),
                        onChanged: (v) => setState(() => pitch = v),
                      ),
                      effectSlider(
                        title: 'Robot',
                        description: 'เพิ่มเอฟเฟกต์เสียงหุ่นยนต์',
                        value: robot,
                        min: 0,
                        max: 100,
                        valueText: '${robot.round()}%',
                        onChanged: (v) => setState(() => robot = v),
                      ),
                      effectSlider(
                        title: 'Echo',
                        description: 'เพิ่มเสียงสะท้อน',
                        value: echo,
                        min: 0,
                        max: 100,
                        valueText: '${echo.round()}%',
                        onChanged: (v) => setState(() => echo = v),
                      ),
                      effectSlider(
                        title: 'Output Gain',
                        description: 'ปรับระดับความดังของเสียง',
                        value: gain,
                        min: 0.2,
                        max: 2,
                        valueText: '${(gain * 100).round()}%',
                        onChanged: (v) => setState(() => gain = v),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFF191626),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: purple.withValues(alpha: 0.22),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: purple,
                              size: 21,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'แอปนี้ต้องได้รับอนุญาตใช้ไมโครโฟนก่อน ระบบเสียง Native จะถูกเพิ่มในไฟล์ถัดไป เอฟเฟกต์นี้ไม่สามารถแทนไมค์ของ Discord หรือเกมอื่นทั่วทั้งระบบ Android ได้โดยตรง',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.6,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'VOICE LAB  •  OFFLINE BY DESIGN',
                          style: TextStyle(
                            color: Colors.white30,
                            fontSize: 9,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double progress;

  WavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int line = 0; line < 5; line++) {
      final path = Path();
      final centerY = size.height * (0.22 + line * 0.14);
      final amplitude = 8.0 + line * 3.0;

      for (double x = 0; x <= size.width; x += 3) {
        final y = centerY +
            math.sin(
                  (x / size.width * 2 * math.pi * 2) +
                      progress * 2 * math.pi +
                      line,
                ) *
                amplitude +
            math.sin(
                  (x / size.width * 2 * math.pi * 4) -
                      progress * 2 * math.pi,
                ) *
                4;

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      paint.color = (line.isEven ? purple : blue).withValues(
        alpha: 0.035 + line * 0.009,
      );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
