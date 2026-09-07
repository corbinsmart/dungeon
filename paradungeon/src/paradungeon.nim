import os
import rdstdin
import strformat
import strutils
import random
import macros
import pararules

########
# struct
########
type
  coord2D = tuple
    x: int
    y: int

#######
# const
#######
const
  MOVE_CH = "wasd"
  SHOOT_CH = "<>^v"

##############
# global state
##############
var
  room_width: int
  room_height: int
  room: string
  player_x: int
  player_y: int
  turn_number: int = 0
  alive: bool = true
  generating: bool = true
  # get_input = true


###########
# pararules
###########
type
  Id = enum
    Global,
    Player,
    Cell,
  Attr = enum
    X, Y,
    Input,
    CellType,

    Adjacent, Above, Below, Left, Right

schema Fact(Id, Attr):
  X: int
  Y: int
  Input: char
  CellType: char

  Above: Id
  Below: int
  Left: int
  Right: int
  Adjacent: int

let rules =
  ruleset:
    # rule getPlayer(Fact):
    #   what:
    #     (Player, X, x)
    #     (Player, Y, y)

    # adjacency
    rule getAbove(Fact):
      what:
        (id1, X, x)
        (id1, Y, y1)
        (id2, X, x)
        (id2, Y, y2)
      cond:
        y1 == y2-1
      then:
        session.insert(id1, Above, id2)
        session.insert(id1, Adjacent, id2)
    rule getBelow(Fact):
      what:
        (id1, X, x)
        (id1, Y, y1)
        (id2, X, x)
        (id2, Y, y2)
      cond:
        y1 == y2+1
      then:
        session.insert(id1, Below, id2)
        session.insert(id1, Adjacent, id2)
    rule getLeft(Fact):
      what:
        (id1, X, x1)
        (id1, Y, y)
        (id2, X, x2)
        (id2, Y, y)
      cond:
        x1 == x2-1
      then:
        session.insert(id1, Left, id2)
        session.insert(id1, Adjacent, id2)
    rule getRight(Fact):
      what:
        (id1, X, x1)
        (id1, Y, y)
        (id2, X, x2)
        (id2, Y, y)
      cond:
        x1 == x2+1
      then:
        session.insert(id1, Left, id2)
        session.insert(id1, Adjacent, id2)

    rule getQuestionAbove(Fact):
      what:
        (cid, Above, Player)
        (cid, CellType, '?')
      then:
        echo "? is above @"

    rule getQuestionAdjacent(Fact):
      what:
        (cid, Adjacent, Player)
        (cid, CellType, '?')
      then:
        echo "? adjacent @"

    rule getPlayerAdjacent(Fact):
      what:
        (Player, Adjacent, cid)
        (cid, CellType, '?')
      then:
        echo "@ adjacent ?"
    
    rule playerMove(Fact):
      what:
        (Player, X, x)
        (Player, Y, y)
      cond:
        true
      then:
        echo "@ ",x,",",y

    rule receiveInput(Fact):
      what:
        (Global, Input, input)
        (Player, X, x, then=false)
        (Player, Y, y, then=false)
      then:
        let
          dx = case input:
            of 'a': -1
            of 'd': 1
            else:   0
          dy = case input:
            of 'w': -1
            of 's': 1
            else:   0
        session.insert(Player, X, x+dx)
        session.insert(Player, Y, y+dy)

var session = initSession(Fact)
# session = initSession(Fact)
for r in rules.fields:
  session.add(r)

######
# util
######
proc cout(txt: string) =
  stdout.write txt
  stdout.flushFile()
  # echo txt
proc cin(): string =
  readLineFromStdin("")
proc is_char_in_str(ch: char, str: string): bool =
  ch in str
proc wait(seconds: float) =
  let ms = (seconds*1000).int
  sleep(ms)
proc random_int(min: int, max: int): int =
  rand(min..<max)
proc roll_d20(): int =
  random_int(1,20)
proc random_coord(): coord2D =
  (x: random_int(1, room_width-3),
   y: random_int(1, room_height-3))
proc coord_to_str_index(x: int, y: int): int =
  y * room_width + x
proc str_index_to_coord(index: int): coord2D =
  (x: index mod room_width,
   y: (index / room_width).int)
proc in_bounds(x: int, y: int): bool =
  x >= 0 and x < room_width-1 and
  y >= 0 and y < room_height-1
proc set_char_at(ch: char, x: int, y: int) =
  if not in_bounds(x, y):
    return

  let index = coord_to_str_index(x, y)
  room[index] = ch
proc char_at(x: int, y: int): char =
  if not in_bounds(x, y):
    return '0'

  let index = coord_to_str_index(x, y)
  room[index]
proc is_adjacent_to(ch: char, x: int, y: int): bool =
  let
    above = char_at(x, y-1)
    below = char_at(x, y+1)
    left = char_at(x-1, y)
    right = char_at(x+1, y)
  above == ch or
  below == ch or
  left == ch or
  right == ch
proc get_shot_coords(): seq[coord2D] =
  var shot_coords = newseq[coord2D](0)
  for i in 0..<room_width:
    for j in 0..<room_height:
      let ch = char_at(i, j)
      if is_char_in_str(ch, SHOOT_CH):
        let coord = (x: i, y: j)
        shot_coords.add(coord)
  shot_coords

# pararules
var next_id = Id.high.ord + 1
proc get_next_id(): int =
  next_id += 1
  next_id

######
# draw
######
proc box(width: int, height: int): string =
  var edge = ""
  for i in 0..<width:
    edge.add("#")
  edge.add("\n")

  var middle = "#"
  for i in 0..<width-2:
    middle.add(".")
  middle.add("#\n")

  var txt = ""
  txt.add(edge)
  for j in 0..<height-2:
    txt.add(middle)
  txt.add(edge)

  txt
proc display(txt: string, inpu_enabled: bool) =
  # echo "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"

  # status
  if not generating:
    let show_help = is_adjacent_to('?', player_x, player_y)
    if show_help:
      echo "goty 2027 [early access]"
    else:
      echo fmt("turn {turn_number}")

  # room
  echo room

  # command entry
  if not generating:
    if alive:
      cout "~ "
    else:
      cout "dead "

#######
# logic
#######
proc simulate() =
  var shot_coords: seq[coord2D] = get_shot_coords()

  while shot_coords.len > 0:
    # search again
    shot_coords = get_shot_coords()

    # move shots
    for i in 0..<shot_coords.len:
      let
        coord = shot_coords[i]
        x = coord.x
        y = coord.y
        ch = char_at(x, y)
      case ch:
        of '^':
          set_char_at('.', x, y)
          set_char_at('^', x, y-1)
        of 'v':
          set_char_at('.', x, y)
          set_char_at('v', x, y+1)
        of '<':
          set_char_at('.', x, y)
          set_char_at('<', x-1, y)
        of '>':
          set_char_at('.', x, y)
          set_char_at('>', x+1, y)
        else:
          discard

    let delay = 0.05
    wait(delay)

    # show
    display(room, false)
  
  # display normal
  display(room, true)
proc process_input(input_ch: char) =
  # pararules
  session.insert(Global, Input, input_ch)

  var
    dx = 0
    dy = 0
  
  # input
  case input_ch:
    # move
    of 'w':
      dy = -1
    of 's':
      dy = 1
    of 'a':
      dx = -1
    of 'd':
      dx = 1

    # shoot
    # of '^':
    #   dy = -1
    # of 'v':
    #   dy = 1
    # of '>':
    #   dx = 1
    # of '<':
    #   dx = -1

    else:
      discard
  
  let
    is_move_ch = is_char_in_str(input_ch, MOVE_CH)
    is_shoot_ch = is_char_in_str(input_ch, SHOOT_CH)

    next_x = player_x + dx
    next_y = player_y + dy
    next_ch = char_at(next_x, next_y)

    next_next_x = player_x + dx + dx
    next_next_y = player_y + dy + dy
    next_next_ch = char_at(next_next_x, next_next_y)
  
  # debug
  # echo input_ch
  # echo fmt("is_move {is_move_ch}")
  # echo fmt("is_shoot {is_shoot_ch}")

  # move
  if is_move_ch and next_ch == '.':
    set_char_at('.', player_x, player_y)
    set_char_at('@', next_x, next_y)

    # update pos
    player_x = next_x
    player_y = next_y

  # push
  # if is_move_ch and next_ch == 'o' and next_next_ch == '.':
  #   # move player
  #   set_char_at('.', player_x, player_y)
  #   set_char_at('@', next_x, next_y)

  #   # move bag
  #   set_char_at('o', next_x+dx, next_y+dy)

  #  # update pos
  #  player_x = next_x
  #  player_y = next_y

  # shoot
  # elif is_shoot_ch and next_ch == '.':
  #   # place shot
  #   set_char_at(input_ch, next_x, next_y)

  # place enemy
  # if roll_d20() < 5:
  #   let
  #     enemy_coord = random_coord()
  #     ch = char_at(enemy_coord.x, enemy_coord.y)
  #   if ch == '.':
  #     set_char_at('!', enemy_coord.x, enemy_coord.y)
    
  # place bag
  # elif roll_d20() < 3:
  #   let
  #     bag_coord = random_coord()
  #     ch = char_at(bag_coord.x, bag_coord.y)
  #   if ch == '.':
  #     set_char_at('o', bag_coord.x, bag_coord.y)

  # check alive
  # if is_adjacent_to('!', player_x, player_y):
  #   alive = false

  # inc turn
  turn_number += 1
  
######
# main
######
var
  args = commandLineParams()
  input = ""

# get room gen params
if args.len == 2:
  echo fmt("args: {args}")
  room_width = parseInt(args[0])
  room_height = parseInt(args[1])
else:
  cout "width? "
  input = cin()
  room_width = parseInt(input)+2

  cout "height? "
  input = cin()
  room_height = parseInt(input)+2

echo fmt "generating {room_width}x{room_height}..."

var
  delay = 0.0
  delay_add = 0.001
  delay_max = 0.02

# grow vertically
for h in 0..<room_height:
  echo h
  room = box(2,h)
  display(room, false)

  wait(delay)
  delay += delay_add
  if delay > delay_max:
    delay = delay_max

# grow horizontally
delay *= 0.33
for h in 0..<room_width:
  room = box(h,room_height-1)
  display(room, false)

  wait(delay)
  delay += delay_add
  if delay > delay_max:
    delay = delay_max

wait(0.1)

# place player
player_x = (room_width/2).int
player_y = (room_height/2).int
set_char_at('@', player_x, player_y)
# pararules
session.insert(Player, X, player_x)
session.insert(Player, Y, player_y)

wait(0.1)

# place help
let help_coord: coord2D = random_coord()
set_char_at('?', help_coord.x, help_coord.y)
# pararules
let qid = get_next_id()
session.insert(qid, X, help_coord.x)
session.insert(qid, Y, help_coord.y)
session.insert(qid, CellType, '?')

# done generating
generating = false

# game loop
while true:
  # end if dead
  if not alive:
    break

  # shots
  simulate()

  # get input
  input = cin()
  for i in 0..<input.len:
    let input_ch = input[i]
    process_input(input_ch)
  
  # show
  display(room, true)