Audio = {}
Audio.__index = Audio

local MUSIC_VOLUME = 0.28
local SFX_VOLUME = 1
local SFX_POOL_SIZE = 4
local DIG_SOUND_END_SECONDS = 0.18

local MUSIC_TRACKS = {
    menu = "audio/Music_Opening_2",
    playing = "audio/Music_Play4",
}

local SOUND_EFFECTS = {
    gameOver = "audio/Sound_GameOver_1",
    move = "audio/Sound_Move_2",
    negative = "audio/Sound_Negative_1",
    positive = "audio/Sound_Positive_1",
    strongPositive = "audio/Sound_Positive_2",
}

-- Creates several players for one sound so repeated events can retrigger quickly.
local function makeSoundPool(path, playRange)
    local pool = {}
    for _ = 1, SFX_POOL_SIZE do
        local player = playdate.sound.sampleplayer.new(path)
        if player then
            if playRange then
                player:setPlayRange(playRange.start, playRange.finish)
            end
            table.insert(pool, player)
        end
    end
    return pool
end

-- Creates the audio manager and loads music tracks and event sound effects.
function Audio.new()
    local self = setmetatable({}, Audio)
    self.enabled = true
    self.currentMusicName = nil
    self.soundIndexes = {}
    self.music = {
        menu = playdate.sound.fileplayer.new(MUSIC_TRACKS.menu),
        playing = playdate.sound.fileplayer.new(MUSIC_TRACKS.playing),
    }
    self.sounds = {
        gameOver = makeSoundPool(SOUND_EFFECTS.gameOver),
        move = makeSoundPool(SOUND_EFFECTS.move, {
            start = 0,
            finish = DIG_SOUND_END_SECONDS,
        }),
        negative = makeSoundPool(SOUND_EFFECTS.negative),
        positive = makeSoundPool(SOUND_EFFECTS.positive),
        strongPositive = makeSoundPool(SOUND_EFFECTS.strongPositive),
    }

    for _, player in pairs(self.music) do
        if player then
            player:setVolume(MUSIC_VOLUME)
            player:setStopOnUnderrun(false)
        end
    end

    for name, pool in pairs(self.sounds) do
        self.soundIndexes[name] = 1
        for _, player in ipairs(pool) do
            player:setVolume(SFX_VOLUME, SFX_VOLUME)
        end
    end

    return self
end

-- Plays a loaded sound effect if audio is enabled.
function Audio:playSound(name)
    if not self.enabled then
        return
    end

    local pool = self.sounds[name]
    if not pool or #pool == 0 then
        return
    end

    local index = self.soundIndexes[name] or 1
    local player = pool[index]
    self.soundIndexes[name] = index % #pool + 1

    if player then
        player:stop()
        player:setOffset(0)
        player:play()
    end
end

-- Switches to a looping music track, stopping the previous track first.
function Audio:playMusic(name)
    if not self.enabled then
        return
    end

    local nextMusic = self.music[name]
    if not nextMusic then
        self.currentMusicName = nil
        return
    end

    if self.currentMusicName == name and nextMusic:isPlaying() then
        return
    end

    local currentMusic = self.music[self.currentMusicName]
    if currentMusic and currentMusic ~= nextMusic then
        currentMusic:stop()
    end

    nextMusic:stop()
    nextMusic:setOffset(0)
    nextMusic:play(0)
    self.currentMusicName = name
end

-- Starts the looping opening and main menu music.
function Audio:playMenuMusic()
    self:playMusic("menu")
end

-- Starts the looping gameplay music.
function Audio:playGameMusic()
    self:playMusic("playing")
end

-- Stops whichever music track is currently playing.
function Audio:stopMusic()
    local currentMusic = self.music[self.currentMusicName]
    if currentMusic then
        currentMusic:stop()
    end
    self.currentMusicName = nil
end

-- Plays the short movement sound used when the mole changes grid cells.
function Audio:move()
    self:playSound("move")
end

-- Plays the movement sound when a new tile is dug.
function Audio:dig()
    self:move()
end

-- Plays a pickup sound based on the type of treasure collected.
function Audio:treasure(kind)
    if kind == "diamond" or kind == "gold" then
        self:playSound("strongPositive")
    else
        self:playSound("positive")
    end
end

-- Plays the regular positive pickup sound when a worm adds time.
function Audio:worm(seconds)
    self:playSound(seconds >= 5 and "strongPositive" or "positive")
end

-- Plays the negative alert sound as time runs low.
function Audio:warning()
    self:playSound("negative")
end

-- Plays the negative sound when combat begins.
function Audio:enemyEncounter()
    self:playSound("negative")
end

-- Plays the negative impact sound for a successful crank hit during enemy combat.
function Audio:combatHit()
    self:playSound("negative")
end

-- Plays the stronger positive sound after an enemy is defeated.
function Audio:enemyDefeated()
    self:playSound("strongPositive")
end

-- Plays the stronger positive sound for collecting a temporary power-up.
function Audio:powerUp()
    self:playSound("strongPositive")
end

-- Plays the game-over sound.
function Audio:gameOver()
    self:playSound("gameOver")
end
