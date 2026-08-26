-- Audio stores all sound-effect helpers for the game.
Audio = {}
Audio.__index = Audio

-- Creates the synth instruments used by the sound effects.
function Audio.new()
    local self = setmetatable({}, Audio)
    self.lead = playdate.sound.synth.new(playdate.sound.kWaveSquare)
    self.bass = playdate.sound.synth.new(playdate.sound.kWaveTriangle)
    self.enabled = true
    return self
end

-- Plays a note if sound is enabled and the synth exists.
function Audio:note(synth, pitch, volume, duration)
    if self.enabled and synth then
        synth:playNote(pitch, volume, duration)
    end
end

-- Plays the short low sound used when the mole digs a tile.
function Audio:dig()
    self:note(self.bass, 35, 0.18, 0.04)
end

-- Plays a reward sound, with rarer treasure using a higher pitch.
function Audio:treasure(kind)
    local pitch = ({ gem = 72, gold = 79, diamond = 88 })[kind] or 72
    self:note(self.lead, pitch, 0.45, 0.12)
end

-- Plays a time-bonus sound, with larger bonuses using a higher pitch.
function Audio:worm(seconds)
    self:note(self.lead, seconds >= 10 and 84 or seconds >= 5 and 79 or 76, 0.4, 0.16)
end

-- Plays a quick warning beep when the timer is almost empty.
function Audio:warning()
    self:note(self.lead, 67, 0.28, 0.07)
end

-- Plays the lower ending sound when time runs out.
function Audio:gameOver()
    self:note(self.bass, 40, 0.5, 0.35)
end
