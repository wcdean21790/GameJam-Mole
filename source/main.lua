import "CoreLibs/graphics"

import "audio"
import "world"
import "game"

local seconds = playdate.getSecondsSinceEpoch()
math.randomseed(seconds)

local game = Game.new()

playdate.display.setRefreshRate(30)

function playdate.update()
    game:update()
    game:draw()
end
