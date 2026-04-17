// ============================================================
//  Lumina LED Strip Enclosure — 19 × WS2812B
//
//  Parametric OpenSCAD. Edit PITCH to match your strip's LED
//  spacing (WS2812B 30 LEDs/m = 33.33mm, 60 LEDs/m = 16.66mm,
//  144 LEDs/m = 6.94mm). Default is 30/m — good to match
//  the white-key span on most 49-key controllers.
//
//  Prints in two pieces: base channel (opaque) + diffuser lid.
//  Use white PLA or PETG for the diffuser at 25–30% infill, 2
//  perimeters, for nice even light.
//
//  Rendering: Preview (F5). Export Base and Lid separately by
//  commenting out the other with // at the bottom.
// ============================================================

PITCH        = 33.33;   // center-to-center LED spacing, mm
LED_COUNT    = 19;
STRIP_W      = 10.5;    // WS2812B 30/m strip width
STRIP_H      = 3.0;     // including backing
WALL         = 1.6;
LID_T        = 1.2;     // diffuser lid thickness (thin = brighter)
BASE_H       = 6;
END_PAD      = 8;       // extra length beyond first/last LED
CABLE_D      = 5;       // exit hole diameter

TOTAL_L = PITCH * (LED_COUNT - 1) + 2 * END_PAD;
TOTAL_W = STRIP_W + 2 * WALL;

module base() {
  difference() {
    cube([TOTAL_L, TOTAL_W, BASE_H]);
    // Strip channel
    translate([END_PAD - PITCH/2, WALL, WALL])
      cube([TOTAL_L - 2*(END_PAD - PITCH/2), STRIP_W, STRIP_H + 0.4]);
    // Cable exit
    translate([0, TOTAL_W/2, BASE_H - CABLE_D/2 - 0.4])
      rotate([0,90,0]) cylinder(d=CABLE_D, h=WALL+0.2, $fn=30);
    // Lid lip rebate (inner shoulder)
    translate([WALL/2, WALL/2, BASE_H - LID_T])
      cube([TOTAL_L - WALL, TOTAL_W - WALL, LID_T + 0.01]);
  }
  // Mounting tabs with screw holes
  for (x = [6, TOTAL_L - 6]) {
    translate([x, -6, 0]) difference() {
      hull() {
        translate([-3, 0, 0]) cube([6, 0.01, BASE_H]);
        translate([-4, -4, 0]) cube([8, 4, BASE_H]);
      }
      translate([0, -2, -0.01]) cylinder(d=3.2, h=BASE_H+0.02, $fn=24);
    }
  }
}

module lid() {
  difference() {
    // Main slab
    translate([WALL/2, WALL/2, 0]) cube([TOTAL_L - WALL, TOTAL_W - WALL, LID_T]);
    // 19 pinholes over each LED for a sharper key-by-key look
    // (comment these out for a smooth continuous glow)
    /*
    for (i = [0 : LED_COUNT - 1]) {
      translate([END_PAD + i * PITCH, TOTAL_W/2, -0.01])
        cylinder(d=6, h=LID_T + 0.02, $fn=40);
    }
    */
  }
}

// ---- Output ----
base();
translate([0, TOTAL_W + 6, 0]) lid();
