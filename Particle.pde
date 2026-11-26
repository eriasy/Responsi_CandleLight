class Particle {
  PVector pos;
  PVector vel;
  float life;
  float diameter;
  
  Particle(float x, float y) {
    reset(x, y);
  }
  
  void update(float targetX, float targetY) {
    pos.add(vel);
    
    // DIPERBAIKI: Pengurangan life dibuat statis agar efek pudar lebih mulus
    life -= 8; 
    
    if (life <= 0) {
      reset(targetX, targetY);
    }
  }
  
  void showHand() {
    noStroke();
    fill(255, 100, 150, life); 
    circle(pos.x, pos.y, diameter);
  }
  
  void showFlame() {
    noStroke();
    fill(255, 180, 50, life); 
    circle(pos.x, pos.y, diameter);
  }
  
  void reset(float x, float y) {
    // DIPERBAIKI: Radius penyebaran sedikit difokuskan ke tengah
    pos = new PVector(x + random(-15, 15), y + random(-15, 15));
    // DIPERBAIKI: Kecepatan horizontal dikurangi agar tidak terlalu menyebar ke samping
    vel = new PVector(random(-0.6, 0.6), random(-3.5, -1.5)); 
    life = random(180, 255);
    // DIPERBAIKI: Ukuran partikel divariasikan lebih besar
    diameter = random(8, 18);
  }
}
