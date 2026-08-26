Audio = {}
Audio.__index = Audio

function Audio.new()
    local self = setmetatable({}, Audio)
    self.lead = playdate.sound.synth.new(playdate.sound.kWaveSquare)
    self.bass = playdate.sound.synth.new(playdate.sound.kWaveTriangle)
    self.enabled = true
    return self
end

function Audio:note(synth, pitch, volume, duration)
    if self.enabled and synth then
        synth:playNote(pitch, volume, duration)
    end
end

function Audio:dig()
    self:note(self.bass, 35, 0.18, 0.04)
end

function Audio:treasure(kind)
    local pitch = ({ gem = 72, gold = 79, diamond = 88 })[kind] or 72
    self:note(self.lead, pitch, 0.45, 0.12)
end

function Audio:worm(seconds)
    self:note(self.lead, seconds >= 10 and 84 or seconds >= 5 and 79 or 76, 0.4, 0.16)
end

function Audio:warning()
    self:note(self.lead, 67, 0.28, 0.07)
end

function Audio:combatHit()
    self:note(self.lead, "C5", 0.35, 0.06)
end

function Audio:enemyDefeated()
    self:note(self.lead, "G5", 0.5, 0.18)
end

function Audio:powerUp()
    self:note(self.lead, "C6", 0.45, 0.16)
end

function Audio:gameOver()
    self:note(self.bass, 40, 0.5, 0.35)
end
