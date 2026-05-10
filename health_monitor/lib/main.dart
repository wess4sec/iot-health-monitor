import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  runApp(const HealthMonitorApp());
}

class HealthMonitorApp extends StatelessWidget {
  const HealthMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      ),
      home: const HealthMonitorScreen(),
    );
  }
}

class HealthMonitorScreen extends StatefulWidget {
  const HealthMonitorScreen({super.key});

  @override
  State<HealthMonitorScreen> createState() => _HealthMonitorScreenState();
}

class _HealthMonitorScreenState extends State<HealthMonitorScreen>
    with TickerProviderStateMixin {

  // ── change this to your PC local IP ──────────────────────────────
  static const String _serverIP = '192.168.170.141';
  static const int    _serverPort = 8765;
  // ─────────────────────────────────────────────────────────────────

  int  sugarLevel      = 120;
  bool emergencyPressed = false;
  bool connected       = false;

  final List<int> sugarHistory = List.filled(30, 120);

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _connect();
  }

  void _connect() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://$_serverIP:$_serverPort'),
      );
      // Send a hello so server registers us as Flutter client
      _channel!.sink.add('flutter-hello');

      setState(() => connected = true);

      _channel!.stream.listen(
        (msg) {
          try {
            final data = jsonDecode(msg as String);
            setState(() {
              sugarLevel      = (data['sugar'] as num).toInt();
              emergencyPressed = data['btn'] as bool;
              sugarHistory.removeAt(0);
              sugarHistory.add(sugarLevel);
            });
          } catch (_) {}
        },
        onError: (_) => _scheduleReconnect(),
        onDone:  ()  => _scheduleReconnect(),
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    setState(() => connected = false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  bool get isHigh   => sugarLevel > 250;
  bool get isLow    => sugarLevel < 65;
  bool get isDanger => isHigh || isLow || emergencyPressed;

  String get statusText {
    if (emergencyPressed) return '!! EMERGENCY !!';
    if (isHigh)           return '!! HIGH SUGAR !!';
    if (isLow)            return '!! LOW SUGAR !!';
    return 'Normal';
  }

  Color get statusColor =>
      isDanger ? const Color(0xFFFF3D3D) : const Color(0xFF69FF47);

  Color get sugarColor {
    if (isHigh) return const Color(0xFFFF6B35);
    if (isLow)  return const Color(0xFFFF3D3D);
    return const Color(0xFF00E5FF);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, _) => Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.5,
                colors: isDanger
                    ? [const Color(0xFF1A0A0A), const Color(0xFF0A0E1A)]
                    : [const Color(0xFF0A1A1F), const Color(0xFF0A0E1A)],
              ),
            ),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildMainGauge(),
                        const SizedBox(height: 24),
                        _buildStatusCard(),
                        const SizedBox(height: 24),
                        _buildGraph(),
                        const SizedBox(height: 24),
                        _buildInfoCards(),
                        const SizedBox(height: 32),
                      ],
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

  // ── Header ───────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF00E5FF).withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Live dot
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: statusColor.withOpacity(0.15),
              border: Border.all(color: statusColor.withOpacity(0.5)),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isDanger ? 12 : 8, height: isDanger ? 12 : 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: statusColor,
                  boxShadow: [BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 8)],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Health Monitor',
                style: TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              Text(
                connected ? 'ESP32 • Live' : 'Reconnecting...',
                style: TextStyle(
                  color: connected
                      ? const Color(0xFF69FF47).withOpacity(0.8)
                      : const Color(0xFFFF6B35).withOpacity(0.8),
                  fontSize: 11, letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(
            connected ? Icons.wifi : Icons.wifi_off,
            color: connected
                ? const Color(0xFF00E5FF).withOpacity(0.8)
                : const Color(0xFFFF3D3D).withOpacity(0.6),
            size: 20,
          ),
        ],
      ),
    );
  }

  // ── Gauge ────────────────────────────────────────────────────────
  Widget _buildMainGauge() {
    final double percent = ((sugarLevel - 60) / (400 - 60)).clamp(0.0, 1.0);
    return ScaleTransition(
      scale: _pulseAnim,
      child: SizedBox(
        width: 220, height: 220,
        child: CustomPaint(
          painter: GaugePainter(percent: percent, color: sugarColor, isDanger: isDanger),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$sugarLevel',
                  style: TextStyle(
                    color: sugarColor, fontSize: 52, fontWeight: FontWeight.w900, height: 1,
                    shadows: [Shadow(color: sugarColor.withOpacity(0.5), blurRadius: 20)],
                  )),
                const Text('mg/dL',
                  style: TextStyle(color: Color(0xFF5A6A7A), fontSize: 13,
                      fontWeight: FontWeight.w500, letterSpacing: 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Status card ──────────────────────────────────────────────────
  Widget _buildStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(isDanger ? 0.6 : 0.3),
          width: isDanger ? 1.5 : 1,
        ),
        boxShadow: isDanger
            ? [BoxShadow(color: statusColor.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)]
            : null,
      ),
      child: Row(
        children: [
          Icon(isDanger ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: statusColor, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('STATUS',
                style: TextStyle(color: Colors.white.withOpacity(0.4),
                    fontSize: 11, letterSpacing: 1.5)),
              Text(statusText,
                style: TextStyle(color: statusColor, fontSize: 18,
                    fontWeight: FontWeight.w800, letterSpacing: 1)),
            ],
          ),
          const Spacer(),
          if (isDanger)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                  const SizedBox(width: 6),
                  Text('ALERT',
                    style: TextStyle(color: statusColor, fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Graph ────────────────────────────────────────────────────────
  Widget _buildGraph() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('GLUCOSE TREND',
                style: TextStyle(color: Color(0xFF5A6A7A), fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 2)),
              const Spacer(),
              Text('Live', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: CustomPaint(
              size: const Size(double.infinity, 80),
              painter: GraphPainter(data: sugarHistory, color: sugarColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label('60', const Color(0xFF5A6A7A)),
              _label('LOW<65', const Color(0xFFFF3D3D)),
              _label('HIGH>250', const Color(0xFFFF6B35)),
              _label('400', const Color(0xFF5A6A7A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String t, Color c) =>
      Text(t, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w600));

  // ── Info cards ───────────────────────────────────────────────────
  Widget _buildInfoCards() {
    return Row(
      children: [
        Expanded(child: _infoCard('LED', isDanger ? 'BLINKING' : 'OFF',
            Icons.lightbulb_outline,
            isDanger ? const Color(0xFFFFD700) : const Color(0xFF3A4A5A), isDanger)),
        const SizedBox(width: 12),
        Expanded(child: _infoCard('BUZZER', isDanger ? '1000Hz' : 'SILENT',
            Icons.volume_up_outlined,
            isDanger ? const Color(0xFFFF6B35) : const Color(0xFF3A4A5A), isDanger)),
        const SizedBox(width: 12),
        Expanded(child: _infoCard('RANGE', '65–250', Icons.tune,
            const Color(0xFF00E5FF), false)),
      ],
    );
  }

  Widget _infoCard(String label, String value, IconData icon, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.1) : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? color.withOpacity(0.4) : const Color(0xFF1E2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(label,
            style: TextStyle(color: Colors.white.withOpacity(0.3),
                fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value,
            style: TextStyle(
                color: active ? color : Colors.white.withOpacity(0.6),
                fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Painters ─────────────────────────────────────────────────────────

class GaugePainter extends CustomPainter {
  final double percent;
  final Color color;
  final bool isDanger;
  GaugePainter({required this.percent, required this.color, required this.isDanger});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    canvas.drawCircle(center, radius,
        Paint()..color = const Color(0xFF1E2A3A)..strokeWidth = 12
          ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    final p = Paint()..color = color..strokeWidth = 12
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    if (isDanger) p.maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -pi / 2, 2 * pi * percent, false, p);

    final tick = Paint()..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.5..style = PaintingStyle.stroke;
    for (int i = 0; i < 12; i++) {
      final a = (i / 12) * 2 * pi - pi / 2;
      canvas.drawLine(
        Offset(center.dx + (radius - 6) * cos(a), center.dy + (radius - 6) * sin(a)),
        Offset(center.dx + (radius + 6) * cos(a), center.dy + (radius + 6) * sin(a)),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(GaugePainter old) =>
      old.percent != percent || old.isDanger != isDanger;
}

class GraphPainter extends CustomPainter {
  final List<int> data;
  final Color color;
  static const int minVal = 60, maxVal = 400;
  GraphPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final W = size.width, H = size.height;

    // danger zones
    final hiY = H - ((250 - minVal) / (maxVal - minVal)) * H;
    final loY = H - ((65  - minVal) / (maxVal - minVal)) * H;
    final dp = Paint()..color = const Color(0xFFFF3D3D).withOpacity(0.05);
    canvas.drawRect(Rect.fromLTRB(0, 0, W, hiY), dp);
    canvas.drawRect(Rect.fromLTRB(0, loY, W, H), dp);

    // ref lines
    final rp = Paint()..color = Colors.white.withOpacity(0.05)..strokeWidth = 1;
    for (final v in [65, 120, 180, 250]) {
      final y = H - ((v - minVal) / (maxVal - minVal)) * H;
      canvas.drawLine(Offset(0, y), Offset(W, y), rp);
    }

    // build path
    final step = W / (data.length - 1);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i * step;
      final y = H - ((data[i] - minVal) / (maxVal - minVal)) * H;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    // fill
    final fill = Path.from(path)..lineTo(W, H)..lineTo(0, H)..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, W, H)));

    // line
    canvas.drawPath(path, Paint()
      ..color = color..strokeWidth = 2
      ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // last dot
    final lx = (data.length - 1) * step;
    final ly = H - ((data.last - minVal) / (maxVal - minVal)) * H;
    canvas.drawCircle(Offset(lx, ly), 5, Paint()..color = color);
    canvas.drawCircle(Offset(lx, ly), 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(GraphPainter old) => old.data != data;
}