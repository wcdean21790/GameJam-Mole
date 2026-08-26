local gfx = playdate.graphics

Game = {}
Game.__index = Game

local START_TIME = 30
local MOVE_DURATION = 0.09
local MOVE_REPEAT_MS = 115

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function easeOut(t)
    return 1 - (1 - t) * (1 - t)
end

local function centerText(text, y)
    local width = gfx.getTextSize(text)
    gfx.drawText(text, 200 - width / 2, y)
end

function Game.new()
    local self = setmetatable({}, Game)
    self.audio = Audio.new()
    self.world = World.new()
    self.state = "title"
    self.lastMs = playdate.getCurrentTimeMilliseconds()
    self.titleBob = 0
    self.effects = {}
    self.particles = {}
    self.cameraY = 0
    return self
end

function Game:start()
    self.world:reset()
    self.state = "playing"
    self.score = 0
    self.timeLeft = START_TIME
    self.maxDepth = 0
    self.col = 10
    self.row = 3
    self.facing = "down"
    self.visualX = (self.col - 0.5) * World.TILE
    self.visualY = (self.row - 0.5) * World.TILE
    self.moveFromX = self.visualX
    self.moveFromY = self.visualY
    self.moveToX = self.visualX
    self.moveToY = self.visualY
    self.moveProgress = 1
    self.nextMoveMs = 0
    self.cameraY = 0
    self.effects = {}
    self.particles = {}
    self.lastWarningSecond = 6
    self.lastMs = playdate.getCurrentTimeMilliseconds()
end

function Game:addEffect(text, col, row)
    table.insert(self.effects, {
        text = text,
        x = (col - 0.5) * World.TILE,
        y = (row - 0.5) * World.TILE,
        age = 0,
    })
end

function Game:addDigParticles(col, row)
    local cx = (col - 0.5) * World.TILE
    local cy = (row - 0.5) * World.TILE
    for i = 1, 5 do
        table.insert(self.particles, {
            x = cx + math.random(-6, 6),
            y = cy + math.random(-5, 5),
            vx = math.random(-24, 24),
            vy = math.random(-28, -8),
            age = 0,
            life = 0.22 + math.random() * 0.18,
        })
    end
end

function Game:collectAtPlayer()
    local item = self.world:collect(self.col, self.row)
    if not item then
        return
    end

    if item.kind == "worm" then
        self.timeLeft = self.timeLeft + item.seconds
        self:addEffect(item.label, self.col, self.row)
        self.audio:worm(item.seconds)
    else
        self.score = self.score + item.value
        self:addEffect(item.label, self.col, self.row)
        self.audio:treasure(item.kind)
    end
end

function Game:tryMove(deltaCol, deltaRow, direction, nowMs)
    if self.moveProgress < 1 then
        return
    end

    local newCol = self.col + deltaCol
    local newRow = self.row + deltaRow
    if not self.world:isInside(newCol, newRow) then
        return
    end

    self.facing = direction
    self.moveFromX = self.visualX
    self.moveFromY = self.visualY
    self.col = newCol
    self.row = newRow
    self.moveToX = (self.col - 0.5) * World.TILE
    self.moveToY = (self.row - 0.5) * World.TILE
    self.moveProgress = 0
    self.nextMoveMs = nowMs + MOVE_REPEAT_MS

    if self.world:dig(self.col, self.row) then
        self:addDigParticles(self.col, self.row)
        self.audio:dig()
    end

    self.maxDepth = math.max(self.maxDepth, self.row - 3)
    self:collectAtPlayer()
end

function Game:updateMovement(dt, nowMs)
    if self.moveProgress < 1 then
        self.moveProgress = math.min(1, self.moveProgress + dt / MOVE_DURATION)
        local t = easeOut(self.moveProgress)
        self.visualX = self.moveFromX + (self.moveToX - self.moveFromX) * t
        self.visualY = self.moveFromY + (self.moveToY - self.moveFromY) * t
    end

    local justLeft = playdate.buttonJustPressed(playdate.kButtonLeft)
    local justRight = playdate.buttonJustPressed(playdate.kButtonRight)
    local justDown = playdate.buttonJustPressed(playdate.kButtonDown)
    local repeatReady = nowMs >= self.nextMoveMs

    if justLeft or (repeatReady and playdate.buttonIsPressed(playdate.kButtonLeft)) then
        self:tryMove(-1, 0, "left", nowMs)
    elseif justRight or (repeatReady and playdate.buttonIsPressed(playdate.kButtonRight)) then
        self:tryMove(1, 0, "right", nowMs)
    elseif justDown or (repeatReady and playdate.buttonIsPressed(playdate.kButtonDown)) then
        self:tryMove(0, 1, "down", nowMs)
    end
end

function Game:updateEffects(dt)
    for i = #self.effects, 1, -1 do
        local effect = self.effects[i]
        effect.age = effect.age + dt
        if effect.age > 0.75 then
            table.remove(self.effects, i)
        end
    end

    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.age = particle.age + dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.vy = particle.vy + 90 * dt
        if particle.age > particle.life then
            table.remove(self.particles, i)
        end
    end
end

function Game:update()
    local nowMs = playdate.getCurrentTimeMilliseconds()
    local dt = clamp((nowMs - self.lastMs) / 1000, 0, 0.1)
    self.lastMs = nowMs
    self.titleBob = self.titleBob + dt

    if self.state == "title" then
        if playdate.buttonJustPressed(playdate.kButtonA)
            or playdate.buttonJustPressed(playdate.kButtonLeft)
            or playdate.buttonJustPressed(playdate.kButtonRight)
            or playdate.buttonJustPressed(playdate.kButtonDown) then
            self:start()
        end
        return
    end

    if self.state == "gameOver" then
        self:updateEffects(dt)
        if playdate.buttonJustPressed(playdate.kButtonA)
            or playdate.buttonJustPressed(playdate.kButtonDown) then
            self:start()
        end
        return
    end

    self.timeLeft = math.max(0, self.timeLeft - dt)
    local warningSecond = math.ceil(self.timeLeft)
    if warningSecond <= 5 and warningSecond < self.lastWarningSecond and warningSecond > 0 then
        self.lastWarningSecond = warningSecond
        self.audio:warning()
    end

    self:updateMovement(dt, nowMs)
    self:updateEffects(dt)

    local targetCamera = math.max(0, self.visualY - 132)
    self.cameraY = self.cameraY + (targetCamera - self.cameraY) * math.min(1, dt * 8)

    if self.timeLeft <= 0 then
        self.state = "gameOver"
        self.audio:gameOver()
    end
end

function Game:drawMole()
    local x = self.visualX
    local y = self.visualY - self.cameraY
    local moving = self.moveProgress < 1
    local squash = moving and math.sin(self.moveProgress * math.pi) * 2 or 0

    gfx.setColor(gfx.kColorBlack)
    gfx.fillEllipseInRect(x - 8 - squash, y - 7 + squash / 2, 16 + squash * 2, 15 - squash)

    if self.facing == "left" then
        gfx.fillPolygon(x - 11 - squash, y, x - 5, y - 5, x - 5, y + 5)
    elseif self.facing == "right" then
        gfx.fillPolygon(x + 11 + squash, y, x + 5, y - 5, x + 5, y + 5)
    else
        gfx.fillPolygon(x, y + 11, x - 5, y + 5, x + 5, y + 5)
    end

    gfx.setColor(gfx.kColorWhite)
    local eyeX = self.facing == "left" and x - 3 or self.facing == "right" and x + 3 or x - 3
    gfx.fillCircleAtPoint(eyeX, y - 2, 2)
    if self.facing == "down" then
        gfx.fillCircleAtPoint(x + 3, y - 2, 2)
    end
end

function Game:drawEffects()
    gfx.setColor(gfx.kColorBlack)
    for _, effect in ipairs(self.effects) do
        local y = effect.y - self.cameraY - effect.age * 22
        local width = gfx.getTextSize(effect.text)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(effect.x - width / 2 - 2, y - 1, width + 4, 14, 2)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText(effect.text, effect.x - width / 2, y)
    end

    for _, particle in ipairs(self.particles) do
        local size = particle.age < particle.life * 0.55 and 2 or 1
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(particle.x, particle.y - self.cameraY, size, size)
    end
end

function Game:drawHud()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 27)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawText("SCORE " .. tostring(self.score), 8, 6)
    gfx.drawText("TIME " .. string.format("%02d", math.ceil(self.timeLeft)), 160, 6)
    gfx.drawText("DEPTH " .. tostring(self.maxDepth) .. "m", 287, 6)

    if self.timeLeft <= 5 and math.floor(self.timeLeft * 5) % 2 == 0 then
        gfx.drawRect(151, 3, 85, 21)
    end
end

function Game:drawTitle()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(48, 44, 304, 151)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(4)
    gfx.drawRect(48, 44, 304, 151)
    gfx.setLineWidth(1)

    local bob = math.sin(self.titleBob * 4) * 3
    gfx.fillEllipseInRect(178, 61 + bob, 44, 34)
    gfx.fillPolygon(200, 104 + bob, 190, 88 + bob, 210, 88 + bob)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(192, 73 + bob, 3)
    gfx.fillCircleAtPoint(208, 73 + bob, 3)

    gfx.setColor(gfx.kColorBlack)
    centerText("MOLE DOWN!", 111)
    centerText("DIG  FIND  GO DEEP", 137)
    centerText("LEFT / RIGHT / DOWN", 158)
    centerText("PRESS A OR A DIRECTION", 176)
end

function Game:drawGameOver()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(65, 52, 270, 145, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(4)
    gfx.drawRoundRect(65, 52, 270, 145, 8)
    gfx.setLineWidth(1)
    centerText("TIME'S UP!", 70)
    centerText("SCORE  " .. tostring(self.score), 105)
    centerText("DEPTH  " .. tostring(self.maxDepth) .. "m", 128)
    centerText("PRESS A OR DOWN TO RESTART", 164)
end

function Game:draw()
    self.world:draw(self.cameraY)

    if self.state == "title" then
        self:drawTitle()
        return
    end

    self:drawMole()
    self:drawEffects()
    self:drawHud()

    if self.state == "gameOver" then
        self:drawGameOver()
    end
end
