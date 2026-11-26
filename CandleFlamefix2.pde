import processing.video.*;
import gab.opencv.*;

Capture cam;
OpenCV opencv;
PImage candleImg;

int WIN_W = 960, WIN_H = 720;
int CAM_W = 640, CAM_H = 480;
int DETECT_W = 160, DETECT_H = 120;

float candleW = 260;
float candleH = 340;
float candleX, candleY;
float candleAlpha = 175;

// ---- 3 sumbu lilin ----
// ---- 3 sumbu lilin: kiri, tengah, kanan ----
float[] wickFracX = {0.17, 0.50, 0.83}; 
float[] wickFracY = {0.14, 0.02, 0.14}; // Angka dikecilkan agar titik naik ke pucuk lilin
float[] wickX = new float[3];
float[] wickY = new float[3];

float igniteRadius = 35; // Lingkaran jadi lebih kecil, harus pas di ujung baru menyala
float carryRadius  = 160; // Ini biarkan saja tidak apa-apa

boolean[] lit = {false, false, false};
int[] igniteStreak = {0, 0, 0};
// DIPERBAIKI: Mengurangi waktu yang dibutuhkan agar lilin lebih cepat menyala (dari 6 menjadi 3)
int igniteStreakNeeded = 3;

ArrayList<Particle>[] flame = new ArrayList[3];
ArrayList<Particle> handParticles;

PImage prevFrame;
float handX = -1, handY = -1;
// Variabel baru untuk memperhalus (smooth) pergerakan partikel tangan
float smoothHandX = -1, smoothHandY = -1; 
boolean handDetected = false;
int minMotionPixels = 25;

int extinguishStreak = 0;
int extinguishStreakNeeded = 4;
int totalMotionExtinguishThreshold = 900;

int warmupFrames = 60;

void setup() {
  size(960, 720);

  candleImg = loadImage("Candle.png");

  String[] cameras = Capture.list();
  cam = new Capture(this, CAM_W, CAM_H);
  cam.start();
  opencv = new OpenCV(this, DETECT_W, DETECT_H);

  for (int i = 0; i < 3; i++) {
    flame[i] = new ArrayList<Particle>();
    for (int k = 0; k < 150; k++) flame[i].add(new Particle(0, 0));
  }
  
  handParticles = new ArrayList<Particle>();
  for (int i = 0; i < 200; i++) {
    handParticles.add(new Particle(0, 0));
  }

  candleX = width / 2.0 - candleW / 2.0;
  candleY = height * 0.35;
  hitungWick();
}

void hitungWick() {
  for (int i = 0; i < 3; i++) {
    wickX[i] = candleX + candleW * wickFracX[i];
    wickY[i] = candleY + candleH * wickFracY[i];
  }
}

void captureEvent(Capture c) {
  c.read();
}

void draw() {
  background(0);

  if (cam.width > 0) {
    pushMatrix();
    scale(-1, 1);
    translate(-width, 0);
    imageMode(CORNER);
    image(cam, 0, 0, width, height);
    popMatrix();
  }

  detectHandMotion();

  imageMode(CORNER);
  tint(255, candleAlpha);
  image(candleImg, candleX, candleY, candleW, candleH);
  noTint();

  blendMode(ADD);
  
  // 1. Tampilkan partikel tangan menggunakan koordinat yang sudah di-SMOOTH
  if (handDetected) {
    for (Particle p : handParticles) {
      p.update(smoothHandX, smoothHandY);
      p.showHand(); 
    }
  }

  // 2. Tampilkan partikel api lilin JIKA menyala
  for (int i = 0; i < 3; i++) {
    updateAndShowFlame(i);
  }
  
  blendMode(BLEND);

  drawIndicators();
}

void updateAndShowFlame(int i) {
  if (lit[i]) {
    for (Particle p : flame[i]) {
      p.update(wickX[i], wickY[i]);
      p.showFlame(); 
    }
  }
}

void detectHandMotion() {
  if (cam.width == 0) return;

  if (frameCount < warmupFrames) {
    PImage warm = cam.get();
    warm.resize(DETECT_W, DETECT_H);
    opencv.loadImage(warm);
    prevFrame = opencv.getSnapshot();
    return;
  }

  PImage small = cam.get();
  small.resize(DETECT_W, DETECT_H);
  opencv.loadImage(small);
  PImage gray = opencv.getSnapshot();

  if (prevFrame == null) {
    prevFrame = gray;
    return;
  }

  opencv.diff(prevFrame);
  PImage diffImg = opencv.getSnapshot();
  diffImg.loadPixels();

  float sumX = 0, sumY = 0, weight = 0;
  int totalMotion = 0;

  for (int y = 0; y < diffImg.height; y++) {
    for (int x = 0; x < diffImg.width; x++) {
      float b = brightness(diffImg.pixels[y * diffImg.width + x]);
      if (b > 40) {
        sumX += x * b;
        sumY += y * b;
        weight += b;
        totalMotion++;
      }
    }
  }

  // Jika ada pergerakan
  if (weight > 0 && totalMotion > minMotionPixels) {
    handDetected = true;
    
    // Perhitungan mentah
    float rawHandX = (sumX / weight) * (width / (float) DETECT_W);
    float targetX = width - rawHandX; 
    float targetY = (sumY / weight) * (height / (float) DETECT_H);
    
    // DIPERBAIKI: Memperhalus gerak menggunakan lerp (Linear Interpolation)
    if (smoothHandX == -1) {
      smoothHandX = targetX;
      smoothHandY = targetY;
    } else {
      // Nilai 0.2 menentukan kehalusan (semakin kecil = semakin lambat meluncur)
      smoothHandX = lerp(smoothHandX, targetX, 0.2); 
      smoothHandY = lerp(smoothHandY, targetY, 0.2);
    }
    
  } else {
    handDetected = false;
  }

  // Cek sumbu menggunakan koordinat yang sudah dihaluskan
  for (int i = 0; i < 3; i++) {
    if (lit[i]) continue; 
    // Menggunakan smoothHandX & Y untuk toleransi yang lebih stabil
    boolean dekatSumbu = handDetected && dist(smoothHandX, smoothHandY, wickX[i], wickY[i]) < igniteRadius;
    if (dekatSumbu) {
      igniteStreak[i]++;
    } else {
      igniteStreak[i] = 0;
    }
    if (igniteStreak[i] >= igniteStreakNeeded) {
      lit[i] = true;
      igniteStreak[i] = 0;
    }
  }

  // Kibasan besar = tiup semua lilin
  if (totalMotion > totalMotionExtinguishThreshold) {
    extinguishStreak++;
  } else {
    extinguishStreak = 0;
  }
  if (extinguishStreak >= extinguishStreakNeeded) {
    for (int i = 0; i < 3; i++) lit[i] = false;
    extinguishStreak = 0;
  }

  prevFrame = gray;
}

void drawIndicators() {
  noFill();
  strokeWeight(2);
  for (int i = 0; i < 3; i++) {
    stroke(lit[i] ? color(0, 255, 0) : color(0, 180, 0));
    // Ukuran lingkaran hijau menyesuaikan radius yang baru
    ellipse(wickX[i], wickY[i], igniteRadius * 2, igniteRadius * 2);
  }
}
