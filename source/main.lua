import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "util"

local gfx <const> = playdate.graphics
local point <const> = playdate.geometry.point

local GRID_WIDTH <const> = 10
local GRID_HEIGHT <const> = 15

local X_OFFSET = (12.5 - 5) * 16

local blockTypes <const> = {'single', 'I', 'J', 'L', 'O', 'S', 'T', 'Z'}
-- local blockTypes <const> = {'O'}

local grid = {}

local tilesheet = nil

local tickTimer = nil

local activeBlock = nil

local clearedRows = nil

local crankChange = 0

local score = 0

class('Block').extends(playdate.graphics.sprite)

local function getPointsForBlock(type)
   if type == 'single' then
      return {
         point.new(0, 0)
      }
   end

   if type == 'I' then
      return {
         point.new(0, 0),
         point.new(0, 1),
         point.new(0, 2),
         point.new(0, 3)
      }
   end

   if type == 'J' then
      return {
         point.new(0, 0),
         point.new(0, 1),
         point.new(1, 1),
         point.new(2, 1)
      }
   end

   if type == 'L' then
      return {
         point.new(0, 1),
         point.new(1, 1),
         point.new(2, 1),
         point.new(2, 0)
      }
   end

   if type == 'O' then
      return {
         point.new(0, 0),
         point.new(0, 1),
         point.new(1, 0),
         point.new(1, 1)
      }
   end

   if type == 'S' then
      return {
         point.new(1, 0),
         point.new(2, 0),
         point.new(1, 1),
         point.new(0, 1)
      }
   end

   if type == 'T' then
      return {
         point.new(1, 0),
         point.new(0, 1),
         point.new(1, 1),
         point.new(2, 1)
      }
   end

   if type == 'Z' then
      return {
         point.new(0, 0),
         point.new(1, 0),
         point.new(1, 1),
         point.new(2, 1)
      }
   end
end

local function getCenterForBlock(type)
   if type == 'single' then
      return point.new(0, 0)
   end

   return point.new(0.5, 0.5)
end

function Block:init(blockType)
   Block.super.init(self)
   self.blockType = blockType
   self.row = 1
   self.col = math.floor(math.random(1, GRID_WIDTH / 2))

   self.points = getPointsForBlock(self.blockType)
   self.center = getCenterForBlock(self.blockType)
end

function Block:getPoints()
   return map(
      self.points,
      function(point)
         return point.new(point.x + self.col + 1, point.y + self.row + 1)
      end
   )
end

function Block:moveDown()
   if self.row < GRID_HEIGHT then
      self.row += 1
   end
end

function Block:draw()
   for _, point in ipairs(self:getPoints()) do
      tilesheet:drawImage(2, X_OFFSET + 16 * (point.x - 1), 16 * (point.y - 1))
   end
end

function Block:moveSide(n)
   local points = self:getPoints()

   for _, point in ipairs(points) do
      if grid[point.y][point.x + n] == 1 then
         return
      end

      if point.x + n <= 0 then
         return
      end

      if point.x + n > GRID_WIDTH then
         return
      end
   end

   self.col += n
end

function Block:rotate()
   local translatedPoints = map(
      self.points,
      function(point)
         return point.new(point.x - self.center.x, point.y - self.center.y)
      end
   )
   local rotatedPoints = map(
      translatedPoints,
      function(point)
         return point.new(point.y, (point.x * -1))
      end
   )
   local newPoints = map(
      rotatedPoints,
      function(point)
         return point.new(point.x + self.center.x, point.y + self.center.y)
      end
   )

   for _, point in ipairs(newPoints) do
      if (point.y + self.row + 1) > GRID_HEIGHT then
         return
      end
   end

   self.points = newPoints
end

local function newActiveBlock()
   if activeBlock then
      for _, point in ipairs(activeBlock:getPoints()) do
         grid[point.y][point.x] = 1
      end
   end

   blockChoice = math.floor(
      math.random(1, #blockTypes)
   )
   activeBlock = Block(
      blockTypes[blockChoice]
   )
end

local function hasGap(row)
   for _, val in ipairs(row) do
      if val == 0 then
         return true
      end
   end

   return false
end

local function clearRow(n)
   for i, _ in ipairs(grid[n]) do
      grid[n][i] = 0
   end

   if not clearedRows then
      clearedRows = {}
   end

   table.insert(clearedRows, n)
   score += 1
end

local function runTick()
   if clearedRows then
      for _, clearedRow in ipairs(clearedRows) do
         for y = clearedRow, 2, -1 do
            for x, val in ipairs(grid[y - 1]) do
               grid[y][x] = val
            end
         end
      end

      clearedRows = nil
   end

   activeBlock:moveDown()

   for _, point in ipairs(activeBlock:getPoints()) do
      if grid[point.y][point.x] == 1 then
         activeBlock.row -= 1
         newActiveBlock()
         break
      end

      if point.y == GRID_HEIGHT then
         newActiveBlock()
         break
      end
   end

   for y, row in ipairs(grid) do
      if not hasGap(row) then
         clearRow(y)
      end
   end
end

local function resetTimer()
   tickTimer = playdate.timer.new(800, runTick, 0)
   fastTickTimer = playdate.timer.new(20, runTick, 0)

   tickTimer.repeats = true
   fastTickTimer.repeats = true
   fastTickTimer.paused = true
end

local function initGrid()
   for y = 1, GRID_HEIGHT do
      grid[y] = {}

      for x = 1, GRID_WIDTH do
         grid[y][x] = 0
      end
   end
end

local function drawBg()
   gfx.setLineWidth(2)
   gfx.drawLine(X_OFFSET, 0, X_OFFSET, GRID_HEIGHT * 16)
   gfx.drawLine(X_OFFSET + GRID_WIDTH * 16, 0, X_OFFSET + GRID_WIDTH * 16, GRID_HEIGHT * 16)
end

local function initialize()
   math.randomseed(playdate.getSecondsSinceEpoch())

   tilesheet = gfx.imagetable.new("images/tiles-subset")
   resetTimer()
   initGrid()
   newActiveBlock()

   gfx.sprite.setBackgroundDrawingCallback(drawBg)
end

initialize()

function playdate.update()
   if playdate.buttonJustPressed(playdate.kButtonRight) then
      activeBlock:moveSide(1)
   end
   if playdate.buttonJustPressed(playdate.kButtonLeft) then
      activeBlock:moveSide(-1)
   end
   if playdate.buttonIsPressed(playdate.kButtonDown) then
      tickTimer:pause()
      fastTickTimer:start()
   else
      if tickTimer.paused then
         fastTickTimer:pause()
         tickTimer:start()
      end
   end

   if playdate.buttonJustPressed(playdate.kButtonA) then
      activeBlock:rotate()
   end

   local change, _ = playdate.getCrankChange()
   crankChange += change
   if math.abs(crankChange) > 90 then
      activeBlock:rotate()
      crankChange = 0
   end

   playdate.timer.updateTimers()
   gfx.setLineWidth(2)
   gfx.sprite.update()

   for y, row in ipairs(grid) do
      for x, val in ipairs(row) do
         if val == 1 then
            tilesheet:drawImage(2, X_OFFSET + 16 * (x - 1), 16 * (y - 1))
         end
      end
   end

   activeBlock:draw()
   gfx.drawText("Score: " .. score, 320, 5)
end
