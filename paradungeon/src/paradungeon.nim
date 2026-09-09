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
  room: ref seq[seq[char]] = nil
  PLAYER_ID: int
  # room_width: int
  # room_height: int
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
    RoomWidth,
    RoomHeight,
    TurnNumber,
    ShowHelp,
    Alive,
    D20,

    # entity  
    X, Y, T,
    Input,
    Type,
    Spawnable,
    Moving,

    # derived
    Adjacent, Above, Below, LeftOf, RightOf,
    AdjacentCellsToPlayer,
    AllCells,
  V2 = tuple[x: int, y: int]
  Ids = seq[int]
  Cells = ref seq[tuple[id: int, x: int, y: int, t: char]]

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
  RoomWidth: int
  RoomHeight: int
  TurnNumber: int
  ShowHelp: bool
  Alive: bool
  D20: int

  # entity
  X: int
  Y: int
  T: int
  Input: char
  Type: char
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
        (Global, RoomWidth, room_width)
        (Global, RoomHeight, room_height)
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
        (id, Type, t)
      cond:
        t != ' '
    
    # setter
    # rule setShowHelp(Fact):
    #   what:
    #     (Player, Adjacent, id)
    #     (id, Type, '?')
    #   then:
    #     session.insert(Global, ShowHelp, true)

    # cardinality = N
    rule setCells(Fact):
      what:
        (id, X, x)
        (id, Y, y)
        (id, Type, t)
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
    #     session.insert(c.id, Type, '?')
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
        session.insert(PLAYER_ID, Type, '@')
        session.insert(PLAYER_ID, X, c.x)
        session.insert(PLAYER_ID, Y, c.y)
        session.insert(PLAYER_ID, T, t)
        # echo "@ ",c.x,",",c.y

    rule spawnWall(Fact):
      what:
        (Global, TurnNumber, t)
        (Global, RoomWidth, room_width)
        (Global, RoomHeight, room_height)
        (sid, Type, ' ')
        (sid, X, x)
        (sid, Y, y)
      cond:
        t == 0
        (x == 0 or
         y == 0 or
         x == room_width-1 or
         y == room_height-1)
      then:
        let wid = get_next_id()
        session.insert(wid, X, x)
        session.insert(wid, Y, y)
        session.insert(wid, Type, '#')

    # rule spawnBag(Fact):
    #   what:
    #     (Global, TurnNumber, t)
    #     (Global, D20, d20)
    #     (Derived, AllCells, allCells, then=false)
    #   cond:
    #     d20 < 5
    #   then:
    #     let
    #       cells = allCells[]
    #       index = rand(0..<cells.len)
    #       c = cells[index]
    #     session.insert(c.id, Type, 'o')

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
    #     session.insert(c.id, Type, '!')

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
        (id, Type, '@')
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

    rule playerPushesBagRight(Fact):
      what:
        (pid, Type, '@')
        (pid, Moving, Dir.Right)
        (bid, Type, 'o')
        (bid, RightOf, pid)
      then:
        session.insert(bid, Moving, Dir.Right)

    rule wallStopsActorMovingDown(Fact):
      what:
        (id, Moving, Dir.Down)
        (id, Y, y, then=false)
        (id, Above, wid)
        (wid, Type, '#')
      then:
        echo "wall stop"
        # session.retract(id, Moving)
        session.insert(id, Y, y)

    rule moveDown(Fact):
      what:
        (id, Y, y, then=false)
        (id, Moving, Dir.Down)
        # (id, Above, id1)
        # (id1, Type, '.')
      then:
        echo "move down"
        session.insert(id, Y, y+1)
        session.retract(id, Moving)

    rule moveUp(Fact):
      what:
        (id, Y, y, then=false)
        (id, Moving, Dir.Up)
        # (id, Below, id1)
        # (id1, Type, '.')
      then:
        session.insert(id, Y, y-1)
        session.retract(id, Moving)

    rule moveLeft(Fact):
      what:
        (id, X, x, then=false)
        (id, Moving, Dir.Left)
        # (id, RightOf, id1)
        # (id1, Type, '.')
      then:
        session.insert(id, X, x-1)
        session.retract(id, Moving)

    rule moveRight(Fact):
      what:
        (id, X, x, then=false)
        (id, Moving, Dir.Right)
        # (id, LeftOf, id1)
        # (id1, Type, '.')
      then:
        session.insert(id, X, x+1)
        session.retract(id, Moving)

    rule tryMovePlayer(Fact):
      what:
        (Global, TurnNumber, t)
        (Global, Input, input)
        (pid, X, x, then=false)
        (pid, Y, y, then=false)
        (pid, Type, '@', then=false)
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
        # session.insert(PLAYER_ID, Type, '@')
        # session.insert(PLAYER_ID, T, t+1)
    rule doMovePlayer(Fact):
      what:
        (Global, TurnNumber, t)

        (pid, Type, '@', then=false)
        (pid, X, px, then=false)
        (pid, Y, py, then=false)
        (pid, T, t, then=false)

        (cid, Type, '.', then=false)
        (cid, X, cx, then=false)
        (cid, Y, cy, then=false)
        (cid, T, t, then=false)

        (next_pid, Type, '@', then=false)
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
    #     (cid, Type, '?')
    #   then:
    #     echo "? is above @"
    # rule getQuestionAdjacent(Fact):
    #   what:
    #     (cid, Adjacent, Player)
    #     (cid, Type, '?')
    #   then:
    #     echo "? adjacent @"
    # rule getPlayerAdjacent(Fact):
    #   what:
    #     (Player, Adjacent, cid)
    #     (cid, Type, '?')
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
    #     session.insert(id, Type, '!')
    #     echo "! ",x,",",y

    # spawn
    # rule emptySpawnable(Fact):
    #   what:
    #     (cid, Type, '.')
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
    #     (id, Type, '.')
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
proc wait(seconds: float) =
  let ms = (seconds*1000).int
  sleep(ms)
proc in_bounds(x: int, y: int, width: int, height: int): bool =
  x >= 0 and x < width and
  y >= 0 and y < height
# proc is_char_in_str(ch: char, str: string): bool =
#   ch in str
# proc random_int(min: int, max: int): int =
#   rand(min..<max)
# proc roll_d20(): int =
#   random_int(1,20)
# proc random_coord(): coord2D =
#   (x: random_int(1, room_width-3),
#    y: random_int(1, room_height-3))
# proc coord_to_str_index(x: int, y: int): int =
#   y * room_width + x
# proc str_index_to_coord(index: int): coord2D =
#   (x: index mod room_width,
#    y: (index / room_width).int)
# proc set_char_at(ch: char, x: int, y: int) =
#   discard
#   # if not in_bounds(x, y):
#   #   return
#   # let index = coord_to_str_index(x, y)
#   # room[index] = ch
# proc char_at(x: int, y: int): char =
#   # if not in_bounds(x, y):
#   #   return '0'
#   # let index = coord_to_str_index(x, y)
#   # room[index]
#   return '.'
# proc is_adjacent_to(ch: char, x: int, y: int): bool =
#   let
#     above = char_at(x, y-1)
#     below = char_at(x, y+1)
#     left = char_at(x-1, y)
#     right = char_at(x+1, y)
#   above == ch or
#   below == ch or
#   left == ch or
#   right == ch
# proc get_shot_coords(): seq[coord2D] =
#   var shot_coords = newseq[coord2D](0)
#   for i in 0..<room_width:
#     for j in 0..<room_height:
#       let ch = char_at(i, j)
#       if is_char_in_str(ch, SHOOT_CH):
#         let coord = (x: i, y: j)
#         shot_coords.add(coord)
#    shot_coords

######
# draw
######
proc render_cell(x: int, y: int, ch: char, room_width: int, room_height: int) =
  if in_bounds(x,y,room_width,room_height):
      room[y][x] = ch
proc render_room() =
  # query
  let g = session.query(rules.getGlobal)
  let cells = session.queryAll(rules.getCell)
  let player = session.query(rules.getActor, id=PLAYER_ID)
  echo "get player id ",PLAYER_ID
  
  # clear
  room[] = newSeqWith(g.room_height, newSeq[char](g.room_width))

  # static cells
  for cell in cells:
    let (id,x,y,t) = cell
    render_cell(x,y,t,g.room_width,g.room_height)
  
  # player
  render_cell(player.x, player.y, '@',g.room_width,g.room_height)
  
  # print
  for j in 0..<g.room_height:
    var row = ""
    for i in 0..<g.room_width:
      if room[j][i] == 0.char:
        row.add(' ')
      else:
        row.add(room[j][i])
    echo row
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

######
# main
######
var
  args = commandLineParams()
  input = ""

# get room gen params
var
  room_width = 0
  room_height = 0
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
session.insert(Global, RoomWidth, room_width)
session.insert(Global, RoomHeight, room_height)
echo fmt "generating {room_width}x{room_height}..."

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
  # session.insert(Player, Type, '@')

  # wait(0.1)

  # place help
  # let help_coord: coord2D = random_coord()
  # set_char_at('?', help_coord.x, help_coord.y)
  # # pararules
  # let qid = get_next_id()
  # session.insert(qid, X, help_coord.x)
  # session.insert(qid, Y, help_coord.y)
  # session.insert(qid, Type, '?')
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
for x in 0..<room_width:
  for y in 0..<room_height:
    let space_id = get_next_id()
    session.insert(space_id, X, x)
    session.insert(space_id, Y, y)
    session.insert(space_id, Type, ' ')
    
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