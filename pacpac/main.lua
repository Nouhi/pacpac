--[[ main.lua

     Main code for PacPac, a lua-based pac-man clone.
     There are many pac-man clones. This one is mine.
  ]]

-------------------------------------------------------------------------------
-- Declare all globals here.
-------------------------------------------------------------------------------

map = {{1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 0, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1},
       {1, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 1, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 2, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1},
       {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1},
       {1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1},
       {1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 2, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1},
       {1, 0, 0, 0, 0, 1, 0, 0, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1},
       {1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1},
       {1, 0, 1, 1, 0, 1, 0, 1, 2, 1, 0, 1, 2, 1, 0, 1, 0, 0, 0, 1, 0, 1},
       {1, 0, 0, 0, 0, 0, 0, 1, 2, 1, 0, 1, 2, 1, 0, 0, 0, 1, 0, 0, 0, 1},
       {1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 0, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1}}

superdots = nil -- Value given below.

tile_size = 20

man_x = 10.5
man_y = 17.5
man_dir = {-1, 0}
pending_dir = nil
speed = 4
clock = 0

man = nil  -- A Character object for the hero.
characters = {}  -- All moving Character objects = man + ghosts.

-------------------------------------------------------------------------------
-- Define the Character class.
-------------------------------------------------------------------------------

Character = {} ; Character.__index = Character

-- shape is 'hero' or 'ghost'; color is in {'red', 'pink', 'blue', 'orange'}.
function Character.new(shape, color)
  local c = setmetatable({shape = shape, color = color}, Character)
  if shape == 'hero' then
    c.x = 10.5
    c.y = 17.5
    c.dir = {-1, 0}
    c.next_dir = nil
    c.speed = 4
  else
    c.x = 10.5
    c.y = 9.5
    c.dir = {1, 0}
    c.next_dir = nil
    c.speed = 4
    c.target = {2.5, 2.5}
  end
  return c
end

function Character:snap_into_place()
  if self.dir[1] == 0 then
    self.x = math.floor(2 * self.x + 0.5) / 2
  end
  if self.dir[2] == 0 then
    self.y = math.floor(2 * self.y + 0.5) / 2
  end
end

function Character:can_go_in_dir(dir)
  if dir == nil then return false end
  local new_x, new_y = self.x + dir[1], self.y + dir[2]
  return not xy_hits_a_wall(new_x, new_y)
end

function Character:dot_prod(dir)
  local target_dir = {self.target[1] - self.x, self.target[2] - self.y}
  return target_dir[1] * dir[1] + target_dir[2] * dir[2]
end

function Character:just_turned()
  return self.last_turn and clock - self.last_turn < 0.2
end

-- Input is the direction we were previously going in.
-- We want ghosts to not go directly backwards here.
function Character:did_stop(old_dir)
  if self.shape == 'hero' then return end
  if self:just_turned() then return end
  local turn = {old_dir[2], old_dir[1]}
  local sorted_turns = {}  -- First dir here will be our first choice.
  local dot_prod = self:dot_prod(turn)
  local sign = 1
  if dot_prod < 0 then sign = -1 end
  local turns = {{turn[1] * sign, turn[2] * sign},
                 {turn[1] * sign * -1, turn[2] * sign * -1}}
  for k, t in pairs(turns) do
    if self:can_go_in_dir(t) then
      self.dir = t
      self.last_turn = clock
      return
    end
  end
end

function Character:available_turns()
  if self:just_turned() then return {} end
  local turn = {self.dir[2], self.dir[1]}
  local turns = {}
  for sign = -1, 1, 2 do
    local t = {turn[1] * sign, turn[2] * sign}
    if self:can_go_in_dir(t) then table.insert(turns, t) end
  end
  return turns
end

-- Switch self.dir to dir if it is more aligned with getting to the target.
function Character:turn_if_better(turn)
  if self:dot_prod(turn) > self:dot_prod(self.dir) then
    self.dir = turn
    self.last_turn = clock
  end
end

function Character:update(dt)

  -- Blind movement.
  self.x = self.x + self.dir[1] * dt * self.speed
  self.y = self.y + self.dir[2] * dt * self.speed
  self:snap_into_place()

  -- Step back if we hit a wall.
  local did_hit_wall = xy_hits_a_wall(self.x, self.y)
  if did_hit_wall then
    local old_dir = self.dir
    self.dir = {0, 0}
    self:snap_into_place()
    self:did_stop(old_dir)
  end

  -- Check if we should turn.
  -- This outer guard protects against turns in the side warps.
  if self.x > 1 and self.x < (#map + 1) then
    if self.shape == 'hero' and self:can_go_in_dir(self.next_dir) then
      self.dir = self.next_dir
      self.next_dir = nil
    end
    if self.shape == 'ghost' and not did_hit_wall then
      local turns = self:available_turns()
      for k, t in pairs(turns) do self:turn_if_better(t) end
    end
  end

  -- Check for side warps.
  if self.x <= 0.5 then
    self.x = #map + 1.5
    self.dir = {-1, 0}
  elseif self.x >= #map + 1.5 then
    self.x = 0.5
    self.dir = {1, 0}
  end

  if self.shape == 'hero' then
    local dots_hit = dots_hit_by_man_at_xy(self.x, self.y)
    for k, v in pairs(dots_hit) do
      if dots[k] then dots[k] = nil end
    end
  end
end

function Character:draw()
  local colors = {red = {255, 0, 0}, pink = {255, 128, 128},
                  blue = {0, 64, 255}, orange = {255, 128, 0},
                  yellow = {255, 255, 0}}
  local color = colors[self.color]
  love.graphics.setColor(color[1], color[2], color[3])
  if self.shape == 'hero' then
    love.graphics.circle('fill', self.x * tile_size,
                         self.y * tile_size, tile_size / 2, 10)
  else
    love.graphics.circle('fill', self.x * tile_size,
                         self.y * tile_size, tile_size / 2, 10)
  end
end

man = Character.new('hero', 'yellow')
table.insert(characters, man)

table.insert(characters, Character.new('ghost', 'red'))

-------------------------------------------------------------------------------
-- Non-love functions.
-------------------------------------------------------------------------------

function str(t)
  if type(t) == 'table' then
    local s = '{'
    for i, v in ipairs(t) do
      if #s > 1 then s = s .. ', ' end
      s = s .. str(v)
    end
    s = s .. '}'
    return s
  elseif type(t) == 'number' then
    return tostring(t)
  elseif type(t) == 'boolean' then
    return tostring(t)
  end
  return 'unknown type'
end

-- Turns {a, b} into {[str(a)] = a, [str(b)] = b}.
-- This is useful for testing if hash[key] for inclusion.
function hash_from_list(list)
  local hash = {}
  for k, v in pairs(list) do hash[str(v)] = v end
  return hash
end

function love.load()
  superdots = hash_from_list({{2.5, 4}, {18.5, 4}, {2.5, 17.5}, {18.5, 17.5}})

  -- This will be a hash set of all dot locations.
  dots = {}
 
  -- Inner functions to help find the dot locations.
  -- The input x, y is the integer square location in tile coordinates.
  function add_dots(x, y)
    if map[x][y] ~= 0 then return end
    add_one_dot(x + 0.5, y + 0.5)
    if x + 1 <= #map and map[x + 1][y] == 0 then
      add_one_dot(x + 1, y + 0.5)
    end
    if y + 1 <= #(map[1]) and map[x][y + 1] == 0 then
      add_one_dot(x + 0.5, y + 1)
    end
  end
  function add_one_dot(x, y) dots[str({x, y})] = {x, y} end

  for x = 1, #map do for y = 1, #(map[1]) do add_dots(x, y) end end
end

-- The input x, y is the center of the dot in tile-based coordinates.
function draw_one_dot(x, y)
  local dot_size = 1
  if superdots[str({x, y})] then dot_size = 4 end
  love.graphics.setColor(255, 255, 255)
  love.graphics.circle('fill',
                       x * tile_size,
                       y * tile_size,
                       dot_size, 10)
end

function draw_dots()
  for k, v in pairs(dots) do draw_one_dot(v[1], v[2]) end
end

function draw_wall(x, y)
  -- print('draw_wall(' .. x .. ', ' .. y .. ')')
  love.graphics.setColor(255, 255, 255)
  love.graphics.rectangle('fill', x * tile_size, y * tile_size,
                          tile_size, tile_size)
end

function pts_hit_by_man_at_xy(x, y)
  local h = 0.45  -- Less than 0.5 to allow turns near intersections.
  local pts = {}
  for dx = -1, 1, 2 do for dy = -1, 1, 2 do
    table.insert(pts, {math.floor(x + dx * h), math.floor(y + dy * h)})
  end end
  return pts
end

-- Returns a hash set of the dot pts nearby, whether or not a dot is there.
function dots_hit_by_man_at_xy(x, y)
  local pts = pts_hit_by_man_at_xy(2 * x + 0.5, 2 * y + 0.5)
  local dots = {}
  for k, v in pairs(pts) do
    local pt = {v[1] / 2, v[2] / 2}
    dots[str(pt)] = pt
  end
  return dots
end

function xy_hits_a_wall(x, y)
  local pts = pts_hit_by_man_at_xy(x, y)
  for k, v in pairs(pts) do
    if v[1] >= 1 and v[1] <= #map then
      if map[v[1]][v[2]] == 1 then return true end
    end
  end
  return false
end

-------------------------------------------------------------------------------
-- Love functions.
-------------------------------------------------------------------------------

function love.draw()
  for x = 1, #map do for y = 1, #(map[1]) do
    if map[x][y] == 1 then
      draw_wall(x, y)
    end
  end end  -- Loop over x, y.

  -- Draw dots.
  for k, v in pairs(dots) do draw_one_dot(v[1], v[2]) end

  for k, character in pairs(characters) do
    character:draw()
  end
end

function love.keypressed(key)
  local dirs = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}
  local dir = dirs[key]
  if dir == nil then return end
  if man:can_go_in_dir(dir) then
    man.dir = dir
  else
    man.next_dir = dir
  end
end

function love.update(dt)
  clock = clock + dt
  for k, character in pairs(characters) do
    character:update(dt)
  end
end
