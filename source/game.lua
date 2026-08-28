local gfx = playdate.graphics

local moleDownFrames = assert(gfx.imagetable.new("assets/Mole_Front_Dig_Down"))
local moleSideFrames = assert(gfx.imagetable.new("assets/Mole_Left_Right_Sheet"))

Game = {}
Game.__index = Game

local START_TIME = 30
local MOVE_DURATION = 0.09
local MOVE_REPEAT_MS = 115
local MOLE_DOWN_SCALE = 1.25
local MOLE_SIDE_SCALE = 1
local MOLE_DOWN_Y_OFFSET = -2
local MOLE_SIDE_Y_OFFSET = -5
local MOVE_SPEED_DURATION = 10
local MOVE_SPEED_MULTIPLIER = 1.5
local NORMAL_CRANK_THRESHOLD = 10
local CRANK_PROMPT_TEXT = "CRANK!"
local CRANK_PROMPT_CENTER_Y = 22
local CRANK_PROMPT_MIN_SCALE = 1
local CRANK_PROMPT_MAX_SCALE = 1.4
local CRANK_PROMPT_PULSE_MS = 45
local crankPromptImage = assert(gfx.imageWithText(CRANK_PROMPT_TEXT, 80, 20))
local crankPromptWidth, crankPromptHeight = crankPromptImage:getSize()
local TIMER_WARNING_SECONDS = 5
local TIMER_TEXT_X = 8
local TIMER_TEXT_Y = 23
local TIMER_WARNING_BOX_X = 3
local TIMER_WARNING_BOX_Y = 20
local TIMER_WARNING_BOX_WIDTH = 88
local TIMER_WARNING_BOX_HEIGHT = 20
local TIMER_TEXT_CENTER_Y = TIMER_WARNING_BOX_Y + TIMER_WARNING_BOX_HEIGHT / 2
local TIMER_TEXT_MIN_SCALE = 0.72
local TIMER_TEXT_MAX_SCALE = 1
local TIMER_TEXT_PULSE_MS = 55
local timerWarningImages = {}

for seconds = 0, TIMER_WARNING_SECONDS do
    local text = "TIME " .. string.format("%02d", seconds)
    local image = assert(gfx.imageWithText(text, 90, 20))
    local width, height = image:getSize()
    timerWarningImages[seconds] = {
        image = image,
        width = width,
        height = height,
    }
end

-- Builds a stable lookup key for anything stored at a world grid cell.
local function worldCellKey(col, row)
    return col .. ":" .. row
end

-- Restricts a number so it stays within the requested minimum and maximum.
local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

-- Smooths movement animation so it slows gently as it reaches the target tile.
local function easeOut(t)
    return 1 - (1 - t) * (1 - t)
end

-- Draws an image centered on a point while applying scale and vertical offset.
local function drawImageCenteredScaled(image, x, y, scale, yOffset)
    local width, height = image:getSize()
    local drawX = math.floor(x - width * scale / 2)
    local drawY = math.floor(y - height * scale / 2 + yOffset)
    if scale == 1 then
        image:draw(drawX, drawY)
    else
        image:drawScaled(drawX, drawY, scale)
    end
end

-- Draws text centered horizontally on the Playdate screen.
local function centerText(text, y)
    local width = gfx.getTextSize(text)
    gfx.drawText(text, 200 - width / 2, y)
end

-- Draws text so its right edge lines up with the requested x position.
local function rightText(text, rightX, y)
    local width = gfx.getTextSize(text)
    gfx.drawText(text, rightX - width, y)
end

-- Draws the combat prompt centered in the HUD while pulsing its size for urgency.
local function drawCrankPrompt()
    local pulse = (math.sin(playdate.getCurrentTimeMilliseconds() / CRANK_PROMPT_PULSE_MS) + 1) / 2
    local scale = CRANK_PROMPT_MIN_SCALE
        + (CRANK_PROMPT_MAX_SCALE - CRANK_PROMPT_MIN_SCALE) * pulse
    local x = math.floor(200 - crankPromptWidth * scale / 2)
    local y = math.floor(CRANK_PROMPT_CENTER_Y - crankPromptHeight * scale / 2)
    crankPromptImage:drawScaled(x, y, scale)
end

-- Draws the timer normally, then switches to a pulsing warning style at five seconds.
local function drawTimer(timeLeft)
    local seconds = math.ceil(timeLeft)
    if seconds > TIMER_WARNING_SECONDS then
        gfx.drawText("TIME " .. string.format("%02d", seconds), TIMER_TEXT_X, TIMER_TEXT_Y)
        return
    end

    seconds = clamp(seconds, 0, TIMER_WARNING_SECONDS)
    local timerImage = timerWarningImages[seconds]
    local pulse = (math.sin(playdate.getCurrentTimeMilliseconds() / TIMER_TEXT_PULSE_MS) + 1) / 2
    local scale = TIMER_TEXT_MAX_SCALE
        - (TIMER_TEXT_MAX_SCALE - TIMER_TEXT_MIN_SCALE) * pulse
    local x = math.floor(TIMER_TEXT_X + timerImage.width / 2 - timerImage.width * scale / 2)
    local y = math.floor(TIMER_TEXT_CENTER_Y - timerImage.height * scale / 2)
    timerImage.image:drawScaled(x, y, scale)
end

-- Creates a new game controller with world, audio, save data, and title state.
function Game.new()
    local self = setmetatable({}, Game)
    self.audio = Audio.new()
    self.world = World.new()
    local saveData = playdate.datastore.read("save")
    self.highScore = type(saveData) == "table" and saveData.highScore or 0
    self.state = "title"
    self.lastMs = playdate.getCurrentTimeMilliseconds()
    self.titleBob = 0
    self.effects = {}
    self.particles = {}
    self.combatEnemy = nil
    self.cameraY = 0
    self.audio:playMenuMusic()
    return self
end

-- Saves a new high score when the current run beats the stored best score.
function Game:saveHighScore()
    if self.score <= self.highScore then
        return
    end

    self.highScore = self.score
    playdate.datastore.write({ highScore = self.highScore }, "save")
end

-- Starts or restarts a run by resetting player, timer, camera, buffs, and world state.
function Game:start()
    self.world:reset()
    self.state = "playing"
    self.audio:playGameMusic()
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
    self.currentMoveDuration = MOVE_DURATION
    self.nextMoveMs = 0
    self.cameraY = 0
    self.effects = {}
    self.particles = {}
    self.combatEnemy = nil
    self.moveSpeedBuff = 0
    self.strengthBuff = 0
    self.strengthBuffTimer = 0
    self.lastWarningSecond = 6
    self.lastMs = playdate.getCurrentTimeMilliseconds()
end

-- Adds a floating text effect at a grid cell for pickups, damage, and rewards.
function Game:addEffect(text, col, row)
    table.insert(self.effects, {
        text = text,
        x = (col - 0.5) * World.TILE,
        y = (row - 0.5) * World.TILE,
        age = 0,
    })
end

-- Spawns small dirt particles around a newly dug grid cell.
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

-- Collects an item under the player and applies its score, time, or buff effect.
function Game:collectAtPlayer()
    local item = self.world:collect(self.col, self.row)
    if not item then
        return
    end

    if item.kind == "worm" then
        self.timeLeft += item.seconds
        self:addEffect(item.label, self.col, self.row)
        self.audio:worm(item.seconds)
    elseif item.kind == "move_speed" then
        self.moveSpeedBuff = math.max(
            self.moveSpeedBuff,
            item.seconds or MOVE_SPEED_DURATION
        )
        self:addEffect(item.label, self.col, self.row)
        self.audio:powerUp()
    elseif item.kind == "strength" then
        self.strengthBuff = math.min(self.strengthBuff + 1, 3)
        self.strengthBuffTimer = math.max(
            self.strengthBuffTimer,
            item.seconds or 10
        )
        self:addEffect("POWER x" .. tostring(self.strengthBuff), self.col, self.row)
        self.audio:powerUp()
    else
        self.score += item.value
        self:addEffect(item.label, self.col, self.row)
        self.audio:treasure(item.kind)
    end
end

-- Detects whether the player is standing on an enemy and starts combat if needed.
function Game:checkEnemyCollision()
    for _, enemy in ipairs(self.world.enemies) do
        if enemy.col == self.col and enemy.row == self.row then
            self.combatEnemy = enemy
            enemy.state = "combat"
            self.audio:enemyEncounter()
            return true
        end
    end
    return false
end

-- Removes a defeated enemy, awards points, drops loot, and exits combat state.
function Game:killEnemy(enemy)
    for i = #self.world.enemies, 1, -1 do
        if self.world.enemies[i] == enemy then
            table.remove(self.world.enemies, i)
            break
        end
    end

    self.score += 25
    self:addEffect("+25", enemy.col, enemy.row)

    local drop = self.world:makeEnemyDrop(enemy)
    if drop then
        drop.col = enemy.col
        drop.row = enemy.row
        self.world.items[worldCellKey(enemy.col, enemy.row)] = drop
    end

    self.audio:enemyDefeated()
    self.combatEnemy = nil
    self.moveProgress = 1
    self.visualX = (self.col - 0.5) * World.TILE
    self.visualY = (self.row - 0.5) * World.TILE
    self.nextMoveMs = 0
end

-- Handles crank-based combat damage while the player is touching an enemy.
function Game:updateCombat()
    local enemy = self.combatEnemy
    if not enemy then
        return
    end

    local crankChange = playdate.getCrankChange()
    if math.abs(crankChange) >= NORMAL_CRANK_THRESHOLD then
        local damage = 1 + self.strengthBuff
        enemy.hp -= damage
        self:addEffect("-" .. tostring(damage), enemy.col, enemy.row)
        self.audio:combatHit()
        if enemy.hp <= 0 then
            self:killEnemy(enemy)
        end
    end
end

-- Attempts to move the player by one grid cell and handles digging, pickups, and collisions.
function Game:tryMove(deltaCol, deltaRow, direction, nowMs)
    if self.moveProgress < 1 then
        return
    end

    local moveDuration = MOVE_DURATION
    local moveRepeat = MOVE_REPEAT_MS
    if self.moveSpeedBuff > 0 then
        moveDuration = MOVE_DURATION / MOVE_SPEED_MULTIPLIER
        moveRepeat = MOVE_REPEAT_MS / MOVE_SPEED_MULTIPLIER
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
    self.currentMoveDuration = moveDuration
    self.nextMoveMs = nowMs + moveRepeat
    self.audio:move()

    if self.world:dig(self.col, self.row) then
        self:addDigParticles(self.col, self.row)
    end

    self.maxDepth = math.max(self.maxDepth, self.row - 3)
    self:collectAtPlayer()
    self:checkEnemyCollision()
end

-- Updates movement animation and reads held or newly pressed direction buttons.
function Game:updateMovement(dt, nowMs)
    if self.moveProgress < 1 then
        local moveDuration = self.currentMoveDuration or MOVE_DURATION
        self.moveProgress = math.min(1, self.moveProgress + dt / moveDuration)
        local t = easeOut(self.moveProgress)
        self.visualX = self.moveFromX + (self.moveToX - self.moveFromX) * t
        self.visualY = self.moveFromY + (self.moveToY - self.moveFromY) * t
    end

    if self.combatEnemy then
        return
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

-- Counts down temporary speed and strength buffs and clears them when they expire.
function Game:updateBuffs(dt)
    if self.moveSpeedBuff > 0 then
        self.moveSpeedBuff = math.max(0, self.moveSpeedBuff - dt)
    end

    if self.strengthBuffTimer > 0 then
        self.strengthBuffTimer = math.max(0, self.strengthBuffTimer - dt)
        if self.strengthBuffTimer <= 0 then
            self.strengthBuff = 0
        end
    end
end

-- Advances floating text and dirt particles, removing them after their lifetime ends.
function Game:updateEffects(dt)
    for i = #self.effects, 1, -1 do
        local effect = self.effects[i]
        effect.age += dt
        if effect.age > 0.75 then
            table.remove(self.effects, i)
        end
    end

    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.age += dt
        particle.x += particle.vx * dt
        particle.y += particle.vy * dt
        particle.vy += 90 * dt
        if particle.age > particle.life then
            table.remove(self.particles, i)
        end
    end
end

-- Advances all game state for the current frame, including title, play, and game-over flow.
function Game:update()
    local nowMs = playdate.getCurrentTimeMilliseconds()
    local dt = clamp((nowMs - self.lastMs) / 1000, 0, 0.1)
    self.lastMs = nowMs
    self.titleBob += dt

    if self.state == "title" then
        if playdate.buttonJustPressed(playdate.kButtonLeft)
            or playdate.buttonJustPressed(playdate.kButtonRight)
            or playdate.buttonJustPressed(playdate.kButtonDown) then
            self:start()
            self:updateMovement(dt, nowMs)
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
    self:updateBuffs(dt)
    local warningSecond = math.ceil(self.timeLeft)
    if warningSecond <= 5 and warningSecond < self.lastWarningSecond and warningSecond > 0 then
        self.lastWarningSecond = warningSecond
        self.audio:warning()
    end

    self:updateMovement(dt, nowMs)
    self.world:updateEnemies(dt)
    if not self.combatEnemy then
        self:checkEnemyCollision()
    end
    self:updateCombat()
    self:updateEffects(dt)

    local targetCamera = math.max(0, self.visualY - 132)
    self.cameraY += (targetCamera - self.cameraY) * math.min(1, dt * 8)

    if self.timeLeft <= 0 then
        self:saveHighScore()
        self.state = "gameOver"
        self.audio:stopMusic()
        self.audio:gameOver()
        self.audio:playMenuMusic()
    end
end

-- Draws the mole with the correct animation frames for movement and facing direction.
function Game:drawMole()
    local x = self.visualX
    local y = self.visualY - self.cameraY
    local moving = self.moveProgress < 1

    if self.facing == "down" then
        local frameIndex = 1
        if moving then
            frameIndex = math.min(4, math.floor(self.moveProgress * 4) + 1)
        end
        drawImageCenteredScaled(
            moleDownFrames:getImage(frameIndex),
            x,
            y,
            MOLE_DOWN_SCALE,
            MOLE_DOWN_Y_OFFSET
        )
        return
    end

    local animationFrame = moving
        and (math.floor(playdate.getCurrentTimeMilliseconds() / 70) % 8)
        or 0
    local frameIndex = self.facing == "left"
        and (25 + animationFrame)
        or (16 - animationFrame)
    drawImageCenteredScaled(
        moleSideFrames:getImage(frameIndex),
        x,
        y,
        MOLE_SIDE_SCALE,
        MOLE_SIDE_Y_OFFSET
    )
end

-- Draws floating text popups and short-lived dirt particles.
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

-- Draws the score, timer, depth, high score, combat prompt, and active buff indicators.
function Game:drawHud()
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, 0, 400, 43)
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawText("SCORE " .. tostring(self.score), 8, 6)
    rightText("HIGH SCORE " .. tostring(self.highScore), 392, 6)
    if self.timeLeft <= TIMER_WARNING_SECONDS
        and math.floor(self.timeLeft * 5) % 2 == 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.drawRect(
            TIMER_WARNING_BOX_X,
            TIMER_WARNING_BOX_Y,
            TIMER_WARNING_BOX_WIDTH,
            TIMER_WARNING_BOX_HEIGHT
        )
    end
    drawTimer(self.timeLeft)
    rightText("DEPTH " .. tostring(self.maxDepth) .. "m", 392, 23)
    if self.combatEnemy then
        drawCrankPrompt()
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    local buffY = 46
    if self.moveSpeedBuff > 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(6, buffY, 74, 16, 3)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRoundRect(6, buffY, 74, 16, 3)
        gfx.drawText("SPD " .. tostring(math.ceil(self.moveSpeedBuff)), 11, buffY + 2)
    end

    if self.strengthBuff > 0 then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRoundRect(84, buffY, 104, 16, 3)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRoundRect(84, buffY, 104, 16, 3)
        gfx.drawText(
            "PWR x" .. tostring(self.strengthBuff)
                .. " " .. tostring(math.ceil(self.strengthBuffTimer)),
            89,
            buffY + 2
        )
    end
end

-- Draws the title screen panel and animated mole prompt.
function Game:drawTitle()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(48, 44, 304, 151)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(4)
    gfx.drawRect(48, 44, 304, 151)
    gfx.setLineWidth(1)

    gfx.setColor(gfx.kColorBlack)
    centerText("HOLEY MOLE-Y!", 54)

    local bob = math.sin(self.titleBob * 4) * 3
    drawImageCenteredScaled(
        moleDownFrames:getImage(1),
        200,
        89 + bob,
        2,
        -4
    )

    gfx.setColor(gfx.kColorBlack)
    centerText("DIG  FIND  GO DEEP", 115)
    centerText("LEFT / RIGHT / DOWN", 143)
    centerText("PRESS A OR A DIRECTION", 169)
end

-- Draws the end-of-run summary and restart prompt.
function Game:drawGameOver()
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(65, 52, 270, 145, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(4)
    gfx.drawRoundRect(65, 52, 270, 145, 8)
    gfx.setLineWidth(1)
    centerText("TIME'S UP!", 70)
    centerText("SCORE  " .. tostring(self.score), 98)
    centerText("HIGH SCORE  " .. tostring(self.highScore), 121)
    centerText("DEPTH  " .. tostring(self.maxDepth) .. "m", 144)
    centerText("PRESS A OR DOWN TO RESTART", 170)
end

-- Draws the world and the appropriate title, gameplay, or game-over overlays.
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
