local gfx = playdate.graphics

World = {}
World.__index = World

local TILE = 20
local COLS = 20
local CHUNK_HEIGHT = 8

local chunkTemplates = {
    {
        { col = 6, row = 1, role = "treasure" },
        { col = 14, row = 2, role = "worm" },
        { col = 4, row = 4, role = "treasure" },
        { col = 11, row = 5, role = "treasure" },
        { col = 17, row = 7, role = "treasure" },
    },
    {
        { col = 15, row = 1, role = "treasure" },
        { col = 9, row = 3, role = "worm" },
        { col = 3, row = 4, role = "treasure" },
        { col = 17, row = 5, role = "treasure" },
        { col = 7, row = 7, role = "treasure" },
    },
    {
        { col = 4, row = 1, role = "worm" },
        { col = 12, row = 2, role = "treasure" },
        { col = 18, row = 4, role = "treasure" },
        { col = 7, row = 5, role = "treasure" },
        { col = 14, row = 7, role = "worm" },
    },
    {
        { col = 10, row = 1, role = "treasure" },
        { col = 2, row = 3, role = "treasure" },
        { col = 16, row = 3, role = "worm" },
        { col = 6, row = 6, role = "treasure" },
        { col = 18, row = 7, role = "treasure" },
    },
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

function World:generateChunk()
    self.chunkCount = self.chunkCount + 1
    local chunkIndex = self.chunkCount
    local template = chunkTemplates[((chunkIndex - 1) % #chunkTemplates) + 1]
    local baseRow = 3 + (chunkIndex - 1) * CHUNK_HEIGHT

    for _, slot in ipairs(template) do
        local row = baseRow + slot.row
        local item = slot.role == "worm" and self:makeWorm(chunkIndex) or self:makeTreasure(chunkIndex)
        item.col = slot.col
        item.row = row
        self.items[cellKey(slot.col, row)] = item
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
    gfx.setColor(gfx.kColorWhite)
    if item.kind == "gem" then
        gfx.drawPolygon(cx, cy - 6, cx + 6, cy, cx, cy + 6, cx - 6, cy)
        gfx.drawLine(cx - 3, cy, cx + 3, cy)
    elseif item.kind == "gold" then
        gfx.fillRoundRect(cx - 7, cy - 5, 14, 10, 3)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText("G", cx - 3, cy - 6)
    elseif item.kind == "diamond" then
        gfx.fillPolygon(cx, cy - 8, cx + 8, cy - 2, cx + 5, cy + 6, cx, cy + 9, cx - 5, cy + 6, cx - 8, cy - 2)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(cx - 5, cy - 2, cx + 5, cy - 2)
        gfx.drawLine(cx, cy - 7, cx, cy + 6)
    end
end

local function drawWorm(item, cx, cy)
    gfx.setColor(gfx.kColorWhite)
    gfx.setLineWidth(item.seconds >= 10 and 4 or item.seconds >= 5 and 3 or 2)
    gfx.drawLine(cx - 7, cy + 4, cx - 3, cy - 2)
    gfx.drawLine(cx - 3, cy - 2, cx + 2, cy + 3)
    gfx.drawLine(cx + 2, cy + 3, cx + 7, cy - 4)
    gfx.setLineWidth(1)
    gfx.fillCircleAtPoint(cx + 7, cy - 4, 2)
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
            else
                drawTreasure(item, x, y)
            end
        end
    end
end

World.TILE = TILE
World.COLS = COLS
