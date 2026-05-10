# 🩺 IoT Blood Sugar Health Monitor

> Real-time blood glucose monitoring — ESP32 on Wokwi → WebSocket → Flutter Web dashboard

![Flutter](https://img.shields.io/badge/Flutter-3.41-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![ESP32](https://img.shields.io/badge/ESP32-Wokwi-E7352C?style=for-the-badge&logo=espressif&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-Bridge-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![ngrok](https://img.shields.io/badge/ngrok-Tunnel-1F1E37?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=for-the-badge)

---

## ✨ What It Does

A potentiometer on a simulated ESP32 (Wokwi) acts as a blood sugar sensor. The readings stream live over WebSocket to a Flutter Web app running in Chrome — with animated gauges, trend graphs, and real-time alerts for dangerous glucose levels or emergency button presses.

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        WOKWI (Cloud)                             │
│  ┌─────────────┐                                                 │
│  │   ESP32     │  Potentiometer → ADC → sugar mg/dL             │
│  │  sketch.ino │  Button        → emergency alert               │
│  │             │  LCD           → local display                  │
│  │             │  LED + Buzzer  → danger indicators             │
│  └──────┬──────┘                                                 │
└─────────│────────────────────────────────────────────────────────┘
          │ WiFi (Wokwi-GUEST)
          ▼
┌─────────────────┐        ┌──────────────────┐
│   ngrok tunnel  │───────►│  Node.js server  │  port 8765
│  (public HTTPS) │        │   server.js      │
└─────────────────┘        └────────┬─────────┘
                                    │ WebSocket ws://
                                    ▼
                           ┌──────────────────┐
                           │  Flutter Web     │
                           │  Chrome Browser  │
                           │  Live Dashboard  │
                           └──────────────────┘
```

---

## 📁 Project Structure

```
health-bridge/
├── 📄 server.js              # Node.js WebSocket bridge
├── 📄 package.json           # Node dependencies
├── 📄 README.md
└── 📂 health_monitor/        # Flutter Web application
    ├── 📂 lib/
    │   └── 📄 main.dart      # Full UI + WebSocket client
    ├── 📂 web/               # Web entry point
    └── 📄 pubspec.yaml       # Flutter dependencies
```

---

## ⚙️ Hardware Components (Wokwi)

| Component | GPIO | Role |
|-----------|:----:|------|
| Potentiometer | 34 | Simulates blood sugar sensor (ADC 0–4095 → 60–400 mg/dL) |
| Push Button | 4 | Triggers emergency alert |
| LED (Red) | 26 | Blinks on danger state |
| Buzzer | 25 | 1000Hz tone on danger state |
| LCD 16×2 I2C | SDA 21 / SCL 22 | Shows level + status locally |

### 🩸 Blood Sugar Thresholds

| Range | Status | Hardware Response |
|-------|:------:|-------------------|
| `< 65 mg/dL` | 🔴 **LOW SUGAR** | LED blinks + Buzzer ON |
| `65 – 250 mg/dL` | 🟢 **Normal** | All OFF |
| `> 250 mg/dL` | 🔴 **HIGH SUGAR** | LED blinks + Buzzer ON |
| Button pressed | 🆘 **EMERGENCY** | LED blinks + Buzzer ON |

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Link |
|------|---------|------|
| Node.js | v18+ | [nodejs.org](https://nodejs.org) |
| Flutter | 3.x | [flutter.dev](https://docs.flutter.dev/get-started/install/windows/web) |
| ngrok | Free account | [ngrok.com](https://ngrok.com/download) |
| Wokwi | Free account | [wokwi.com](https://wokwi.com) |

---

### Step 1 — Clone the repository

```bash
git clone https://github.com/wess4sec/iot-health-monitor.git
cd iot-health-monitor
npm install
```

---

### Step 2 — Start the WebSocket bridge

Open **Terminal 1** — keep it open the whole time:

```bash
node server.js
```

```
✅ Bridge running on port 8765
```

---

### Step 3 — Open ngrok tunnel

Open **Terminal 2** — keep it open the whole time:

```bash
# First time only — paste your token from dashboard.ngrok.com
ngrok.exe config add-authtoken YOUR_NGROK_TOKEN

# Start tunnel
ngrok.exe http 8765
```

Copy the URL shown:
```
Forwarding  https://xxxx-xxx.ngrok-free.app  ->  http://localhost:8765
```

---

### Step 4 — Configure Wokwi sketch

In your Wokwi project, open `sketch.ino` and update:

```cpp
ws.beginSSL("xxxx-xxx.ngrok-free.app", 443, "/");
//           ^^^ paste your ngrok host here (no https://)
```

Make sure `libraries.txt` contains:
```
WebSockets
ArduinoJson
```

Press **▶ Play** in Wokwi. Serial monitor should print:
```
WiFi connected
```

---

### Step 5 — Find your PC local IP

```bash
ipconfig
# Look for: Carte réseau sans fil Wi-Fi → Adresse IPv4
# Example result: 192.168.1.5
```

---

### Step 6 — Configure the Flutter app

Open `health_monitor/lib/main.dart` and update **line 38**:

```dart
static const String _serverIP = '192.168.1.X'; // ← your IP here
```

---

### Step 7 — Run Flutter Web

Open **Terminal 3**:

```bash
cd health_monitor
flutter pub get
flutter run -d chrome
```

🎉 **Chrome opens with your live Health Monitor dashboard!**

---

## 📡 WebSocket Data Format

The ESP32 sends a JSON packet every **200ms**:

```json
{ "sugar": 142, "btn": false }
```

| Field | Type | Description |
|-------|------|-------------|
| `sugar` | `int` | Glucose level in mg/dL |
| `btn` | `bool` | Emergency button state |

---

## 🖥️ Flutter Dashboard Features

- 🔵 **Animated circular gauge** — color shifts cyan → orange → red with sugar level
- 📈 **Live 30-point trend graph** — scrolling history with highlighted danger zones
- ⚡ **Animated status card** — glowing border + blinking text on alerts
- 💡 **LED & Buzzer cards** — mirror the physical hardware state in real time
- 📶 **Connection indicator** — shows `ESP32 • Live` or `Reconnecting...`
- 🔄 **Auto-reconnect** — Flutter automatically reconnects if the server drops

---

## 🔧 Troubleshooting

| Problem | Fix |
|---------|-----|
| `flutter` not recognized | Add `C:\flutter\bin` to PATH, restart terminal |
| `ngrok` not recognized | Use `.\ngrok.exe` instead of `ngrok` |
| Flutter shows `Reconnecting...` | Verify `node server.js` is running and IP is correct in `main.dart` |
| Wokwi not sending data | Update ngrok URL in sketch, restart the simulation |
| `Duplicate mapping key` error | Remove the second `dependencies:` block in `pubspec.yaml` |
| Push takes forever | Make sure `flutter/`, `node_modules/`, `.zip` are in `.gitignore` |

---

## 🛠️ Tech Stack

| Technology | Role |
|------------|------|
| **ESP32 + Arduino C++** | Sensor reading, LCD, LED, Buzzer logic |
| **Wokwi** | Browser-based ESP32 simulation |
| **Node.js + ws** | WebSocket bridge server |
| **ngrok** | Secure public tunnel (Wokwi → local PC) |
| **Flutter Web** | Real-time dashboard UI |
| **ArduinoJson** | JSON serialization on the ESP32 |
| **web_socket_channel** | Flutter WebSocket client package |

---

## 👤 Author

**Abdel fatteh Hamdi**
- 🐙 GitHub: [@wess4sec](https://github.com/wess4sec)

---

## 📄 License

MIT © 2026 Abdel fatteh Hamdi
