-- Load the Playdate graphics library so the game can draw to the screen.
import "CoreLibs/graphics"

-- Load the game modules.
import "audio"
import "world"
import "game"

-- Seed the random number generator so treasure and worm rewards vary each run.
local seconds = playdate.getSecondsSinceEpoch()
math.randomseed(seconds)

-- Create one game object that owns the game state.
local game = Game.new()

-- Run the game at 30 frames per second.
playdate.display.setRefreshRate(30)

-- Playdate calls this function once every frame.
function playdate.update()
    game:update()
    game:draw()
end
