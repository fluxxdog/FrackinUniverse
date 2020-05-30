require "/stats/effects/fu_armoreffects/setbonuses_common.lua"

setName="fu_diamondset"


weaponBonus={
	{stat = "powerMultiplier", effectiveMultiplier = 1.25},
	{stat = "critChance", amount = 2.5}
}

armorBonus={
	{stat = "sulphuricImmunity", amount = 1},
	{stat = "biooozeImmunity", amount = 1}
}

function init()
	setSEBonusInit(setName,setEffects)
	effectHandlerList.armorBonusHandle=effect.addStatModifierGroup({})
	effectHandlerList.weaponBonusHandle=effect.addStatModifierGroup({})
	
	handleBonuses(0,checkSetWorn(self.setBonusCheck))
end

function update(dt)
	handleBonuses(dt,checkSetWorn(self.setBonusCheck))
end

function handleBonuses(dt,on)
	if on then
		effect.setStatModifierGroup(effectHandlerList.armorBonusHandle,armorBonus)
		applySetEffects()
	else
		effect.setStatModifierGroup(effectHandlerList.armorBonusHandle,{})
	end
	checkWeapons(not on)
end

function checkWeapons(autofail)
	if autofail then effect.setStatModifierGroup(effectHandlerList.weaponBonusHandle,{}) return end

	local weaponSingle=weaponCheck({"katana","daikatana"})

	if weaponSingle["either"] then
		effect.setStatModifierGroup(effectHandlerList.weaponBonusHandle,weaponBonus)				
	else
		effect.setStatModifierGroup(effectHandlerList.weaponBonusHandle,{})
	end
end