Audio = {}
Audio.__index = Audio

-- Creates the audio manager and prepares the synth voices used for effects.
function Audio.new()
    local self = setmetatable({}, Audio)
    self.lead = playdate.sound.synth.new(playdate.sound.kWaveSquare)
    self.bass = playdate.sound.synth.new(playdate.sound.kWaveTriangle)
    self.enabled = true
    return self
end

-- Plays a note when audio is enabled and the requested synth is available.
function Audio:note(synth, pitch, volume, duration)
    if self.enabled and synth then
        synth:playNote(pitch, volume, duration)
    end
end

-- Plays the short low sound used when the mole digs a tile.
function Audio:dig()
    self:note(self.bass, 35, 0.18, 0.04)
end

-- Plays a treasure pickup sound based on the type of treasure collected.
function Audio:treasure(kind)
    local pitch = ({ gem = 72, gold = 79, diamond = 88 })[kind] or 72
    self:note(self.lead, pitch, 0.45, 0.12)
end

-- Plays a worm pickup sound, with higher pitches for larger time bonuses.
function Audio:worm(seconds)
    self:note(self.lead, seconds >= 10 and 84 or seconds >= 5 and 79 or 76, 0.4, 0.16)
end

-- Plays the countdown warning beep as time runs low.
function Audio:warning()
    self:note(self.lead, 67, 0.28, 0.07)
end

-- Plays the sound for a successful crank hit during enemy combat.
function Audio:combatHit()
    self:note(self.lead, "C5", 0.35, 0.06)
end

-- Plays the reward sound after an enemy is defeated.
function Audio:enemyDefeated()
    self:note(self.lead, "G5", 0.5, 0.18)
end

-- Plays the sound for collecting a temporary power-up.
function Audio:powerUp()
    self:note(self.lead, "C6", 0.45, 0.16)
end

-- Plays the longer low note used when the game ends.
function Audio:gameOver()
    self:note(self.bass, 40, 0.5, 0.35)
end
