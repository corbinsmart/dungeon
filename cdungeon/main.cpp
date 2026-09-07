#include <iostream>
#include <fstream>
#include <string>
#include <cctype>
#include <unistd.h>
// #include <sstream>
#include <vector>
using namespace std;

/////////
// struct
/////////
struct coord2D {
  int x;
  int y;
};

////////
// const
////////
const string MOVE_CH = "wasd";
const string SHOOT_CH = "<>^v";

///////////////
// global state
///////////////
string name;
string room;
int room_width;
int room_height;
int player_x;
int player_y;
int turn_number = 0;
bool alive = true;
bool get_input = true;

///////
// util
///////
int random_int(int min, int max) {
  return min + rand() % max;
}
int roll_d20() {
  return random_int(1,20);
}
coord2D random_coord() {
  coord2D coord;
  coord.x = random_int(1, room_width-3);
  coord.y = random_int(1, room_height-3);
  return coord;
}
void wait(float seconds) {
  int microsec = (int)(seconds*1000000);
  usleep(microsec);
}
int coord_to_str_index(int x, int y) {
  return y * room_width + x;
}
coord2D str_index_to_coord(int index) {
  coord2D coord;
  coord.x = index % room_width;
  coord.y = index / room_width;
  return coord;
}
bool in_bounds(int x, int y) {
  return x >= 0 && x < room_width-1 &&
         y >= 0 && y < room_height;
}
void set_char_at(char ch, int x, int y) {
  if (!in_bounds(x, y))
    return;

  int index = coord_to_str_index(x, y);
  room[index] = ch;
}
char char_at(int x, int y) {
  if (!in_bounds(x, y))
    return -1;
  
  int index = coord_to_str_index(x, y);
  return room[index];
}
bool is_adjacent_to(char ch, int x, int y) {
  char above = char_at(x, y-1);
  char below = char_at(x, y+1);
  char left = char_at(x-1, y);
  char right = char_at(x+1, y);
  return above == ch ||
         below == ch ||
         left == ch ||
         right == ch;
}
bool is_char_in_str(char ch, string str) {
  return (int)str.find(ch) >= 0;
}
vector<coord2D> get_shot_coords() {
  vector<coord2D> shot_coords;
  for (int i = 0; i < room_width; i++) {
    for (int j = 0; j < room_height; j++) {
      char ch = char_at(i, j);
      if (is_char_in_str(ch, SHOOT_CH)) {
        coord2D coord;
        coord.x = i;
        coord.y = j;
        shot_coords.push_back(coord);
      }
    }
  }
  return shot_coords;
}

///////
// draw
///////
string box(int width, int height) {
  string edge = "";
  for (int i = 0; i < width; i++)
    edge += "#";
  edge += "\n";

  string middle = "#";
  for (int i = 0; i < width-2; i++)
    middle += ".";
  middle += "#\n";

  string txt = "";
  txt += edge;
  for (int j = 0; j < height-2; j++)
    txt += middle;
  txt += edge;

  return txt;
}
void display(string txt, bool input_enabled) {
  cout << "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n" << endl;

  // status
  bool show_help = is_adjacent_to('?', player_x, player_y);
  if (show_help)
    cout << "goty 2027 [early access]" << endl;
  else if (input_enabled)
    cout << "turn " << turn_number << endl;

  cout << room << endl;

  // command entry
  if (alive)
    cout << "~ ";
  else
    cout << "dead";
}

///////
// main
///////
void simulate() {
  // find coordinates where there are currently shots
  vector<coord2D> shot_coords = get_shot_coords();

  while (shot_coords.size() > 0) {
    shot_coords = get_shot_coords();
  
    // move shots
    for (int i = 0; i < shot_coords.size(); i++) {
      coord2D coord = shot_coords[i];
      int x = coord.x;
      int y = coord.y;
      char ch = char_at(x, y);
      switch (ch) {
        case '^':
          set_char_at('.', x, y);
          set_char_at('^', x, y-1);
          break;
        case '<':
          set_char_at('.', x, y);
          set_char_at('<', x-1, y);
          break;
        case 'v':
          set_char_at('.', x, y);
          set_char_at('v', x, y+1);
          break;
        case '>':
          set_char_at('.', x, y);
          set_char_at('>', x+1, y);
          break;
      }
    }

    float delay = 0.05f;
    wait(delay);

    // show
    display(room, false);
  }
  
  // display normal
  display(room, true);
}
void process_input(char input_ch) {
  int dx = 0;
  int dy = 0;

  // input
  switch (input_ch) {
    // move
    case 'w':
      dy = -1;
      break;
    case 's':
      dy = 1;
      break;
    case 'a':
      dx = -1;
      break;
    case 'd':
      dx = 1;
      break;
    
    // shoot
    case '^':
      dy = -1;
      break;
    case 'v':
      dy = 1;
      break;
    case '>':
      dx = 1;
      break;
    case '<':
      dx = -1;
      break;
  }

  bool is_move_ch = is_char_in_str(input_ch, MOVE_CH);
  bool is_shoot_ch = is_char_in_str(input_ch, SHOOT_CH);

  int next_x = player_x + dx;
  int next_y = player_y + dy;
  char next_ch = char_at(next_x, next_y);
  
  int next_next_x = player_x + dx + dx;
  int next_next_y = player_y + dy + dy;
  char next_next_ch = char_at(next_next_x, next_next_y);

  // debug
  // cout << input_ch << endl;
  // cout << "is_move " << is_move_ch << endl;
  // cout << "is_shoot " << is_shoot_ch << endl;

  // move
  if (is_move_ch && next_ch == '.') {
    set_char_at('.', player_x, player_y);
    set_char_at('@', next_x, next_y);

    // update pos
    player_x = next_x;
    player_y = next_y;
  }

  // push
  if (is_move_ch && next_ch == 'o' && next_next_ch == '.') {
    // move player
    set_char_at('.', player_x, player_y);
    set_char_at('@', next_x, next_y);
    
    // move bag
    set_char_at('o', next_x+dx, next_y+dy);

    // update pos
    player_x = next_x;
    player_y = next_y;
  }

  // shoot
  else if (is_shoot_ch && next_ch == '.') {
    // place shot
    set_char_at(input_ch, next_x, next_y);
  }

  // place enemy
  if (roll_d20() < 5) {
    coord2D enemy_coord = random_coord();
    char ch = char_at(enemy_coord.x, enemy_coord.y);
    if (ch == '.')
      set_char_at('!', enemy_coord.x, enemy_coord.y);
  }
  
  // place bag
  else if (roll_d20() < 3) {
    coord2D bag_coord = random_coord();
    char ch = char_at(bag_coord.x, bag_coord.y);
    if (ch == '.')
      set_char_at('o', bag_coord.x, bag_coord.y);
  }

  // check alive
  if (is_adjacent_to('!', player_x, player_y))
    alive = false;

  // inc turn
  turn_number++;
}

int main() {
  string input;

  cout << "width? ";
  cin >> input;
  room_width = stoi(input)+2;

  cout << "height? ";
  cin >> input;
  room_height = stoi(input)+2;

  cout << "generating " << room_width << "x" << room_height << "..." << endl;

  int w = 0;
  int h = 0;
  float delay = 0.0f;
  float delay_add = 0.001f;
  float delay_max = 0.02f;

  // grow vertically
  for (; h < room_height; h++) {
    room = box(w,h);
    display(room, false);

    wait(delay);
    delay += delay_add;
    if (delay > delay_max)
      delay = delay_max;
  }

  // grow horizontally
  delay *= 0.33f;
  for (; w < room_width; w++) {
    room = box(w,h);
    display(room, false);

    wait(delay);
    delay += delay_add;
    if (delay > delay_max)
      delay = delay_max;
  }
  
  wait(0.1f);
  
  // place player
  player_x = room_width / 2;
  player_y = room_height / 2;
  set_char_at('@', player_x, player_y);

  wait(0.1f);
  
  // place help
  coord2D help_coord = random_coord();
  set_char_at('?', help_coord.x, help_coord.y);

  // game loop
  while (true) {
    // end if dead
    if (!alive)
      break;

    // shots
    simulate();

    // get input
    string input;
    cin >> input;
    for (int i = 0; i < input.length(); i++) {
      char input_ch = input[i];
      process_input(input_ch);
    }

    // show
    display(room, true);
  }

  // exit when done
  return 0;
}