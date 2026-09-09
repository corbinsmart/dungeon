import os
import terminal
import random
import rdstdin
import strformat
import strutils
import sequtils
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
  room: ref seq[seq[char]] = nil
  PLAYER_ID: int
  # player_x: int
  # player_y: int

#################
# pararules types
#################
type
  Dir = enum
    _,
    Left,
    Right,
    Up,
    Down,

  Id = enum
    Global,
    Derived,
    Cell,

  Attr = enum
    # global
    TurnNumber,
    ShowHelp,
    Alive,
    D20,

    # entity  
    X, Y, T,
    Input,
    CellType,
    Spawnable,
    Moving,

    # derived
    Adjacent, Above, Below, LeftOf, RightOf,
    AdjacentCellsToPlayer,
    AllCells,
  V2 = tuple[x: int, y: int]
  Ids = seq[int]
  Cells = ref seq[tuple[id: int, x: int, y: int, cell_type: char]]

################
# pararules util
################
var next_id = Id.high.ord + 1
proc get_next_id(): int =
  next_id += 1
  next_id
proc ch_to_v2(ch: char): V2 =
  let
    x = case ch:
      of 'a': -1
      of 'd': 1
      else:   0
    y = case ch:
      of 'w': -1
      of 's': 1
      else:   0
  (x,y)
proc xy_to_dir(x: int, y: int): Dir =
  if x == -1 and y == 0:
    Dir.Left
  elif x == 1 and y == 0:
    Dir.Right
  elif x == 0 and y == -1:
    Dir.Up
  elif x == 0 and y == 1:
    Dir.Down
  else:
    Dir._

#################
# pararules rules
#################
schema Fact(Id, Attr):
  # global
  TurnNumber: int
  ShowHelp: bool
  Alive: bool
  D20: int

  # entity
  X: int
  Y: int
  T: int
  Input: char
  CellType: char
  Spawnable: bool
  Moving: Dir

  # derived
  Above: Id
  Below: int
  LeftOf: int
  RightOf: int
  Adjacent: int
  AdjacentCellsToPlayer: Ids
  AllCells: Cells

let (initSession, rules) =
  staticRuleset(Fact, FactMatch):

    # getter
    rule getGlobal(Fact):
      what:
        (Global, TurnNumber, turn_number)
        (Global, ShowHelp, show_help)
        (Global, Alive, alive)
        (Global, D20, d20)

    rule getActor(Fact):
      what:
        (id, X, x)
        (id, Y, y)
        (id, T, t)

    rule getCell(Fact):
      what:
        (id, X, x)
        (id, Y, y)
        (id, CellType, cell_type)
    
    # setter
    # rule setShowHelp(Fact):
    #   what:
    #     (Player, Adjacent, id)
    #     (id, CellType, '?')
    #   then:
    #     session.insert(Global, ShowHelp, true)

    # cardinality = N
    rule setCells(Fact):
      what:
        (id, X, x)
        (id, Y, y)
        (id, CellType, cell_type)
      then:
        var cells: Cells = nil
        new cells
        cells[] = session.queryAll(this)
        session.insert(Derived, AllCells, cells)

    # rule spawnHelp(Fact):
    #   what:
    #     (Global, TurnNumber, t)
    #     (Derived, AllCells, allCells, then=false)
    #   cond:
    #     t == 0
    #   then:
    #     let
    #       cells = allCells[]
    #       index = rand(0..<cells.len)
    #       c = cells[index]
    #     session.insert(c.id, CellType, '?')
    #     # echo "? ",c.x,",",c.y

    rule spawnPlayer(Fact):
      what:
        (Global, TurnNumber, t)
        (Derived, AllCells, allCells, then=false)
      cond:
        t == 0
      then:
        let
          cells = allCells[]
          index = rand(0..<cells.len)
          c = cells[index]
        PLAYER_ID = get_next_id()
        session.insert(PLAYER_ID, CellType, '@')
        session.insert(PLAYER_ID, X, c.x)
        session.insert(PLAYER_ID, Y, c.y)
        session.insert(PLAYER_ID, T, t)
        # echo "@ ",c.x,",",c.y

    # rule spawnEnemy(Fact):
    #   what:
    #     (Global, TurnNumber, t)
    #     (Global, D20, d20)
    #     (Derived, AllCells, allCells, then=false)
    #   cond:
    #     t > 5
    #     d20 < 5
    #   then:
    #     let
    #       cells = allCells[]
    #       index = rand(0..<cells.len)
    #       c = cells[index]
    #     session.insert(c.id, CellType, '!')
    #     # echo "! ",c.x,",",c.y

    # random
    rule rollD20(Fact):
      what:
        (Global, TurnNumber, n)
      then:
        session.insert(Global, D20, rand(1..20))

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
        session.insert(id1, LeftOf, id2)
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
        session.insert(id1, RightOf, id2)
        session.insert(id1, Adjacent, id2)

    rule qKillsPlayer(Fact):
      what:
        (Global, Input, input)
      cond:
        input == 'q'
      then:
        session.insert(Global, Alive, false)

    rule inputMovesPlayer(Fact):
      what:
        (Global, Input, input)
        (Global, TurnNumber, t, then=false)
        (id, CellType, '@')
        (id, X, x, then=false)
        (id, Y, y, then=false)
      then:
        # indicate player is moving
        let
          (dx,dy) = ch_to_v2(input)
          dir = xy_to_dir(dx,dy)
        if dir != Dir._:
          session.insert(id, Moving, dir)

        # inc turn
        session.insert(Global, TurnNumber, t+1)

    rule moveDown(Fact):
      what:
        (id, Y, y, then=false)
        (id, Moving, Dir.Down)
        (id, Above, id1)
        (id1, CellType, '.')
      then:
        session.insert(id, Y, y+1)
        session.retract(id, Moving)

    rule moveUp(Fact):
      what:
        (id, Y, y, then=false)
        (id, Moving, Dir.Up)
        (id, Below, id1)
        (id1, CellType, '.')
      then:
        session.insert(id, Y, y-1)
        session.retract(id, Moving)

    rule moveLeft(Fact):
      what:
        (id, X, x, then=false)
        (id, Moving, Dir.Left)
        (id, RightOf, id1)
        (id1, CellType, '.')
      then:
        session.insert(id, X, x-1)
        session.retract(id, Moving)

    rule moveRight(Fact):
      what:
        (id, X, x, then=false)
        (id, Moving, Dir.Right)
        (id, LeftOf, id1)
        (id1, CellType, '.')
      then:
        session.insert(id, X, x+1)
        session.retract(id, Moving)

    rule tryMovePlayer(Fact):
      what:
        (Global, TurnNumber, t)
        (Global, Input, input)
        (pid, X, x, then=false)
        (pid, Y, y, then=false)
        (pid, CellType, '@', then=false)
      then:
        discard
        # let
        #   dx = case input:
        #     of 'a': -1
        #     of 'd': 1
        #     else:   0
        #   dy = case input:
        #     of 'w': -1
        #     of 's': 1
        #     else:   0
        # PLAYER_ID = get_next_id()
        # session.insert(PLAYER_ID, X, x+dx)
        # session.insert(PLAYER_ID, Y, y+dy)
        # session.insert(PLAYER_ID, CellType, '@')
        # session.insert(PLAYER_ID, T, t+1)
    rule doMovePlayer(Fact):
      what:
        (Global, TurnNumber, t)

        (pid, CellType, '@', then=false)
        (pid, X, px, then=false)
        (pid, Y, py, then=false)
        (pid, T, t, then=false)

        (cid, CellType, '.', then=false)
        (cid, X, cx, then=false)
        (cid, Y, cy, then=false)
        (cid, T, t, then=false)

        (next_pid, CellType, '@', then=false)
        (next_pid, X, next_x, then=false)
        (next_pid, Y, next_y, then=false)
        (next_pid, T, next_t, then=false)
      cond:
        next_t == t + 1
      then:
        discard

    # rule playerMovesCrate(Fact):
    #   what:
    #     (Player p)
    #     (Crate c)
    #   cond:
    #     p adjacent c
    #   then:
    #     move player
    #     move crate

    # rule getQuestionAbove(Fact):
    #   what:
    #     (cid, Above, Player)
    #     (cid, CellType, '?')
    #   then:
    #     echo "? is above @"
    # rule getQuestionAdjacent(Fact):
    #   what:
    #     (cid, Adjacent, Player)
    #     (cid, CellType, '?')
    #   then:
    #     echo "? adjacent @"
    # rule getPlayerAdjacent(Fact):
    #   what:
    #     (Player, Adjacent, cid)
    #     (cid, CellType, '?')
    #   then:
    #     echo "@ adjacent ?"

    # rule spawnEnemy(Fact):
    #   what:
    #     (Global, TurnNumber, n)
    #     (id, Spawnable, true)
    #     (id, X, x)
    #     (id, Y, y)
    #   cond:
    #     # roll_d20() < 10
    #     # true
    #     n > 0
    #   then:
    #     session.insert(id, CellType, '!')
    #     echo "! ",x,",",y

    # spawn
    # rule emptySpawnable(Fact):
    #   what:
    #     (cid, CellType, '.')
    #   then:
    #     session.insert(cid, Spawnable, true)
    # rule notSpawnableAdjacent(Fact):
    #   what:
    #     (cid, Spawnable, true)
    #     (cid, Adjacent, Player)
    #   then:
    #     session.insert(cid, Spawnable, false)

    # echo
    # rule echoTurnNumber(Fact):
    #   what:
    #     (Global, TurnNumber, n)
    #   then:
    #     echo "turn number:",n
    
    # rule getAdjacentCells(Fact):
    #   what:
    #     (id, Adjacent, Player)
    #   then:
    #     let ids = session.queryAll(this).map(cell => cell.id)
    #     session.insert(Derived, AdjacentCellsToPlayer, ids)

    # rule setSpawnable(Fact):
    #   what:
    #     (id, CellType, '.')
    #     # (Derived, AdjacentCellsToPlayer, ids)
    #   cond:
    #     # id notin ids
    #     true
    #   then:
    #     session.insert(id, Spawnable, true)

var session: Session[Fact,FactMatch] = initSession(autoFire=false)
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
  x >= 0 and x < room_width and
  y >= 0 and y < room_height
proc set_char_at(ch: char, x: int, y: int) =
  # if not in_bounds(x, y):
  #   return

  # let index = coord_to_str_index(x, y)
  # room[index] = ch
  discard
proc char_at(x: int, y: int): char =
  # if not in_bounds(x, y):
  #   return '0'

  # let index = coord_to_str_index(x, y)
  # room[index]
  return '.'
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

######
# draw
######
proc set_cell(x: int, y: int, ch: char) =
  if in_bounds(x,y):
      room[y][x] = ch
proc render_room() =
  let g = session.query(rules.getGlobal)
  
  let cells = session.queryAll(rules.getCell)
  # let player = session.query(rules.getActor, id=PLAYER_ID, t=g.turn_number)
  let player = session.query(rules.getActor, id=PLAYER_ID)
  echo "get player id ",PLAYER_ID

  # static cells
  for cell in cells:
    let (id,x,y,cell_type) = cell
    set_cell(x,y,cell_type)
  
  # player
  set_cell(player.x, player.y, '@')
  
  # print
  for j in 0..<room_height:
    echo room[j].join

proc render() =
  # echo "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"

  # debug
  let g = session.query(rules.getGlobal)
  echo g
  # let player_moving = session.queryAll(rules.getGlobal)

  # status
  #   # let show_help = is_adjacent_to('?', player_x, player_y)
  #   let show_help = session.query(rules.getShowHelp).show_help
  #   echo "show_help? ",show_help
  #   if show_help:
  #     echo "goty 2027 [early access]"
  #   else:
  #     echo fmt("turn {turn_number}")
    # if show_help:
    #   echo "goty 2027 [early access]"
    # else:
    #   echo fmt("turn {turn_number}")

  # room
  render_room()

  # command entry
  if g.alive:
    cout "~ "
  else:
    cout "dead "

#######
# logic
#######
proc simulate() =
  proc move_shots(coords: seq[coord2D]) =
    for i in 0..<coords.len:
      let
        coord = coords[i]
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

  let coords = get_shot_coords()
  move_shots(coords)
  # display(room, true)
proc process_input(input_ch: char) =
  discard

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
    of '^':
      dy = -1
    of 'v':
      dy = 1
    of '>':
      dx = 1
    of '<':
      dx = -1

    else:
      discard
  
  # let
  #   is_move_ch = is_char_in_str(input_ch, MOVE_CH)
  #   is_shoot_ch = is_char_in_str(input_ch, SHOOT_CH)

  #   next_x = player_x + dx
  #   next_y = player_y + dy
  #   next_ch = char_at(next_x, next_y)

  #   next_next_x = player_x + dx + dx
  #   next_next_y = player_y + dy + dy
  #   next_next_ch = char_at(next_next_x, next_next_y)
  
  # # move
  # if is_move_ch and next_ch == '.':
  #   set_char_at('.', player_x, player_y)
  #   set_char_at('@', next_x, next_y)

  #   # update pos
  #   player_x = next_x
  #   player_y = next_y

  # push
  # if is_move_ch and next_ch == 'o' and next_next_ch == '.':
  #   # move player
  #   set_char_at('.', player_x, player_y)
  #   set_char_at('@', next_x, next_y)

  #   # move bag
  #   set_char_at('o', next_x+dx, next_y+dy)

  #   # update pos
  #   player_x = next_x
  #   player_y = next_y

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
  
######
# main
######
var
  args = commandLineParams()
  input = ""

# get room gen params
if args.len == 2:
  echo fmt("args: {args}")
  room_width = parseInt(args[0])+2
  room_height = parseInt(args[1])+2
else:
  cout "width? "
  input = cin()
  room_width = parseInt(input)+2

  cout "height? "
  input = cin()
  room_height = parseInt(input)+2

echo fmt "generating {room_width}x{room_height}..."

# var
#   delay = 0.0
#   delay_add = 0.001
#   delay_max = 0.02

# intro animation
proc intro() =
  discard
  # grow vertically
  # for h in 0..<room_height:
  #   echo h
  #   room = box(2,h)
  #   display(room, false)

  #   wait(delay)
  #   delay += delay_add
  #   if delay > delay_max:
  #     delay = delay_max

  # grow horizontally
  # delay *= 0.33
  # for h in 0..<room_width:
  #   room = box(h,room_height-1)
  #   display(room, false)

  #   wait(delay)
  #   delay += delay_add
  #   if delay > delay_max:
  #     delay = delay_max

  # wait(0.1)

  # place player
  # player_x = (room_width/2).int
  # player_y = (room_height/2).int
  # set_char_at('@', player_x, player_y)
  # # pararules
  # session.insert(Player, X, player_x)
  # session.insert(Player, Y, player_y)
  # session.insert(Player, CellType, '@')

  # wait(0.1)

  # place help
  # let help_coord: coord2D = random_coord()
  # set_char_at('?', help_coord.x, help_coord.y)
  # # pararules
  # let qid = get_next_id()
  # session.insert(qid, X, help_coord.x)
  # session.insert(qid, Y, help_coord.y)
  # session.insert(qid, CellType, '?')
intro()

# done generating
# generating = false
# turn_number = 0
new room
room[] = newSeqWith(room_height, newSeq[char](room_width))

# pararules init
echo "pararules init..."
session.insert(Global, TurnNumber, 0)
session.insert(Global, ShowHelp, false)
session.insert(Global, Alive, true)
for i in 0..<room_width:
  for j in 0..<room_height:
    let id = get_next_id()
    let cell_type = if (i == 0 or i == room_width-1 or
                        j == 0 or j == room_height-1): '#' else: '.'
    session.insert(id, X, i)
    session.insert(id, Y, j)
    session.insert(id, CellType, cell_type)
echo "fireRules..."
session.fireRules()
echo "done"

# show
render()

# game loop
while true:
  # end if dead
  let alive = session.query(rules.getGlobal).alive
  if not alive:
    break

  # shots
  # simulate()

  # input
  let ch = getch()
  # echo fmt"ch:{ch} ch.int:{ch.int}"

  # pararules
  session.insert(Global, Input, ch)
  session.fireRules()

  # show
  render()

  # wait until next frame
  wait(0.01)