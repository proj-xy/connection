import codeanticode.syphon.*;
import processing.sound.*;

boolean calibration = false;

PGraphics canvas;
SyphonServer server;

SoundFile bgm;

int rows = 5;
int cols = 5;

int scale = 6;
int tileSize = 40 * scale;
int tileEdge = 4 * scale;
int frameWidth = 6 * scale;

String tileKeys = "abcdefghijklmnopqrstuvwxy";
int tiles = tileKeys.length();

StringList activeTileKey = new StringList();
boolean[] activeTile = new boolean[tiles];

Tile[] tileArray = new Tile[tiles];
boolean[][][] junctions = new boolean[rows + 1][cols + 1][4];
int[] vertical = {0, 2};
int[] horizontal = {1, 3};

int tileCopy = 4;
float decay = 0.6;
int tileAlpha = 8;
int tileDimOut = 32;
color[] tileColors = {
  color(150, 150, 255), // a 1
  color(255, 150, 255), // b 2
  color(150, 150, 255), // c 3
  color(255, 150, 255), // d 4
  color(150, 150, 255), // e 5
  color(255, 150, 255), // f 6
  color(150, 255, 150), // g 7
  color(255, 255, 150), // h 8
  color(150, 255, 150), // i 9
  color(255, 150, 255), // j 10
  color(150, 150, 255), // k 11
  color(255, 255, 150), // l 12
  color(150, 255, 255), // m 13
  color(255, 255, 150), // n 14
  color(150, 150, 255), // o 15
  color(255, 150, 255), // p 16
  color(150, 255, 150), // q 17
  color(255, 255, 150), // r 18
  color(150, 255, 150), // s 19
  color(255, 150, 255), // t 20
  color(150, 150, 255), // u 21
  color(255, 150, 255), // v 22
  color(150, 150, 255), // w 23
  color(255, 150, 255), // x 24
  color(150, 150, 255), // y 25
};

color frameColor = color(50);

int cursorAlpha = 160;
int cursorSize = 2;
int cursorMemory = 100;
float cursorVelocity = 30.0;

void setup() {
  size(1380, 1380, P3D);
  background(0);
  frameRate(30);
  smooth(8);
  
  canvas = createGraphics(1380, 1380, P3D);
  server = new SyphonServer(this, "Processing Syphon");
  
  initTile();
  initJunctions();
  loopSound();
}

void draw() {
  canvas.beginDraw();
  canvas.noFill();
  displayFrame();
  for (Tile tile : tileArray) {
    tile.checkActivate();
    tile.displayTile();
    tile.displayCursor();
  }
  canvas.endDraw();
  image(canvas, 0, 0);
  server.sendImage(canvas);
}

class Tile {

  int id;
  PVector xy;
  Boolean isActivated;
  String tileKey;
  
  color tileColor;
  color cursorColor;

  boolean[] connection = new boolean[tiles];
  int[] cursorDirections = new int[tiles];
  PVector[] cursorXYs = new PVector[tiles];
  float[][][] cursorHistory = new float[tiles][cursorMemory][2];
  
  SoundFile sfx = new SoundFile(connection.this, "connection_effect.wav");
  boolean activeSound = false;

  Tile(int idInput, PVector xyInput) {
    xy = xyInput;
    id = idInput;
    isActivated = false;
    tileKey = str(tileKeys.charAt(id));
    tileColor = tileColors[id];
    initializeCursorColor();
    for (int i = 0; i < tiles; i++) {
      connection[i] = false;
      for (int j = 0; j < cursorMemory; j++) {
        cursorHistory[i][j][0] = -float(width);
        cursorHistory[i][j][1] = -float(height);
      }
    }
  }

  void checkActivate() {
    isActivated = activeTile[id];
  }

  void displayTile() {
    float x = xy.x;
    float y = xy.y;
    float rO = tileSize / 2.0;
    float rI = rO - tileEdge / 2.0;
    
    canvas.strokeWeight(tileEdge); 
    if (calibration) {
      canvas.stroke(255);
      canvas.textSize(12 * scale);
      canvas.text(tileKey, x - 3 * scale, y + 3 * scale);
      drawTile(x, y, rO, rI, tileEdge);
    } else {
      if (isActivated) {
        if (!sfx.isPlaying() && !activeSound) {
          activeSound = true;
          sfx.play();
        }
        canvas.stroke(tileColor, tileAlpha);
      } else {
        activeSound = false;
        canvas.stroke(0, tileDimOut);
      }
      drawTile(x, y, rO, rI, tileEdge);      
      
      for (int i = 0; i < tileCopy; i++) {
        rO -= tileEdge * pow(decay, i);
        rI = rO - tileEdge * pow(decay, i + 1) / 2;
        canvas.strokeWeight(tileEdge * pow(decay, i + 1)); 
        if (isActivated) {
          canvas.stroke(tileColor, tileAlpha * pow(decay, i + 1));
          drawTile(x, y, rO, rI, tileEdge * pow(decay, i + 1));
        } else {
          canvas.stroke(0, tileDimOut);
          drawTile(x, y, rO, rI, tileEdge * pow(decay, i + 1));
        }
      }
    }
  }

  void drawTile(float x, float y, float rO, float rI, float edge) {
    canvas.line(x - rO, y - rI, x + rO - edge, y - rI);
    canvas.line(x + rI, y - rO, x + rI, y + rO - edge);
    canvas.line(x + rO, y + rI, x - rO + edge, y + rI);
    canvas.line(x - rI, y + rO, x - rI, y - rO + edge);
  }

  void displayCursor() {
    if (isActivated) {
      int cursorCount = countActiveTileKey() - 1;
      if (cursorCount >= 1) {
        for (int t = 0; t < tiles; t++) {
          if (t != id && activeTile[t]) {
            if (!connection[t]) {
              PVector targetXY = convertXY(t);
              PVector currentXY = cursorXYs[t];
              float distance = PVector.dist(targetXY, currentXY);
              if (distance > tileSize / 2 + frameWidth / 2 + 1.0) {
                moveCursor(t, targetXY, false);
              } else {
                moveCursor(t, targetXY, true);
              }
            }
            drawCursorHistory(t);
          } else {
            initializeCursor(t);
          }
        }
      } else {
        for (int i = 0; i < tiles; i++) {
          initializeCursor(i);
          initializeCursorColor();
        }
      } 
    } else {
      for (int i = 0; i < tiles; i++) {
        initializeCursor(i);
        initializeCursorColor();
      }
    }
  }
  
  void moveCursor(int t, PVector targetXY, boolean lastMove) {
    PVector cursorXY = cursorXYs[t];
    PVector nextCursorXY;
    if (lastMove) {
      connection[t] = true;
      float lossX = cursorXY.x - targetXY.x;
      float lossY = cursorXY.y - targetXY.y;
      float lastX = cursorXY.x;
      float lastY = cursorXY.y;
      if (abs(lossX) > abs(lossY)) {
        if (lossX > 0) {
          lastX -= frameWidth / 2;
        } else {
          lastX += frameWidth / 2;
        }
      } else {
        if (lossY > 0){
          lastY -= frameWidth / 2;
        } else {
          lastY += frameWidth / 2;
        }
      }
      nextCursorXY = new PVector(lastX, lastY);
    } else {
      int cursorDirection = cursorDirections[t];
      float updateX = cursorXY.x;
      float updateY = cursorXY.y;
      if (cursorDirection == 0) {
        updateY -= cursorVelocity;
      } else if (cursorDirection == 1) {
        updateX -= cursorVelocity;
      } else if (cursorDirection == 2) {
        updateY += cursorVelocity;
      } else {
        updateX += cursorVelocity;
      }
      nextCursorXY = new PVector(updateX, updateY);
      int[] junctionIndex = findJunction(nextCursorXY);
      int junctionRow = junctionIndex[0];
      int junctionCol = junctionIndex[1];
      if (junctionRow >= 0 && junctionCol >= 0) {
        nextCursorXY = convertJunctionXY(junctionIndex);
        IntList candidates = new IntList();
        for (int k = 0; k < 4; k++) {
          if (junctions[junctionRow][junctionCol][k]) {
            int reverseDirection = (cursorDirection + 2) % 4;
            if (k != reverseDirection) {
              if (k == 0 && targetXY.y < nextCursorXY.y) {
                candidates.append(k);
              }
              if (k == 1 && targetXY.x < nextCursorXY.x) {
                candidates.append(k);
              }
              if (k == 2 && targetXY.y >= nextCursorXY.y) {
                candidates.append(k);
              }
              if (k == 3 && targetXY.x >= nextCursorXY.x) {
                candidates.append(k);
              }
            }
          }
        }
        int randomSelect = int(random(candidates.size()));
        int candidate = candidates.get(randomSelect);
        cursorDirections[t] = candidate;
      }
    }
    cursorXYs[t] = nextCursorXY;
    
    // shift history to left
    for (int j = 1; j < cursorMemory; j++) {
      cursorHistory[t][j - 1][0] = cursorHistory[t][j][0];
      cursorHistory[t][j - 1][1] = cursorHistory[t][j][1];
    }
    cursorHistory[t][cursorMemory - 1][0] = nextCursorXY.x;
    cursorHistory[t][cursorMemory - 1][1] = nextCursorXY.y;   
  }
  
  void drawCursorHistory(int t) {
    canvas.stroke(cursorColor, cursorAlpha);
    canvas.strokeWeight(cursorSize * scale);
    canvas.beginShape();
    for (int j = 0; j < cursorMemory; j ++) {
      float[] cursor = cursorHistory[t][j];
      if (cursor[0] > -width && cursor[1] > -height) {
        canvas.vertex(cursor[0], cursor[1]);
      }
    }
    canvas.endShape();
  }

  void initializeCursor(int t) {
    int randomEdge = int(random(0, 4));
    int randomDirection = int(random(2));
    int initialDirection;
    float primaryX = xy.x;
    float primaryY = xy.y;
    float secondaryX = xy.x;
    float secondaryY = xy.y;
    if (randomEdge == 0) {
      primaryY -= tileSize / 2.0;
      secondaryY -= (tileSize + frameWidth) / 2.0;
      initialDirection = horizontal[randomDirection];
    } else if (randomEdge == 1) {
      primaryX -= tileSize / 2.0;
      secondaryX -= (tileSize + frameWidth) / 2.0;
      initialDirection = vertical[randomDirection];
    } else if (randomEdge == 2) {
      primaryY += tileSize / 2.0;
      secondaryY += (tileSize + frameWidth) / 2.0;
      initialDirection = horizontal[randomDirection];
    } else {
      primaryX += tileSize / 2.0;
      secondaryX += (tileSize + frameWidth) / 2.0;
      initialDirection = vertical[randomDirection];
    }
    
    // reset cursor history
    for (int i = 0; i < cursorMemory; i++) {
      cursorHistory[t][i][0] = -float(width);
      cursorHistory[t][i][1] = -float(height);
    }
    cursorHistory[t][cursorMemory - 2][0] = primaryX;
    cursorHistory[t][cursorMemory - 2][1] = primaryY;
    cursorHistory[t][cursorMemory - 1][0] = secondaryX;
    cursorHistory[t][cursorMemory - 1][1] = secondaryY;
    cursorXYs[t] = new PVector(secondaryX, secondaryY);
    cursorDirections[t] = initialDirection;
    connection[t] = false;
  }
  
  void initializeCursorColor() {
    cursorColor = color(
      random(100, 255), 
      random(100, 255), 
      random(100, 255)
    );
  }
}

void initTile() {
  for (int i = 0; i < rows; i++) {
    for (int j = 0; j < cols; j++) {
      int id = i * rows + j;
      float x = (frameWidth + tileSize) * (j + 0.5);
      float y = (frameWidth + tileSize) * (i + 0.5);
      PVector xy = new PVector(x, y);
      tileArray[id] = new Tile(id, xy);
    }
  }
}

void initJunctions() {
  for (int i = 0; i < rows + 1; i++) {
    for (int j = 0; j < cols + 1; j++) {
      if (i == 0) {
        junctions[i][j][2] = true;
      } else if (i == rows) {
        junctions[i][j][0] = true;
      } else {
        junctions[i][j][0] = true;
        junctions[i][j][2] = true;
      }
  
      if (j == 0) {
        junctions[i][j][3] = true;
      } else if (j == cols) {
        junctions[i][j][1] = true;
      } else {
        junctions[i][j][1] = true;
        junctions[i][j][3] = true;
      }
    }
  }
}

int findIndex(String keyString, StringList targetList) {
  for (int i = 0; i < targetList.size(); i++) {
    if (targetList.get(i).equals(keyString)) {
      return i;
    }
  }
  return -1;
}

void keyPressed() {
  if (tileKeys.indexOf(key) >= 0) {
    if (!activeTileKey.hasValue(str(key))) {
      setTileStatus(true);
      activeTileKey.append(str(key));

    }
  }
}

void keyReleased() {
  if (tileKeys.indexOf(key) >= 0) {
    String date = year() + "/" + month() + "/" + day();
    String time = hour() + ":" + minute() + ":" + second();
    println(date, time, "key released:", key);
    setTileStatus(false);
    int popKeyIndex = findIndex(str(key), activeTileKey);
    activeTileKey.remove(popKeyIndex);
  }
}

void setTileStatus(boolean isActivated) {
  String keyString = str(key);
  int keyIndex = tileKeys.indexOf(keyString);
  if (keyIndex >= 0) {
    activeTile[keyIndex] = isActivated;
  }
}

int countActiveTileKey() {
  int count = 0;
  for (int i = 0; i < tiles; i++) {
    if (activeTile[i]) {
      count += 1;
    }
  }
  return count;
}

PVector convertXY(int index) {
  int j = index % rows;
  int i = index / rows;
  float x = (tileSize + frameWidth) * (j + 0.5);
  float y = (tileSize + frameWidth) * (i + 0.5);;
  PVector xy = new PVector(x, y);
  return xy;
}

PVector convertJunctionXY(int[] junctionIndex) {
  float x = (tileSize + frameWidth) * junctionIndex[1];
  float y = (tileSize + frameWidth) * junctionIndex[0];
  PVector xy = new PVector(x, y);
  return xy;
}

int[] findJunction(PVector cursorXY) {
  int[] cornerIndex = {-1, -1};
  for (int i = 0; i < rows + 1; i++) {
    float cornerY = (tileSize + frameWidth) * i;
    float distanceY = abs(cornerY - cursorXY.y);
    if (distanceY < cursorVelocity) {
      for (int j = 0; j < cols + 1; j++) {
        float cornerX = (tileSize + frameWidth) * j;
        float distanceX = abs(cornerX - cursorXY.x);
        if (distanceX < cursorVelocity) {
          cornerIndex[0] = i;
          cornerIndex[1] = j;
          return cornerIndex;
        }
      }
      return cornerIndex;
    }
  }
  return cornerIndex;
}

void loopSound() {
  bgm = new SoundFile(this, "connection_bgm.wav");
  bgm.loop();
}

void displayFrame() {
  canvas.stroke(frameColor);
  canvas.strokeWeight(frameWidth);
  canvas.beginShape(LINES);
  for (int i = 0; i <= rows; i++) {
    canvas.vertex(0, i * (tileSize + frameWidth));
    canvas.vertex(width, i * (tileSize + frameWidth));
  }
  for (int i = 0; i <= cols; i++) {
    canvas.vertex(i * (tileSize + frameWidth), 0);
    canvas.vertex(i * (tileSize + frameWidth), height);
  }
  canvas.endShape();
}
