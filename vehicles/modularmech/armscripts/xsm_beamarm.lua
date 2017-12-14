require "/vehicles/modularmech/armscripts/base.lua"

BeamArm = MechArm:extend()

function BeamArm:init()
  self.state = FSM:new()
  if self.rotationOffset then
    self.shoulderOffset = vec2.sub(self.shoulderOffset,self.rotationOffset)
  end
end


function BeamArm:update(dt)
  if self.state.state then
    self.state:update()
  end

  if not self.state.state then
    if self.isFiring then
      self.state:set(self.windupState, self)
    end
  end

  if self.state.state then
    self.bobLocked = true
  else
    animator.setAnimationState(self.armName, "idle")
    self.bobLocked = false
  end
end

function BeamArm:windupState()
  local stateTimer = self.windupTime

  animator.setAnimationState(self.armName, "windup")
  animator.playSound(self.armName .. "Windup")

  while stateTimer > 0 do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    local dt = script.updateDt()
    stateTimer = stateTimer - dt
    coroutine.yield()
  end

  if self.isFiring then
    self.state:set(self.fireState, self)
  else
    self.state:set(self.winddownState, self)
  end
end


function BeamArm:statSet()
        self.mechBonusWeapon = self.stats.power + self.stats.energy
        self.mechBonusBody = self.parts.body.stats.protection + self.parts.body.stats.energy
        self.mechBonusBooster = self.parts.booster.stats.control + self.parts.booster.stats.speed 
        self.mechBonusLegs = self.parts.legs.stats.speed + self.parts.legs.stats.jump 
        self.mechBonusTotal = self.mechBonusLegs + self.mechBonusBooster + self.mechBonusBody -- all three combined
        self.mechBonus = ((self.mechBonusBody  /2.4) + (self.mechBonusBooster/ 3) + (self.mechBonusLegs / 2.7))
        self.energyMax = self.parts.body.energyMax
        self.weaponDrain = ((self.parts.leftArm.energyDrain or 0) + (self.parts.rightArm.energyDrain or 0))/20
        self.weaponDrainCrit = ((self.parts.leftArm.energyDrain or 0) + (self.parts.rightArm.energyDrain or 0))/10
        storage.energy = math.min(math.max(0, storage.energy - self.weaponDrain),self.energyMax)
end

function BeamArm:fireState()
  local stateTimer = self.fireTime

  -- FU beam damage scaling *******************************************
	  self:statSet()  
	  self.mechTier = self.stats.power
	  self.basePower = self.stats.basePower or 1
	  
          pParams = config.getParameter("")  -- change this later to only read the relevant data, rather than all of it
          self.critChance = (self.parts.body.stats.energy/2) + math.random(100)

          self.applyBeamDamage = self.basePower * self.mechTier; 
          --Mech critical hits
		if (self.stats.rapidFire) then 
		  self.critMod = self.stats.rapidFire / 10
		  self.critChance = self.critChance * self.critMod
		end          
		if (self.critChance) >= 100 then
		  self.mechBonus = self.mechBonus * 2
		end

        --apply final damage
        
        if (self.mechBonus) >= (self.mechBonusWeapon) then
          self.randbonus = (self.mechBonus/100) * self.mechTier
          self.mechBonus = self.mechBonus * (1 + self.randbonus)
        end          
        
        self.applyBeamDamage = self.applyBeamDamage + self.mechBonus; 
  -- ********************************************************************
  
  local beamEndTimer = 0

  if not self:rayCheck(self.firePosition) then -- don't fire if sticking thru wall
    self.state:set(self.winddownState, self)
    return
  end
    
  animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

  local endPoint, beamCollision, beamLength = self:updateBeam()

  animator.playSound(self.armName .. "Fire")
  animator.setAnimationState(self.armName .. "Beam", "fire", true)

  vehicle.setDamageSourceEnabled(self.armName .. "Beam", true)

  self.aimLocked = self.lockAim



  coroutine.yield()

  while stateTimer > 0 do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    endPoint, beamCollision, beamLength = self:updateBeam()

  if beamCollision and self.beamTileDamage > 0 then
    local maximumEndPoint = vec2.add(self.firePosition, vec2.mul(self.aimVector, self.beamLength))
    local damagePositions = world.collisionBlocksAlongLine(self.firePosition, maximumEndPoint, nil, self.beamTileDamageDepth)
    world.damageTiles(damagePositions, "foreground", self.firePosition, "beamish", self.beamTileDamage, 99)
    world.damageTiles(damagePositions, "background", self.firePosition, "beamish", self.beamTileDamage, 99)
  end
    
    if beamCollision and beamEndTimer <= 0 and self.beamEndProjectile then
      world.spawnProjectile(self.beamEndProjectile, {endPoint[1],endPoint[2]}, self.driverId, {0, 0}, false)
      beamEndTimer = self.beamEndTimer
    end
    
    beamParams = {}
    beamParams.speed =  200
    
    beamParams.timeToLive =  1
    if self.basePower == 0.05 then
      beamParams.timeToLive =  0.23
    elseif (self.basePower) == 2.25 then
      beamParams.timeToLive =  0.1
      beamParams.speed =  900
    elseif (self.basePower) >= 34 then
      beamParams.timeToLive =  2        
    end   
    
    beamParams.power =  self.applyBeamDamage      
    --FU Projectile spawn, to do scaled damage *******************************************************************************
      world.spawnProjectile("fu_genericBlankProjectile", self.firePosition, self.driverId, self.aimVector , false, beamParams)
    -- ***********************************************************************************************************************
    
    animator.setParticleEmitterBurstCount(self.armName .. "Beam", math.ceil(self.beamParticleDensity * beamLength / 10))
    animator.burstParticleEmitter(self.armName .. "Beam")

    local dt = script.updateDt()
    stateTimer = stateTimer - dt
    beamEndTimer = beamEndTimer - dt
    coroutine.yield()
  end

  self.aimLocked = false

  vehicle.setDamageSourceEnabled(self.armName .. "Beam", false)

  if self.isFiring and self.repeatFire then
    self.state:set(self.fireState, self)
  else
    self.state:set(self.winddownState, self)
  end
end

function BeamArm:winddownState()
  local stateTimer = self.winddownTime or 0

  animator.setAnimationState(self.armName, "winddown")

  while stateTimer > 0 do
    animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)

    local dt = script.updateDt()
    stateTimer = stateTimer - dt
    coroutine.yield()
  end

  self.state:set()
end

function BeamArm:updateBeam()
  local endPoint = vec2.add(self.firePosition, vec2.mul(self.aimVector, self.beamLength))
  local beamCollision = world.lineCollision(self.firePosition, endPoint)
  if beamCollision then
    endPoint = beamCollision
  end
  local beamLength = world.magnitude(self.firePosition, endPoint)

  animator.resetTransformationGroup(self.armName .. "Beam")
  animator.scaleTransformationGroup(self.armName .. "Beam", {beamLength, 1}, {self.beamSourceOffset[1], self.beamSourceOffset[2] - self.beamHeight / 2})

  local particleRegion = {self.beamSourceOffset[1], self.beamSourceOffset[2], self.beamSourceOffset[1] + beamLength, self.beamSourceOffset[2]}
  animator.setParticleEmitterOffsetRegion(self.armName .. "Beam", particleRegion)

  return endPoint, beamCollision, beamLength
end
