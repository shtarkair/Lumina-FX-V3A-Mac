// ============================================================
//  Lumina FX — ESP32 LED Bridge
//  54 × WS2812B RGB LEDs driven via USB serial from Lumina,
//  grouped as 19 "notes" (one cluster of LEDs per piano key).
//
//  Wire:   DATA -> GPIO 10 (through a 470 ohm resistor)
//          5V   -> 5V      (external 5V / 3A supply recommended,
//                           GND must be common with ESP32 GND)
//          GND  -> GND
//
//  Protocol (binary, sent by Lumina):
//      0xFF 0xA1  <R1 G1 B1> <R2 G2 B2> ... <R19 G19 B19>  <checksum>
//      = 2 + 57 + 1 = 60 bytes per frame (19 logical notes).
//      checksum = XOR of all 57 RGB bytes.
//
//  IMPORTANT: Uses Serial0 (UART0, GPIO20 RX / GPIO21 TX) for data
//  from the CH340 USB-UART chip (/dev/cu.usbserial-*).
//  Serial (USB CDC) is only used if USB CDC On Boot is enabled.
//
//  Install libraries:
//      Adafruit NeoPixel       (via Arduino Library Manager)
//
//  Board:  "ESP32C3 Dev Module"
// ============================================================

#include <Adafruit_NeoPixel.h>

#define LED_PIN      10
#define NUM_NOTES    19
#define NUM_LEDS     54
#define BRIGHTNESS   160
#define FRAME_SIZE   60

// Use Serial0 = UART0 (GPIO20 RX, GPIO21 TX) = CH340 chip = /dev/cu.usbserial-*
// This works regardless of the "USB CDC On Boot" setting.
#define LUMINA_SERIAL Serial0

const uint8_t NOTE_WIDTHS[NUM_NOTES] = {
  2, 3, 3, 3, 3, 3, 3, 3, 3,
  2,
  3, 3, 3, 3, 3, 3, 3, 3, 2
}; // sum = 54

uint16_t NOTE_START[NUM_NOTES];
Adafruit_NeoPixel strip(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

uint8_t buf[FRAME_SIZE];
int bufLen = 0;
unsigned long lastFrameMs = 0;

void computeNoteStarts() {
  uint16_t acc = 0;
  for (int n = 0; n < NUM_NOTES; n++) {
    NOTE_START[n] = acc;
    acc += NOTE_WIDTHS[n];
  }
}

void setup() {
  LUMINA_SERIAL.begin(115200);
  computeNoteStarts();
  strip.begin();
  strip.setBrightness(BRIGHTNESS);
  strip.clear();
  strip.show();

  // Boot indicator: sweep amber across all LEDs, then dark.
  for (int i = 0; i < NUM_LEDS; i++) {
    strip.setPixelColor(i, strip.Color(50, 30, 0));
    strip.show();
    delay(10);
  }
  delay(150);
  strip.clear();
  strip.show();
}

void applyFrame(const uint8_t *rgb) {
  for (int n = 0; n < NUM_NOTES; n++) {
    uint8_t r = rgb[n*3];
    uint8_t g = rgb[n*3 + 1];
    uint8_t b = rgb[n*3 + 2];
    uint32_t c = strip.Color(r, g, b);
    uint16_t s = NOTE_START[n];
    uint8_t  w = NOTE_WIDTHS[n];
    for (uint8_t k = 0; k < w; k++) {
      if (s + k < NUM_LEDS) strip.setPixelColor(s + k, c);
    }
  }
  strip.show();
}

void loop() {
  while (LUMINA_SERIAL.available()) {
    uint8_t b = LUMINA_SERIAL.read();

    if (bufLen == 0 && b != 0xFF) continue;
    if (bufLen == 1 && b != 0xA1) { bufLen = 0; continue; }

    buf[bufLen++] = b;

    if (bufLen == FRAME_SIZE) {
      bufLen = 0;
      uint8_t chk = 0;
      for (int i = 2; i < 2 + NUM_NOTES * 3; i++) chk ^= buf[i];
      if (chk == buf[FRAME_SIZE - 1]) {
        applyFrame(buf + 2);
        lastFrameMs = millis();
      }
    }
  }

  // Watchdog: if no valid frame for 5 seconds, fade to black.
  if (lastFrameMs && millis() - lastFrameMs > 5000) {
    strip.clear();
    strip.show();
    lastFrameMs = 0;
  }
}
