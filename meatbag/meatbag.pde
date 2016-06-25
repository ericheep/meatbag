// Meatbag //<>// //<>// //<>// //<>// //<>// //<>//
// for Amy Golden

int[] active = new int[64];
int[] blink = new int[64];

import oscP5.*;
import netP5.*;

import processing.video.*;
Capture cam;

OscP5 oscP5;
NetAddress myRemoteLocation;

float overall = 0.90;
float scale = 1.0;
float aspect;

float xShake, yShake;
float xSharp, ySharp;
int index = 0;
int stroke = 15;
int copies = 1;
int loops = 1;
int NUM_PHOTOS;

PImage[] photos;

// oldPhoto
PShader grain;
PShader bleach;
PShader technicolor;

// badTV
PShader blur;
PShader contrast;
PShader sharp;
PShader hsv;

boolean blank = false;
boolean load = false;
boolean webcam = false;

// copy stuff
boolean one = true;
boolean two = false;
boolean four = false;
boolean nine = false;
boolean sixteen = false;
boolean sixtyfour = false;

boolean bleachActive = true;
boolean grainActive = true;
boolean technicolorActive = true;
boolean blurActive = true;
boolean contrastActive = true;
boolean sharpActive = true;

void setup() {
  // webcam
  String[] cameras = Capture.list();
  if (cameras.length == 0) {
    exit();
  } else {
    cam = new Capture(this, cameras[0]);
  }  

  fullScreen(P3D);
  //size(750, 750, P3D);
  noCursor();

  strokeWeight(stroke);
  imageMode(CENTER);
  rectMode(CENTER);

  /// comm stuff
  oscP5 = new OscP5(this, 12001);

  // badTV shaders
  blur = loadShader("blur.glsl");
  sharp = loadShader("sharp.glsl");
  contrast = loadShader("contrast.glsl");

  // badTV resolutions
  sharp.set("resolution", float(width), float(height));
  contrast.set("resolution", float(width), float(height));

  // badTV settings
  blur.set("scale_factor", 1.1);
  sharp.set("mouse", 0.3, 0.4);
  contrast.set("contrast", 1.3);

  // oldPhoto shaders
  bleach = loadShader("bleach.glsl");
  technicolor = loadShader("technicolor1.glsl");
  grain = loadShader("grain.glsl");

  // oldPhoto settings
  bleach.set("amount", 0.4);
  technicolor.set("amount", 0.8);
  grain.set("grainamount", 0.1);
}

void draw() {
  background(0);

  if (one) {
    copies = 1;
    scale = 1.0;
    loops = 1;
  }
  if (two) {
    copies = 2;
    scale = 0.5;
    loops = 2;
  }
  if (four) {
    copies = 4;
    scale = 0.5;
    loops = 2;
  }
  if (nine) {
    copies = 9;
    scale = 0.33;
    loops = 3;
  }
  if (sixteen) { 
    copies = 16;
    scale = 0.25;
    loops = 4;
  }
  if (sixtyfour) {
     copies = 64;
     scale = 0.125;
     loops = 8;
  }

  if (webcam) {
    if (cam.available() == true) {
      cam.read();
    }
  }

  // make it small
  scale(scale);

  if (blank) {
    fill(0, 0, 0);
    rect(width * 0.5, height * 0.5, width, height);
  } else {
    int counter = 0;
    for (int i = 0; i < loops; i++) {
      for (int j = 0; j < loops; j++) {
        if (active[counter] == 1 && blink[counter] == 1) {
          pushMatrix();

          if (!two) {
            translate(i * width + random(-xShake, xShake), j * height + random(-yShake, yShake));
          } else if (two) { 
            translate(i * width + random(-xShake, xShake), height * 0.5 + random(-yShake, yShake));
          }

          if (webcam) {
            aspect = float(cam.height)/cam.width;
            //image(cam, height * 0.5, width * 0.5, height * overall, height * aspect * overall);
            image(cam, width * 0.5, height * 0.5, height * overall, height * aspect * overall);
            //set(height * 0.5, width * 0.5, height * overall, height * aspect * overall, cam);
            noFill();
            blurryRectangle(height * overall, height * aspect * overall);
          } else if (load) {
            grain.set("dimensions", float(photos[index].width), float(photos[index].height));

            if (photos[index].width > photos[index].height) {
              aspect = float(photos[index].height)/photos[index].width;
            } else {
              aspect = float(photos[index].width)/photos[index].height;
            }
            image(photos[index], width * 0.5, height * 0.5, height * overall, height * aspect * overall);

            // rounded blurry corners
            noFill();
            blurryRectangle(height * overall, height * aspect * overall);
          }
          popMatrix();
        }
        counter++;
      }
    }
  }

  sharp.set("mouse", random(-xSharp, xSharp), random(-ySharp, ySharp));
  if (bleachActive) filter(bleach);
  if (grainActive) filter(grain);
  if (technicolorActive) filter(technicolor);
  if (blurActive) filter(blur);
  if (contrastActive) filter(contrast);
  if (sharpActive) filter(sharp);
}

void blurryRectangle(float w, float h) {
  for (float i = 0; i < 20; i = i + 0.1) {
    stroke(0, 0, 0, 20 - i);
    rect(width * 0.5, height * 0.5, w - i, h - i, stroke);
  }
}

void oscEvent(OscMessage msg) {
  if (msg.checkAddrPattern("/webcam") == true) {
    if (msg.get(0).intValue() == 1) { 
      cam.start();
      webcam = true;
    } else if (msg.get(0).intValue() == 0) {
      cam.stop();
      webcam = false;
    }
  }
  if (msg.checkAddrPattern("/xShake") == true) {
    xShake = msg.get(0).floatValue();
  }
  if (msg.checkAddrPattern("/yShake") == true) {
    yShake = msg.get(0).floatValue();
  }
  if (msg.checkAddrPattern("/xSharp") == true) {
    xSharp = msg.get(0).floatValue();
  }
  if (msg.checkAddrPattern("/ySharp") == true) {
    ySharp = msg.get(0).floatValue();
  }
  if (msg.checkAddrPattern("/index") == true) {
    index = msg.get(0).intValue();
  }
  if (msg.checkAddrPattern("/active") == true) {
    active[msg.get(0).intValue()] = msg.get(1).intValue();
  }
  // copies
  if (msg.checkAddrPattern("/copies") == true) { 
    if (msg.get(0).intValue() == 1) {
      one = true;
    } else {
      one = false;
    }
    if (msg.get(0).intValue() == 2) {
      two = true;
    } else {
      two = false;
    }
    if (msg.get(0).intValue() == 4) {
      four = true;
    } else {
      four = false;
    }
    if (msg.get(0).intValue() == 9) {
      nine = true;
    } else {
      nine = false;
    }
    if (msg.get(0).intValue() == 16) {
      sixteen = true;
    } else {
      sixteen = false;
    }
    if (msg.get(0).intValue() == 64) {
      sixtyfour = true;
    } else {
      sixtyfour = false;
    }
  }
  if (msg.checkAddrPattern("/blank") == true) {
    if (msg.get(0).intValue() == 1) {
      blank = true;
    } else if (msg.get(0).intValue() == 0) {
      blank = false;
    }
  }
  if (msg.checkAddrPattern("/blink") == true) {
    blink[msg.get(0).intValue()] = msg.get(1).intValue();
  }
  if (msg.checkAddrPattern("/NUM_PHOTOS") == true) {
    NUM_PHOTOS = msg.get(0).intValue();
    photos = new PImage[NUM_PHOTOS];
  }
  if (msg.checkAddrPattern("/filename") == true) {
    photos[msg.get(0).intValue()] = loadImage(msg.get(1).stringValue());
    if (msg.get(0).intValue() == NUM_PHOTOS - 1) {
      load = true;
    };
  }
}