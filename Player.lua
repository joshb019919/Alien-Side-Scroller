--[[
    Represents our player in the game, with its own sprite.
]]

Player = Class{}

local WALKING_SPEED = 140
local JUMP_VELOCITY = 400
local LEVEL = 1

function Player:init(map)
    
    self.x = 0
    self.y = 0
    self.width = 16
    self.height = 20

    -- offset from top left to center to support sprite flipping
    self.xOffset = 8
    self.yOffset = 10

    -- reference to map for checking tiles
    self.map = map
    self.texture = love.graphics.newImage('graphics/blue_alien.png')

    -- sound effects
    self.sounds = {
        ['jump'] = love.audio.newSource('sounds/jump.wav', 'static'),
        ['hit'] = love.audio.newSource('sounds/hit.wav', 'static'),
        ['coin'] = love.audio.newSource('sounds/coin.wav', 'static')
    }

    -- animation frames
    self.frames = {}

    -- current animation frame
    self.currentFrame = nil

    -- current level
    self.level = LEVEL

    -- used to determine behavior and animations
    self.state = 'idle'

    -- determines sprite flipping
    self.direction = 'left'

    -- x and y velocity
    self.dx = 0
    self.dy = 0

    -- starting position
    self.y = self.map.tileHeight * ((self.map.mapHeight / 2) + 1) - self.height
    self.x = self.map.tileWidth * 10

    -- initialize all player animations
    self.animations = {
        ['idle'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(0, 0, 16, 20, self.texture:getDimensions())
            }
        }),
        ['walking'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(128, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(144, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(160, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(144, 0, 16, 20, self.texture:getDimensions()),
            },
            interval = 0.15
        }),
        ['jumping'] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(32, 0, 16, 20, self.texture:getDimensions())
            }
        }),
        ["climbing"] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(80, 0, 16, 20, self.texture:getDimensions()),
                love.graphics.newQuad(96, 0, 16, 20, self.texture:getDimensions())
            },
            interval = 0.50
        }),
        ["win"] = Animation({
            texture = self.texture,
            frames = {
                love.graphics.newQuad(32, 0, 16, 20, self.texture:getDimensions())
            }
        })
        -- ["died"] = Animation({
        --     texture = self.texture,
        --     frames = {
        --         love.graphics.newQuad(64, 0, 16, 20, self.texture:getDimensions())
        --     }
        -- })
    }

    -- initialize animation and current frame we should render
    self.animation = self.animations['idle']
    self.currentFrame = self.animation:getCurrentFrame()

    -- behavior map we can call based on player state
    self.behaviors = {
        ['idle'] = function(dt)
            
            -- add functionality to trigger jump state
            if love.keyboard.wasPressed('x') then
                self.dy = -JUMP_VELOCITY
                self.state = 'jumping'
                self.animation = self.animations['jumping']
                self.sounds['jump']:play()
            elseif love.keyboard.isDown('left') then
                self.direction = 'left'
                self.dx = -WALKING_SPEED
                self.state = 'walking'
                self.animations['walking']:restart()
                self.animation = self.animations['walking']
            elseif love.keyboard.isDown('right') then
                self.direction = 'right'
                self.dx = WALKING_SPEED
                self.state = 'walking'
                self.animations['walking']:restart()
                self.animation = self.animations['walking']
            else
                self.dx = 0
            end
        end,
        ['walking'] = function(dt)

            if self.x <= 0 then 
                self.x = 0
            elseif self.y > 280 then 
                -- self.state = "died"
                return
            end
            
            -- keep track of input to switch movement while walking, or reset
            -- to idle if we're not moving
            if love.keyboard.wasPressed('x') then
                self.dy = -JUMP_VELOCITY
                self.state = 'jumping'
                self.animation = self.animations['jumping']
                self.sounds['jump']:play()
            elseif love.keyboard.isDown('left') then
                self.direction = 'left'
                self.dx = -WALKING_SPEED
            elseif love.keyboard.isDown('right') then
                self.direction = 'right'
                self.dx = WALKING_SPEED
            else
                self.dx = 0
                self.state = 'idle'
                self.animation = self.animations['idle']
            end

            -- check if not there's a tile directly beneath us
            if not self.map:collides(self.map:tileAt(self.x + 6, self.y + self.height)) or
               not self.map:collides(self.map:tileAt(self.x + self.width - 6, self.y + self.height)) then
                
                    -- if so, reset position and change state (sprite falls through hole)
                    self.state = 'jumping'
                    self.animation = self.animations['jumping']
            end

            -- check for collisions moving left and right
            self:checkRightCollision()
            self:checkLeftCollision()
        end,
        ['jumping'] = function(dt)
            -- break if we go below the surface
            if self.y > 300 then
                -- self.state = "died"
                return
            elseif self.x <= 0 then 
                self.x = 0
            end

            if love.keyboard.isDown('left') then
                self.direction = 'left'
                self.dx = -WALKING_SPEED
            elseif love.keyboard.isDown('right') then
                self.direction = 'right'
                self.dx = WALKING_SPEED
            else
                self.dx = 0
            end

            -- apply map's gravity before y velocity
            self.dy = self.dy + self.map.gravity

            -- check if there's a tile directly beneath us
            if self.map:collides(self.map:tileAt(self.x + 6, self.y + self.height)) or
                self.map:collides(self.map:tileAt(self.x + self.width - 6, self.y + self.height)) then
                
                -- if so, reset velocity and position and change state
                self.dy = 0
                self.state = 'idle'
                self.animation = self.animations['idle']
                self.y = (self.map:tileAt(self.x, self.y + self.height).y - 1) * self.map.tileHeight - self.height
            end

            -- check for collisions moving left and right
            self:checkRightCollision()
            self:checkLeftCollision()
        end,
        ["poleClimbing"] = function(dt)
            self.x = self.map.mapWidthPixels - 32
            self.dx = 0
            self.animation = self.animations["climbing"]
            self.animations["climbing"]:restart()
            self.dy = WALKING_SPEED

            -- check for bricks as where to stop poleClimbing down
            if self.map:collides(self.map:tileAt(self.x, self.y + self.height)) then 
                self.state = "win"
            end
        end,
        ["win"] = function(dt)
            self.animation = self.animations["win"]
            self.animation = self.animations["walking"]
            self.dy = 0
            self.y = self.map:tileAt(self.x, self.y + self.height).y * self.map.tileHeight - 34
            self.dx = WALKING_SPEED

            -- stop and begin new level once sprite is offscreen
            if self.x - 128 >= self.map.mapWidthPixels then 
                -- reset everything
                self.animation = self.animations["idle"]

                self.state = 'idle'
                self.direction = 'left'

                self.dx = 0
                self.dy = 0

                self.y = self.map.tileHeight * ((self.map.mapHeight / 2) + 1) - self.height
                self.x = self.map.tileWidth * 10

                self.map.music:stop()
                self.state = "newLevel"
                LEVEL = LEVEL + 1
            end
        end
        -- ["died"] = function(dt)
        --     self.animation = self.animations["died"]
        --     self.dy = 0
        --     self.dx = 0
        -- end
    }
end

function Player:update(dt)
    if love.keyboard.isDown("z") and self.dx ~= 0 then 
        WALKING_SPEED = 180
        JUMP_VELOCITY = 430
    else
        WALKING_SPEED = 80
        JUMP_VELOCITY = 400
    end
    
    self.behaviors[self.state](dt)
    self.animation:update(dt)
    self.currentFrame = self.animation:getCurrentFrame()
    self.x = self.x + self.dx * dt

    self:calculateJumps()

    -- apply velocity
    self.y = self.y + self.dy * dt
end

-- jumping and block hitting logic
function Player:calculateJumps()
    
    -- if we have negative y velocity (jumping), check if we collide
    -- with any blocks above us
    if self.dy < 0 then
        if self.map:tileAt(self.x, self.y).id == TILE_BRICK or 
           self.map:tileAt(self.x, self.y).id == JUMP_BLOCK or 
           self.map:tileAt(self.x, self.y).id == JUMP_BLOCK_HIT or 
           self.map:tileAt(self.x + self.width - 1, self.y).id == TILE_BRICK or 
           self.map:tileAt(self.x + self.width - 1, self.y).id == JUMP_BLOCK or 
           self.map:tileAt(self.x + self.width - 1, self.y).id == JUMP_BLOCK_HIT then
                -- reset y velocity
                self.dy = 0

            -- change block to different block
            local playCoin = false
            local playHit = false
            if self.map:tileAt(self.x, self.y).id == JUMP_BLOCK then
                self.map:setTile(math.floor(self.x / self.map.tileWidth) + 1,
                    math.floor(self.y / self.map.tileHeight) + 1, JUMP_BLOCK_HIT)
                playCoin = true
            else
                playHit = true
            end
            if self.map:tileAt(self.x + self.width - 1, self.y).id == JUMP_BLOCK then
                self.map:setTile(math.floor((self.x + self.width - 1) / self.map.tileWidth) + 1,
                    math.floor(self.y / self.map.tileHeight) + 1, JUMP_BLOCK_HIT)
                playCoin = true
            else
                playHit = true
            end

            if playCoin then
                self.sounds['coin']:play()
            elseif playHit then
                self.sounds['hit']:play()
            end
        end
    end

    if self.map:tileAt(self.x + self.width - 15, self.y + 10).id == FLAG_POLE or 
       self.map:tileAt(self.x + self.width - 15, self.y).id == FLAG_TOP then 
            self.state = "poleClimbing"
    end
end

-- checks the two tiles to our left to see if a collision occurred
function Player:checkLeftCollision()
    if self.dx < 0 then
        -- check if there's a tile directly to the left
        if self.map:collides(self.map:tileAt(self.x - 1, self.y)) or
            self.map:collides(self.map:tileAt(self.x - 1, self.y + self.height - 1)) then
            
            -- if so, reset velocity and position
            self.dx = 0
            self.x = self.map:tileAt(self.x - 1, self.y).x * self.map.tileWidth
        end
    end
end

-- checks the two tiles to our right to see if a collision occurred
function Player:checkRightCollision()
    if self.dx > 0 then
        -- check if there's a tile directly beneath us or to the right
        if self.map:collides(self.map:tileAt(self.x + self.width, self.y)) or
            self.map:collides(self.map:tileAt(self.x + self.width, self.y + self.height - 1)) then
            
            -- if so, reset velocity and position
            self.dx = 0
            self.x = (self.map:tileAt(self.x + self.width, self.y).x - 1) * self.map.tileWidth - self.width
        end
    end
end

function Player:render()
    local scaleX

    -- set negative x scale factor if facing left, which will flip the sprite when applied
    if self.direction == 'right' then
        scaleX = 1
    else
        scaleX = -1
    end

    if self.state == "win" then 
        love.graphics.print("          VICTORY!\n          You completed map level " .. self.level .. "!", 
                            self.x, self.y)
    end

    -- draw sprite with scale factor and offsets
    love.graphics.draw(self.texture, self.currentFrame, math.floor(self.x + self.xOffset),
        math.floor(self.y + self.yOffset), 0, scaleX, 1, self.xOffset, self.yOffset)

    -- display map level
    love.graphics.print("Map Level " .. self.level)

    -- if self.state == "died" then 
    --     love.graphics.print("You fell!", self.map.mapWidth / 2, self.map.mapHeight / 2)
    -- end
end
