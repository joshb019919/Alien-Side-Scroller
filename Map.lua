--[[
    Contains tile data and necessary code for rendering a tile map to the
    screen.
]]

require 'Util'

Map = Class{}

TILE_BRICK = 1
TILE_EMPTY = -1

-- cloud tiles
CLOUD_LEFT = 6
CLOUD_RIGHT = 7

-- bush tiles
BUSH_LEFT = 2
BUSH_RIGHT = 3

-- mushroom tiles
MUSHROOM_TOP = 10
MUSHROOM_BOTTOM = 11

-- jump block
JUMP_BLOCK = 5
JUMP_BLOCK_HIT = 9

-- flag pole and flag
FLAG_BASE = 16
FLAG_POLE = 12
FLAG_TOP = 8
FLAG_1 = 13
FLAG_2 = 14
FLAG_3 = 15

-- a speed to multiply delta time to scroll map; smooth value
local SCROLL_SPEED = 62

-- constructor for our map object
function Map:init()

    self.spritesheet = love.graphics.newImage("graphics/spritesheet.png")
    self.sprites = generateQuads(self.spritesheet, 16, 16)
    self.music = love.audio.newSource('sounds/music.wav', 'static')

    self.tileWidth = 16
    self.tileHeight = 16
    self.mapWidth = 30
    self.mapHeight = 28
    self.tiles = {}

    -- applies positive Y influence on anything affected
    self.gravity = 15

    -- associate player with map
    self.player = Player(self)

    -- camera offsets
    self.camX = 0
    self.camY = -3

    -- cache width and height of map in pixels
    self.mapWidthPixels = self.mapWidth * self.tileWidth
    self.mapHeightPixels = self.mapHeight * self.tileHeight

    -- first, fill map with empty tiles
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            
            -- support for multiple sheets per tile; storing tiles as tables 
            self:setTile(x, y, TILE_EMPTY)
        end
    end

    -- begin generating the terrain using vertical scan lines
    local x = 1
    while x < self.mapWidth do
        
        -- 5% chance to generate a cloud
        -- make sure we're 2 tiles from edge at least
        if x < self.mapWidth - 2 then
            if math.random(20) == 1 then
                
                -- choose a random vertical spot above where blocks/pipes generate
                local cloudStart = math.random(self.mapHeight / 2 - 6)

                self:setTile(x, cloudStart, CLOUD_LEFT)
                self:setTile(x + 1, cloudStart, CLOUD_RIGHT)
            end
        end

        -- 5% chance to generate a mushroom
        if math.random(20) == 1 then
            -- left side of pipe
            self:setTile(x, self.mapHeight / 2, MUSHROOM_TOP)
            self:setTile(x, self.mapHeight / 2 + 1, MUSHROOM_BOTTOM)

            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2 + 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- next vertical scan line
            x = x + 1

        -- 10% chance to generate bush, being sure to generate away from edge
        elseif math.random(10) == 1 and x < self.mapWidth - 3 then
            local bushLevel = self.mapHeight / 2 + 1

            -- place bush component and then column of bricks
            self:setTile(x, bushLevel, BUSH_LEFT)
            for y = self.mapHeight / 2 + 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

            self:setTile(x, bushLevel, BUSH_RIGHT)
            for y = self.mapHeight / 2 + 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end
            x = x + 1

        -- 10% chance to not generate anything, creating a gap
        elseif math.random(10) ~= 1 then
            
            -- creates column of tiles going to bottom of map
            for y = self.mapHeight / 2 + 2, self.mapHeight do
                self:setTile(x, y, TILE_BRICK)
            end

            -- chance to create a block for Mario to hit
            if math.random(15) == 1 then
                self:setTile(x, self.mapHeight / 2 - 2, JUMP_BLOCK)
            end

            -- next vertical scan line
            x = x + 1
        else
            -- increment X so we skip two scanlines, creating a 2-tile gap
            x = x + 2
        end
    end

    for y = self.mapHeight / 2 + 2, self.mapHeight do
        self:setTile(math.floor(self.player.x), y, TILE_BRICK)
    end

    -- pyramid steps leading to flagpole
    for y = (self.mapHeight - 2), 10, -1 do
        for z = 25, y, -1 do
            self:setTile(z, self.mapHeight - y + 6, TILE_BRICK)
        end
    end

    -- flagpole all the way up the screen
    for y = 3, 13 do
        self:setTile(self.mapWidth - 1, y, FLAG_POLE)
    end

    -- area under and after flag pole always has bricks
    for y = 15, self.mapHeight do
        self:setTile(math.floor(self.mapWidth - 1), y, TILE_BRICK)
        self:setTile(math.floor(self.mapWidth), y, TILE_BRICK)
    end
        
    -- flag base, flag top, flag facing away from player
    self:setTile(self.mapWidth - 1, self.mapHeight / 2, FLAG_BASE)
    self:setTile(self.mapWidth - 1, 2, FLAG_TOP)
    self:setTile(self.mapWidth, 2, FLAG_1)

    -- start the background music
    self.music:setLooping(true)
    self.music:setVolume(0.25)
    self.music:play()
end

-- return whether a given tile is collidable
function Map:collides(tile)
    -- define our collidable tiles
    local collidables = {
        TILE_BRICK, JUMP_BLOCK, JUMP_BLOCK_HIT,
        MUSHROOM_TOP, MUSHROOM_BOTTOM, PYRAMID_BLOCK,
        FLAG_POLE, FLAG_BASE, FLAG_TOP
    }

    -- iterate and return true if our tile type matches
    for _, v in ipairs(collidables) do
        if tile.id == v then
            return true
        end
    end

    return false
end

-- function to update camera offset with delta time
function Map:update(dt)
    self.player:update(dt)
    
    -- keep camera's X coordinate following the player, preventing camera from
    -- scrolling past 0 to the left and the map's width
    self.camX = math.max(0, math.min(self.player.x - VIRTUAL_WIDTH / 2,
        math.min(self.mapWidthPixels - VIRTUAL_WIDTH, self.player.x)))

    -- make sure camera follows player up and down, too
    -- need to fix where bricks start so map is full
end

-- gets the tile type at a given pixel coordinate
function Map:tileAt(x, y)
    return {
        x = math.floor(x / self.tileWidth) + 1,
        y = math.floor(y / self.tileHeight) + 1,
        id = self:getTile(math.floor(x / self.tileWidth) + 1, math.floor(y / self.tileHeight) + 1)
    }
end

-- returns an integer value for the tile at a given x-y coordinate
function Map:getTile(x, y)
    return self.tiles[(y - 1) * self.mapWidth + x]
end

-- sets a tile at a given x-y coordinate to an integer value
function Map:setTile(x, y, id)
    self.tiles[(y - 1) * self.mapWidth + x] = id
end

-- renders our map to the screen, to be called by main's render
function Map:render()    
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            local tile = self:getTile(x, y)
            if tile ~= TILE_EMPTY then
                love.graphics.draw(self.spritesheet, self.sprites[tile],
                    (x - 1) * self.tileWidth, (y - 1) * self.tileHeight)
            end
        end
    end

    self.player:render()
end
