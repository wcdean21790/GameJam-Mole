local gfx = playdate.graphics
local wormFrames = assert(gfx.imagetable.new("assets/Worm"))
local treasureFrames = assert(gfx.imagetable.new("assets/Treasure"))
local enemyFrames = assert(gfx.imagetable.new("assets/Enemy"))

World = {}
World.__index = World

local TILE = 20
local COLS = 20
local CHUNK_HEIGHT = 8
local MAX_ENEMIES_PER_CHUNK = 6

local enemyKinds = { "skunk", "gopher", "vole" }

local chunkRolePatterns = {
    { "treasure", "worm", "treasure", "treasure", "treasure" },
    { "treasure", "treasure", "worm", "treasure", "treasure" },
    { "worm", "treasure", "treasure", "treasure", "worm" },
    { "treasure", "treasure", "worm", "treasure", "treasure" },
}

local function cellKey(col, row)
    return col .. ":" .. row
end

function World.new()
    local self = setmetatable({}, World)
    self:reset()
    return self
end

function World:reset()
    self.dug = {}
    self.items = {}
    self.enemies = {}
    self.chunkCount = 0
    self.generatedBottom = 3
    self.dug[cellKey(10, 3)] = true
    self:ensureThroughRow(40)
end

function World:makeTreasure(chunkIndex)
    local roll = math.random()
    local diamondChance = math.min(0.08 + chunkIndex * 0.012, 0.30)
    local goldChance = math.min(0.25 + chunkIndex * 0.015, 0.48)
    if roll < diamondChance then
        return { kind = "diamond", value = 200, label = "+200" }
    elseif roll < diamondChance + goldChance then
        return { kind = "gold", value = 50, label = "+50" }
    end
    return { kind = "gem", value = 10, label = "+10" }
end

function World:makeWorm(chunkIndex)
    local roll = math.random()
    if chunkIndex >= 6 and roll < 0.16 then
        return { kind = "worm", seconds = 10, label = "+10s" }
    elseif chunkIndex >= 3 and roll < 0.42 then
        return { kind = "worm", seconds = 5, label = "+5s" }
    end
    return { kind = "worm", seconds = 2, label = "+2s" }
end

function World:makeEnemyDrop(enemy)
    local chunkIndex = enemy.chunkIndex or 1
    local depth = (chunkIndex - 1) * CHUNK_HEIGHT
    local depthFactor = math.min(depth / 200, 1)
    local dropChance = 0.35 + 0.50 * depthFactor

    if math.random() > dropChance then
        return nil
    end

    local wormChance = 0.18 + 0.045 * depthFactor
    local treasureChance = 0.14 + 0.21 * depthFactor
    local roll = math.random()

    if roll < wormChance then
        local item = self:makeWorm(chunkIndex)
        item.dropped = true
        return item
    elseif roll < wormChance + treasureChance then
        local item = self:makeTreasure(chunkIndex)
        item.dropped = true
        return item
    elseif math.random() < 0.5 then
        return {
            kind = "move_speed",
            seconds = 10,
            label = "SPEED BUFF!",
            dropped = true,
        }
    end

    return {
        kind = "strength",
        seconds = 10,
        label = "POWER BUFF!",
        dropped = true,
    }
end

local function enemiesForChunk(chunkIndex)
    if chunkIndex <= 5 then
        return 1
    elseif chunkIndex <= 15 then
        return 2
    elseif chunkIndex <= 35 then
        return 3
    elseif chunkIndex <= 50 then
        return 4
    elseif chunkIndex <= 100 then
        return 5
    end
    return MAX_ENEMIES_PER_CHUNK
end

local function enemyMoveInterval(chunkIndex)
    return math.max(0.40, 0.70 - (chunkIndex - 1) * 0.01)
end

function World:makeEnemy(chunkIndex, occupiedCells)
    local baseRow = 3 + (chunkIndex - 1) * CHUNK_HEIGHT
    local minRow = math.max(3, baseRow - CHUNK_HEIGHT)
    local maxRow = baseRow + CHUNK_HEIGHT * 2
    local spawnCol
    local spawnRow

    for _ = 1, 30 do
        local col = math.random(1, COLS)
        local row = math.random(minRow, maxRow)
        local key = cellKey(col, row)
        local occupiedByEnemy = false

        for _, enemy in ipairs(self.enemies) do
            if enemy.col == col and enemy.row == row then
                occupiedByEnemy = true
                break
            end
        end

        if not occupiedCells[key]
            and not self.items[key]
            and not occupiedByEnemy
            and not (col == 10 and row == 3) then
            spawnCol = col
            spawnRow = row
            occupiedCells[key] = true
            break
        end
    end

    if not spawnCol then
        return nil
    end

    local moveInterval = enemyMoveInterval(chunkIndex)
    local maxHP = math.min(3 + math.floor((chunkIndex - 1) / 3), 10)
    return {
        kind = enemyKinds[math.random(1, #enemyKinds)],
        state = "roaming",
        col = spawnCol,
        row = spawnRow,
        moveTimer = moveInterval,
        moveInterval = moveInterval,
        direction = math.random(1, 4),
        chunkIndex = chunkIndex,
        minCol = 1,
        maxCol = COLS,
        minRow = minRow,
        maxRow = maxRow,
        hp = maxHP,
        maxHP = maxHP,
    }
end

function World:updateEnemies(dt)
    for _, enemy in ipairs(self.enemies) do
        if enemy.state ~= "combat" then
            enemy.moveTimer -= dt
            if enemy.moveTimer <= 0 then
                enemy.moveTimer = enemy.moveInterval

                local changeChance = math.min(0.35 + enemy.chunkIndex * 0.02, 0.60)
                if math.random() < changeChance then
                    enemy.direction = math.random(1, 4)
                end

                local newCol = enemy.col
                local newRow = enemy.row
                if enemy.direction == 1 then
                    newCol -= 1
                elseif enemy.direction == 2 then
                    newCol += 1
                elseif enemy.direction == 3 then
                    newRow -= 1
                else
                    newRow += 1
                end

                if newCol >= enemy.minCol
                    and newCol <= enemy.maxCol
                    and newRow >= enemy.minRow
                    and newRow <= enemy.maxRow then
                    enemy.col = newCol
                    enemy.row = newRow
                else
                    enemy.direction = math.random(1, 4)
                end
            end
        end
    end
end

function World:hasEnemyAt(col, row)
    for _, enemy in ipairs(self.enemies) do
        if enemy.col == col and enemy.row == row then
            return true
        end
    end
    return false
end

function World:generateChunk()
    self.chunkCount += 1
    local chunkIndex = self.chunkCount
    local roles = chunkRolePatterns[((chunkIndex - 1) % #chunkRolePatterns) + 1]
    local baseRow = 3 + (chunkIndex - 1) * CHUNK_HEIGHT
    local usedCells = {}

    for _, role in ipairs(roles) do
        local col
        local row
        local key
        repeat
            col = math.random(2, COLS - 1)
            row = baseRow + math.random(1, CHUNK_HEIGHT)
            key = cellKey(col, row)
        until not usedCells[key] and not self:hasEnemyAt(col, row)

        usedCells[key] = true
        local item = role == "worm" and self:makeWorm(chunkIndex) or self:makeTreasure(chunkIndex)
        item.col = col
        item.row = row
        self.items[key] = item
    end

    for _ = 1, enemiesForChunk(chunkIndex) do
        local enemy = self:makeEnemy(chunkIndex, usedCells)
        if enemy then
            table.insert(self.enemies, enemy)
        end
    end

    self.generatedBottom = baseRow + CHUNK_HEIGHT
end

function World:ensureThroughRow(row)
    while self.generatedBottom < row do
        self:generateChunk()
    end
end

function World:isInside(col, row)
    return col >= 1 and col <= COLS and row >= 3
end

function World:isDug(col, row)
    return self.dug[cellKey(col, row)] == true
end

function World:dig(col, row)
    local key = cellKey(col, row)
    if self.dug[key] then
        return false
    end
    self.dug[key] = true
    self:ensureThroughRow(row + 24)
    return true
end

function World:collect(col, row)
    local key = cellKey(col, row)
    local item = self.items[key]
    self.items[key] = nil
    return item
end

local function drawDirtTexture(col, row, x, y)
    gfx.setColor(gfx.kColorWhite)
    local seed = col * 17 + row * 31
    gfx.drawPixel(x + 3 + (seed % 13), y + 4 + (seed % 5))
    gfx.drawPixel(x + 2 + ((seed * 3) % 15), y + 12 + (seed % 4))
    if (col + row) % 3 == 0 then
        gfx.drawLine(x + 4, y + 8, x + 7, y + 8)
    end
end

local function drawTreasure(item, cx, cy)
    gfx.setColor(item.dropped and gfx.kColorBlack or gfx.kColorWhite)
    if item.kind == "gem" then
        local frameIndex = math.floor(playdate.getCurrentTimeMilliseconds() / 150) % 4 + 1
        if item.dropped then
            gfx.setImageDrawMode(gfx.kDrawModeInverted)
        end
        treasureFrames:getImage(frameIndex):drawCentered(cx, cy)
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
    elseif item.kind == "gold" then
        gfx.fillRoundRect(cx - 7, cy - 5, 14, 10, 3)
        gfx.setColor(item.dropped and gfx.kColorWhite or gfx.kColorBlack)
        gfx.drawText("G", cx - 3, cy - 6)
    elseif item.kind == "diamond" then
        gfx.fillPolygon(cx, cy - 8, cx + 8, cy - 2, cx + 5, cy + 6, cx, cy + 9, cx - 5, cy + 6, cx - 8, cy - 2)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(cx - 5, cy - 2, cx + 5, cy - 2)
        gfx.drawLine(cx, cy - 7, cx, cy + 6)
    end
end

local function drawWorm(item, cx, cy)
    local frameIndex = math.floor(playdate.getCurrentTimeMilliseconds() / 140) % 4 + 1
    if item.dropped then
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
    end
    wormFrames:getImage(frameIndex):drawCentered(cx, cy)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

local function drawPowerUp(item, cx, cy)
    gfx.setColor(item.dropped and gfx.kColorBlack or gfx.kColorWhite)
    if item.kind == "move_speed" then
        gfx.fillPolygon(
            cx + 2, cy - 9,
            cx - 6, cy + 1,
            cx - 1, cy + 1,
            cx - 4, cy + 9,
            cx + 7, cy - 3,
            cx + 1, cy - 3
        )
    else
        gfx.fillRect(cx - 6, cy - 5, 12, 11)
        gfx.fillRect(cx - 8, cy - 2, 3, 7)
        gfx.fillRect(cx - 5, cy - 8, 3, 7)
        gfx.fillRect(cx - 1, cy - 9, 3, 8)
        gfx.fillRect(cx + 3, cy - 7, 3, 6)
    end
end

local function drawEnemy(enemy, cx, cy, inTunnel)
    local frameIndex = math.floor(playdate.getCurrentTimeMilliseconds() / 140) % 3 + 1
    local image = enemyFrames:getImage(frameIndex)
    gfx.setImageDrawMode(inTunnel and gfx.kDrawModeCopy or gfx.kDrawModeFillWhite)

    if enemy.direction == 1 then
        image:drawCentered(cx, cy, gfx.kImageFlippedX)
    elseif enemy.direction == 2 then
        image:drawCentered(cx, cy)
    elseif enemy.direction == 3 then
        image:drawRotated(cx, cy, -90)
    else
        image:drawRotated(cx, cy, 90)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function World:draw(cameraY)
    local firstRow = math.max(1, math.floor(cameraY / TILE) + 1)
    local lastRow = firstRow + 13
    self:ensureThroughRow(lastRow + 16)

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)

    for row = firstRow, lastRow do
        local y = (row - 1) * TILE - cameraY
        if row >= 3 then
            for col = 1, COLS do
                local x = (col - 1) * TILE
                if not self:isDug(col, row) then
                    gfx.setColor(gfx.kColorBlack)
                    gfx.fillRect(x, y, TILE, TILE)
                    drawDirtTexture(col, row, x, y)
                else
                    gfx.setColor(gfx.kColorBlack)
                    if (col + row) % 2 == 0 then
                        gfx.drawPixel(x + 2, y + 2)
                        gfx.drawPixel(x + 17, y + 16)
                    end
                end
            end
        end
    end

    local surfaceY = 40 - cameraY
    if surfaceY > -10 and surfaceY < 250 then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, surfaceY - 3, 400, 3)
        for x = 0, 399, 12 do
            gfx.drawLine(x, surfaceY - 3, x + 5, surfaceY - 7)
        end
    end

    for _, item in pairs(self.items) do
        local y = (item.row - 1) * TILE - cameraY + TILE / 2
        if y > -12 and y < 252 then
            local x = (item.col - 1) * TILE + TILE / 2
            if item.kind == "worm" then
                drawWorm(item, x, y)
            elseif item.kind == "move_speed" or item.kind == "strength" then
                drawPowerUp(item, x, y)
            else
                drawTreasure(item, x, y)
            end
        end
    end

    for _, enemy in ipairs(self.enemies) do
        local y = (enemy.row - 1) * TILE - cameraY + TILE / 2
        if y > -14 and y < 254 then
            local x = (enemy.col - 1) * TILE + TILE / 2
            local inTunnel = self:isDug(enemy.col, enemy.row)
            drawEnemy(enemy, x, y, inTunnel)

            if enemy.state == "combat" then
                local barWidth = 18
                local barX = x - barWidth / 2
                local barY = y - 14
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRect(barX, barY, barWidth, 5)
                gfx.setColor(gfx.kColorBlack)
                gfx.drawRect(barX, barY, barWidth, 5)
                local fillWidth = math.floor((barWidth - 2) * enemy.hp / enemy.maxHP)
                if fillWidth > 0 then
                    gfx.fillRect(barX + 1, barY + 1, fillWidth, 3)
                end
            end
        end
    end
end

World.TILE = TILE
World.COLS = COLS
