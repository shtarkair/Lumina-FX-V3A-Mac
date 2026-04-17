# Lumina FX — ESP32 LED Bridge

Drives a **54-pixel WS2812B strip** over USB from Lumina, grouped into **19
logical notes** (one cluster per piano key). Each note's color = its
fixture/group patch color. Unassigned notes stay dark.

Group layout (widths, left→right across the 19 notes):

```
2, 3, 3, 3, 3, 3, 3, 3, 3, 2, 3, 3, 3, 3, 3, 3, 3, 3, 2   (sum = 54)
```

Short clusters of 2 LEDs sit at the ends and the exact center so the strip
tapers symmetrically. Edit `NOTE_WIDTHS[]` in the sketch if your wiring
differs — any arrangement summing to 54 works.

## 1. Hardware

- ESP32 dev board (any — ESP32-S3 with native USB is cleanest)
- WS2812B strip, **54 pixels**
- 5V 3A power supply (54 LEDs at full brightness can pull ~3A — USB alone is
  only safe at low brightness, ~120 or below)
- 470Ω resistor (in series with the data line)
- 1000µF electrolytic capacitor (across 5V / GND near the strip)
- USB cable to the Mac

### Wiring

```
ESP32 GPIO 5 ──[ 470Ω ]── DIN  (WS2812 data)
ESP32 5V    ──────────── 5V   (strip +)   ← also bridge to PSU 5V if external
ESP32 GND   ──────────── GND  (strip -)
```

Put the 1000µF cap between 5V and GND close to the first LED. Keep the data
wire short (< 30cm).

If you drive the strip from the ESP32's USB 5V alone, keep BRIGHTNESS low in
the sketch (≤120). For full brightness, use an external 5V PSU and share GND
with the ESP32.

## 2. Flash the sketch

1. Install the Arduino IDE (2.x).
2. Boards Manager → install **esp32 by Espressif Systems**.
3. Library Manager → install **Adafruit NeoPixel**.
4. Open `esp32-lumina-leds.ino`.
5. Tools → Board → **ESP32 Dev Module** (or **ESP32S3 Dev Module** if S3).
6. Tools → Port → your ESP32's port (e.g. `/dev/cu.usbserial-XXXX`).
7. Click Upload. On boot you'll see an amber sweep, then the strip goes dark.

If `GPIO 5` is taken by something on your board, change `LED_PIN` in the
sketch. Avoid GPIO 0/2/15 (boot strapping) and ADC2 pins (6–11).

## 3. Connect from Lumina

1. Plug the ESP32 into the Mac.
2. Launch Lumina → open the MIDI panel → scroll to **ESP32 LED STRIP (USB)**.
3. Click **SCAN**, pick your port from the dropdown (looks like
   `cu.usbserial-XXXX` or `cu.usbmodem…`), click **CONNECT**.
4. Click **TEST** — strip should flash a rainbow pattern.
5. Toggle **LED OUTPUT: ON**. Assigned fixtures will light their LED in the
   fixture's color. Unassigned fixtures = dark.

Port + enabled state are saved per machine. Next launch, Lumina auto-reconnects.

## 4. Mapping rules

- Lumina sends 19 logical note colors per frame. The sketch explodes each
  color across its cluster of 2 or 3 physical LEDs (see `NOTE_WIDTHS`).
- `noteIndex = (fixtureIndex - 1) % 19`
- Fixture 1 → note 1, fixture 20 → note 1, fixture 38 → note 1
- Color = `fx.color` (the swatch shown in the patch)
- If multiple fixtures land on the same note (because of wrapping), colors
  blend additively (clamped at 255 per channel)
- "Assigned" means the fixture is mapped directly to a MIDI note, OR it
  belongs to a group that is mapped to a note
- Brightness slider scales the whole strip; sketch-level BRIGHTNESS (in the
  .ino) is a hard cap on top of that for safety

## 5. Troubleshooting

- **Nothing on the strip, TEST does nothing** — wrong port selected, or the
  sketch isn't running. Open Arduino Serial Monitor on another machine to
  sanity-check. Try another USB cable (many are charge-only).
- **Colors look wrong (green shows as red etc.)** — your strip is RGB not
  GRB. In the sketch change `NEO_GRB` to `NEO_RGB` and re-upload.
- **LEDs flicker with long strips** — add a level shifter (74HCT125) between
  ESP32 3.3V logic and the 5V strip. For 54 LEDs it's borderline; add one if
  you see ghosting or wrong colors on LEDs farther down the strip.
- **First LED looks dim/corrupt** — add a second decoupling cap, or insert a
  dummy "sacrificial" LED in the data line.
- **macOS can't find the port** — install the Silicon Labs CP210x or CH340
  driver (depends on your ESP32's USB chip). ESP32-S3 needs no driver.
