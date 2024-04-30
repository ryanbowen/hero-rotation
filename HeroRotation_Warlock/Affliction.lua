--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC           = HeroDBC.DBC
-- HeroLib
local HL            = HeroLib
local Cache         = HeroCache
local Unit          = HL.Unit
local Player        = Unit.Player
local Pet           = Unit.Pet
local Target        = Unit.Target
local Spell         = HL.Spell
local Item          = HL.Item
-- HeroRotation
local HR            = HeroRotation
local AoEON         = HR.AoEON
local CDsON         = HR.CDsON
local Cast          = HR.Cast
-- Num/Bool Helper Functions
local num           = HR.Commons.Everyone.num
local bool          = HR.Commons.Everyone.bool
-- Lua
local mathmax       = math.max

--- ============================ CONTENT ============================
--- ======= APL LOCALS =======
-- Commons
local Everyone = HR.Commons.Everyone
local Warlock  = HR.Commons.Warlock

-- GUI Settings
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Warlock.Commons,
  CommonsDS = HR.GUISettings.APL.Warlock.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Warlock.CommonsOGCD,
  Affliction = HR.GUISettings.APL.Warlock.Affliction
}

-- Spells
local S = Spell.Warlock.Affliction

-- Items
local I = Item.Warlock.Affliction
local OnUseExcludes = {
  I.BelorrelostheSuncaller:ID(),
  I.TimeThiefsGambit:ID(),
}

-- Trinket Item Objects
local Equip = Player:GetEquipment()
local Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
local Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)

-- Rotation Variables
local Enemies40y, Enemies10ySplash, EnemiesCount10ySplash
local VarPSUp, VarVTUp, VarVTPSUp, VarSRUp, VarCDDoTsUp, VarHasCDs, VarCDsActive
local VarMinAgony, VarMinVT, VarMinPS, VarMinPS1
local SoulRotBuffLength = (Player:HasTier(31, 2)) and 12 or 8
local DSSB = (S.DrainSoul:IsAvailable()) and S.DrainSoul or S.ShadowBolt
local SoulShards = 0
local BossFightRemains = 11111
local FightRemains = 11111
local GCDMax

-- Trinket Variables (from Precombat)
local Trinket1ID = Trinket1:ID()
local Trinket2ID = Trinket2:ID()
local VarTrinket1Buffs = Trinket1:HasUseBuff()
local VarTrinket2Buffs = Trinket2:HasUseBuff()
local VarTrinket1Sync = (VarTrinket1Buffs and (Trinket1:Cooldown() % 30 == 0 or 30 % Trinket1:Cooldown() == 0)) and 1 or 0.5
local VarTrinket2Sync = (VarTrinket2Buffs and (Trinket2:Cooldown() % 30 == 0 or 30 % Trinket2:Cooldown() == 0)) and 1 or 0.5
local VarTrinket1Manual = Trinket1ID == I.BelorrelostheSuncaller:ID() or Trinket1ID == I.TimeThiefsGambit:ID()
local VarTrinket2Manual = Trinket2ID == I.BelorrelostheSuncaller:ID() or Trinket2ID == I.TimeThiefsGambit:ID()
local VarTrinket1Exclude = Trinket1ID == I.RubyWhelpShell:ID() or Trinket1ID == I.WhisperingIncarnateIcon:ID()
local VarTrinket2Exclude = Trinket2ID == I.RubyWhelpShell:ID() or Trinket2ID == I.WhisperingIncarnateIcon:ID()
local VarTrinket1BuffDuration = Trinket1:BuffDuration() + (num(Trinket1ID == I.MirrorofFracturedTomorrows:ID()) * 20) + (num(Trinket1ID == I.NymuesUnravelingSpindle:ID()) * 2)
local VarTrinket2BuffDuration = Trinket2:BuffDuration() + (num(Trinket2ID == I.MirrorofFracturedTomorrows:ID()) * 20) + (num(Trinket2ID == I.NymuesUnravelingSpindle:ID()) * 2)
local VarTrinketPriority = (not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((Trinket2:Cooldown() / VarTrinket2BuffDuration) * (VarTrinket2Sync) * (1 - 0.5 * num(Trinket2ID == I.MirrorofFracturedTomorrows:ID() or Trinket2ID == I.AshesoftheEmbersoul:ID()))) > ((Trinket1:Cooldown() / VarTrinket1BuffDuration) * (VarTrinket1Sync) * (1 - 0.5 * num(Trinket1ID == I.MirrorofFracturedTomorrows:ID() or Trinket1ID == I.AshesoftheEmbersoul:ID())))) and 2 or 1

-- Register
HL:RegisterForEvent(function()
  S.SeedofCorruption:RegisterInFlight()
  S.ShadowBolt:RegisterInFlight()
  S.Haunt:RegisterInFlight()
  DSSB = (S.DrainSoul:IsAvailable()) and S.DrainSoul or S.ShadowBolt
end, "LEARNED_SPELL_IN_TAB")
S.SeedofCorruption:RegisterInFlight()
S.ShadowBolt:RegisterInFlight()
S.Haunt:RegisterInFlight()

HL:RegisterForEvent(function()
  Equip = Player:GetEquipment()
  Trinket1 = Equip[13] and Item(Equip[13]) or Item(0)
  Trinket2 = Equip[14] and Item(Equip[14]) or Item(0)
  SoulRotBuffLength = (Player:HasTier(31, 2)) and 12 or 8
  -- Trinket Stuffs on item change
  Trinket1ID = Trinket1:ID()
  Trinket2ID = Trinket2:ID()
  VarTrinket1Buffs = Trinket1:HasUseBuff()
  VarTrinket2Buffs = Trinket2:HasUseBuff()
  VarTrinket1Sync = (VarTrinket1Buffs and (Trinket1:Cooldown() % 30 == 0 or 30 % Trinket1:Cooldown() == 0)) and 1 or 0.5
  VarTrinket2Sync = (VarTrinket2Buffs and (Trinket2:Cooldown() % 30 == 0 or 30 % Trinket2:Cooldown() == 0)) and 1 or 0.5
  VarTrinket1Manual = Trinket1ID == I.BelorrelostheSuncaller:ID() or Trinket1ID == I.TimeThiefsGambit:ID()
  VarTrinket2Manual = Trinket2ID == I.BelorrelostheSuncaller:ID() or Trinket2ID == I.TimeThiefsGambit:ID()
  VarTrinket1Exclude = Trinket1ID == I.RubyWhelpShell:ID() or Trinket1ID == I.WhisperingIncarnateIcon:ID()
  VarTrinket2Exclude = Trinket2ID == I.RubyWhelpShell:ID() or Trinket2ID == I.WhisperingIncarnateIcon:ID()
  VarTrinket1BuffDuration = Trinket1:BuffDuration() + (num(Trinket1ID == I.MirrorofFracturedTomorrows:ID()) * 20) + (num(Trinket1ID == I.NymuesUnravelingSpindle:ID()) * 2)
  VarTrinket2BuffDuration = Trinket2:BuffDuration() + (num(Trinket2ID == I.MirrorofFracturedTomorrows:ID()) * 20) + (num(Trinket2ID == I.NymuesUnravelingSpindle:ID()) * 2)
  VarTrinketPriority = (not VarTrinket1Buffs and VarTrinket2Buffs or VarTrinket2Buffs and ((Trinket2:Cooldown() / VarTrinket2BuffDuration) * (VarTrinket2Sync) * (1 - 0.5 * num(Trinket2ID == I.MirrorofFracturedTomorrows:ID() or Trinket2ID == I.AshesoftheEmbersoul:ID()))) > ((Trinket1:Cooldown() / VarTrinket1BuffDuration) * (VarTrinket1Sync) * (1 - 0.5 * num(Trinket1ID == I.MirrorofFracturedTomorrows:ID() or Trinket1ID == I.AshesoftheEmbersoul:ID())))) and 2 or 1
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

local function CalcMinDoT(Enemies, Spell)
  -- cycling_variable,name=min_agony,op=min,value=dot.agony.remains+(99*!dot.agony.ticking)
  -- cycling_variable,name=min_vt,op=min,default=10,value=dot.vile_taint.remains+(99*!dot.vile_taint.ticking)
  -- cycling_variable,name=min_ps,op=min,default=16,value=dot.phantom_singularity.remains+(99*!dot.phantom_singularity.ticking)
  if not Enemies or not Spell then return 0 end
  local LowestDoT
  for _, CycleUnit in pairs(Enemies) do
    local UnitDoT = CycleUnit:DebuffRemains(Spell) + (99 * num(CycleUnit:DebuffDown(Spell)))
    if LowestDoT == nil or UnitDoT < LowestDoT then
      LowestDoT = UnitDoT
    end
  end
  return LowestDoT or 0
end

local function CanSeed(Enemies)
  if not Enemies or #Enemies == 0 then return false end
  if S.SeedofCorruption:InFlight() or Player:PrevGCDP(1, S.SeedofCorruption) then return false end
  local TotalTargets = 0
  local SeededTargets = 0
  for _, CycleUnit in pairs(Enemies) do
    TotalTargets = TotalTargets + 1
    if CycleUnit:DebuffUp(S.SeedofCorruptionDebuff) then
      SeededTargets = SeededTargets + 1
    end
  end
  return (TotalTargets == SeededTargets)
end

local function DarkglareActive()
  return Warlock.GuardiansTable.DarkglareDuration > 0
end

local function DarkglareTime()
  return Warlock.GuardiansTable.DarkglareDuration
end

-- CastTargetIf Functions
local function EvaluateTargetIfFilterAgony(TargetUnit)
  -- target_if=remains
  return (TargetUnit:DebuffRemains(S.AgonyDebuff))
end

local function EvaluateTargetIfFilterCorruption(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff))
end

local function EvaluateTargetIfFilterShadowEmbrace(TargetUnit)
  -- target_if=min:debuff.shadow_embrace.remains
  return (TargetUnit:DebuffRemains(S.ShadowEmbraceDebuff))
end

local function EvaluateTargetIfFilterSiphonLife(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.SiphonLifeDebuff))
end

local function EvaluateTargetIfFilterSoulRot(TargetUnit)
  -- target_if=min:dot.soul_rot.remains
  return (TargetUnit:DebuffRemains(S.SoulRotDebuff))
end

local function EvaluateTargetIfAgony(TargetUnit)
  -- if=active_dot.agony<8&remains<cooldown.vile_taint.remains+action.vile_taint.cast_time&remains<5
  -- Note: active_dot.agony<8 handled before CastTargetIf.
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < TargetUnit:DebuffRemains(S.VileTaintDebuff) + S.VileTaint:CastTime() and TargetUnit:DebuffRemains(S.AgonyDebuff) < 5)
end

local function EvaluateTargetIfAgony2(TargetUnit)
  -- if=remains<5
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < 5)
end

local function EvaluateTargetIfAgony3(TargetUnit)
  -- if=active_dot.agony<8&(remains<cooldown.vile_taint.remains+action.vile_taint.cast_time|!talent.vile_taint)&gcd.max+action.soul_rot.cast_time+gcd.max<(variable.min_vt*talent.vile_taint<?variable.min_ps*talent.phantom_singularity)&remains<5
  -- Note: active_dot.agony<8 and soul_rot checks done before CastTargetIf.
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < S.VileTaint:CooldownRemains() + S.VileTaint:CastTime() or not S.VileTaint:IsAvailable()) and TargetUnit:DebuffRemains(S.AgonyDebuff) < 5
end

local function EvaluateTargetIfAgony4(TargetUnit)
  -- if=(remains<cooldown.vile_taint.remains+action.vile_taint.cast_time|!talent.vile_taint)&remains<5&fight_remains>5
  return ((TargetUnit:DebuffRemains(S.AgonyDebuff) < S.VileTaint:CooldownRemains() + S.VileTaint:CastTime() or not S.VileTaint:IsAvailable()) and TargetUnit:DebuffRemains(S.AgonyDebuff) < 5 and FightRemains > 5)
end

local function EvaluateTargetIfCorruption(TargetUnit)
  -- if=remains<5
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff) < 5)
end

local function EvaluateTargetIfDrainSoul(TargetUnit)
  -- if=buff.nightfall.react&(talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)|!talent.shadow_embrace)
  -- Note: buff.nightfall.react check done before CastTargetIf.
  return (S.ShadowEmbrace:IsAvailable() and (TargetUnit:DebuffStack(S.ShadowEmbraceDebuff) < 3 or TargetUnit:DebuffRemains(S.ShadowEmbraceDebuff) < 3) or not S.ShadowEmbrace:IsAvailable())
end

local function EvaluateTargetIfSiphonLife(TargetUnit)
  -- if=refreshable
  return (TargetUnit:DebuffRefreshable(S.SiphonLifeDebuff))
end

-- CastCycle Functions
local function EvaluateCycleAgony(TargetUnit)
  -- target_if=remains<5
  return (TargetUnit:DebuffRemains(S.AgonyDebuff) < 5)
end

local function EvaluateCycleAgonyRefreshable(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.AgonyDebuff))
end

local function EvaluateCycleCorruption(TargetUnit)
  -- target_if=remains<5
  return (TargetUnit:DebuffRemains(S.CorruptionDebuff) < 5)
end

local function EvaluateCycleCorruptionRefreshable(TargetUnit)
  -- target_if=refreshable
  return (TargetUnit:DebuffRefreshable(S.CorruptionDebuff))
end

local function EvaluateCycleDrainSoul(TargetUnit)
  -- if=buff.nightfall.react&talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
  -- Note: Non-debuff checks done before CastCycle.
  return (TargetUnit:DebuffStack(S.ShadowEmbraceDebuff) < 3 or TargetUnit:DebuffRemains(S.ShadowEmbraceDebuff) < 3)
end

local function EvaluateCycleDrainSoul2(TargetUnit)
  -- if=(talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3))|!talent.shadow_embrace
  return ((S.ShadowEmbrace:IsAvailable() and (TargetUnit:DebuffStack(S.ShadowEmbraceDebuff) < 3 or TargetUnit:DebuffRemains(S.ShadowEmbraceDebuff) < 3)) or not S.ShadowEmbrace:IsAvailable())
end

local function EvaluateCycleSiphonLife(TargetUnit)
  -- target_if=remains<5
  return (TargetUnit:DebuffRemains(S.SiphonLifeDebuff) < 5)
end

local function EvaluateCycleSiphonLife2(TargetUnit)
  -- target_if=remains<5
  -- This version of the cycle checks if Agony is up also, as required by the "if=" portion of the condition
  return (TargetUnit:DebuffRemains(S.SiphonLifeDebuff) < 5 and TargetUnit:DebuffUp(S.AgonyDebuff))
end

local function Precombat()
  -- flask
  -- food
  -- augmentation
  -- summon_pet - Moved to APL()
  -- variable,name=cleave_apl,default=0,op=reset
  -- Note: Not adding an option to force the Cleave function yet. Possible future addition?
  -- variable,name=trinket_1_buffs,value=trinket.1.has_use_buff
  -- variable,name=trinket_2_buffs,value=trinket.2.has_use_buff
  -- variable,name=trinket_1_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_1_buffs&(trinket.1.cooldown.duration%%cooldown.soul_rot.duration=0|cooldown.soul_rot.duration%%trinket.1.cooldown.duration=0)
  -- variable,name=trinket_2_sync,op=setif,value=1,value_else=0.5,condition=variable.trinket_2_buffs&(trinket.2.cooldown.duration%%cooldown.soul_rot.duration=0|cooldown.soul_rot.duration%%trinket.2.cooldown.duration=0)
  -- variable,name=trinket_1_manual,value=trinket.1.is.belorrelos_the_suncaller|trinket.1.is.timethiefs_gambit
  -- variable,name=trinket_2_manual,value=trinket.2.is.belorrelos_the_suncaller|trinket.2.is.timethiefs_gambit
  -- variable,name=trinket_1_exclude,value=trinket.1.is.ruby_whelp_shell|trinket.1.is.whispering_incarnate_icon
  -- variable,name=trinket_2_exclude,value=trinket.2.is.ruby_whelp_shell|trinket.2.is.whispering_incarnate_icon
  -- variable,name=trinket_1_buff_duration,value=trinket.1.proc.any_dps.duration+(trinket.1.is.mirror_of_fractured_tomorrows*20)+(trinket.1.is.nymues_unraveling_spindle*2)
  -- variable,name=trinket_2_buff_duration,value=trinket.2.proc.any_dps.duration+(trinket.2.is.mirror_of_fractured_tomorrows*20)+(trinket.2.is.nymues_unraveling_spindle*2)
  -- variable,name=trinket_priority,op=setif,value=2,value_else=1,condition=!variable.trinket_1_buffs&variable.trinket_2_buffs|variable.trinket_2_buffs&((trinket.2.cooldown.duration%variable.trinket_2_buff_duration)*(1+0.5*trinket.2.has_buff.intellect)*(variable.trinket_2_sync)*(1-0.5*(trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.is.ashes_of_the_embersoul)))>((trinket.1.cooldown.duration%variable.trinket_1_buff_duration)*(1+0.5*trinket.1.has_buff.intellect)*(variable.trinket_1_sync)*(1-0.5*(trinket.1.is.mirror_of_fractured_tomorrows|trinket.1.is.ashes_of_the_embersoul)))
  -- Note: Trinket variables moved to variable declarations and PLAYER_EQUIPMENT_CHANGED registration.
  -- grimoire_of_sacrifice,if=talent.grimoire_of_sacrifice.enabled
  if S.GrimoireofSacrifice:IsCastable() then
    if Cast(S.GrimoireofSacrifice, Settings.Affliction.GCDasOffGCD.GrimoireOfSacrifice) then return "grimoire_of_sacrifice precombat 2"; end
  end
  -- snapshot_stats
  -- seed_of_corruption,if=spell_targets.seed_of_corruption_aoe>2|talent.sow_the_seeds&spell_targets.seed_of_corruption_aoe>1
  -- NYI precombat multi target
  -- haunt
  if S.Haunt:IsReady() then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt precombat 6"; end
  end
  -- unstable_affliction,if=!talent.soul_swap
  if S.UnstableAffliction:IsReady() and (not S.SoulSwap:IsAvailable()) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction precombat 8"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt precombat 10"; end
  end
end

local function Variables()
  -- variable,name=ps_up,op=set,value=dot.phantom_singularity.ticking|!talent.phantom_singularity
  VarPSUp = (Target:DebuffUp(S.PhantomSingularityDebuff) or not S.PhantomSingularity:IsAvailable())
  -- variable,name=vt_up,op=set,value=dot.vile_taint_dot.ticking|!talent.vile_taint
  VarVTUp = (Target:DebuffUp(S.VileTaintDebuff) or not S.VileTaint:IsAvailable())
  -- variable,name=vt_ps_up,op=set,value=dot.vile_taint_dot.ticking|dot.phantom_singularity.ticking|(!talent.vile_taint&!talent.phantom_singularity)
  VarVTPSUp = (Target:DebuffUp(S.VileTaintDebuff) or Target:DebuffUp(S.PhantomSingularityDebuff) or (not S.VileTaint:IsAvailable() and not S.PhantomSingularity:IsAvailable()))
  -- variable,name=sr_up,op=set,value=dot.soul_rot.ticking|!talent.soul_rot
  VarSRUp = (Target:DebuffUp(S.SoulRotDebuff) or not S.SoulRot:IsAvailable())
  -- variable,name=cd_dots_up,op=set,value=variable.ps_up&variable.vt_up&variable.sr_up
  VarCDDoTsUp = (VarPSUp and VarVTUp and VarSRUp)
  -- variable,name=has_cds,op=set,value=talent.phantom_singularity|talent.vile_taint|talent.soul_rot|talent.summon_darkglare
  VarHasCDs = (S.PhantomSingularity:IsAvailable() or S.VileTaint:IsAvailable() or S.SoulRot:IsAvailable() or S.SummonDarkglare:IsAvailable())
  -- variable,name=cds_active,op=set,value=!variable.has_cds|(variable.cd_dots_up&(cooldown.summon_darkglare.remains>20|!talent.summon_darkglare))
  VarCDsActive = (not VarHasCDs or (VarCDDoTsUp and (S.SummonDarkglare:CooldownRemains() > 20 or not S.SummonDarkglare:IsAvailable())))
  -- variable,name=min_vt,op=reset,if=variable.min_vt
  -- variable,name=min_ps,op=reset,if=variable.min_ps
  -- Note: These are being set every cycle in APL().
end

local function Items()
  if Settings.Commons.Enabled.Trinkets then
    -- use_item,use_off_gcd=1,name=belorrelos_the_suncaller,if=((time>20&cooldown.summon_darkglare.remains>20)|(trinket.1.is.belorrelos_the_suncaller&(trinket.2.cooldown.remains|!variable.trinket_2_buffs|trinket.1.is.time_thiefs_gambit))|(trinket.2.is.belorrelos_the_suncaller&(trinket.1.cooldown.remains|!variable.trinket_1_buffs|trinket.2.is.time_thiefs_gambit)))&(!raid_event.adds.exists|raid_event.adds.up|spell_targets.belorrelos_the_suncaller>=5)|fight_remains<20
    if I.BelorrelostheSuncaller:IsEquippedAndReady() and (((HL.CombatTime() > 20 and S.SummonDarkglare:CooldownRemains() > 20) or (Trinket1:ID() == I.BelorrelostheSuncaller:ID() and (Trinket2:CooldownDown() or Trinket2:Cooldown() == 0 or Trinket1:ID() == I.TimeThiefsGambit:ID())) or (Trinket2:ID() == I.BelorrelostheSuncaller:ID() and (Trinket1:CooldownDown() or Trinket1:Cooldown() == 0 or Trinket2:ID() == I.TimeThiefsGambit:ID()))) or FightRemains < 20) then
      if Cast(I.BelorrelostheSuncaller, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(10)) then return "belorrelos_the_suncaller items 2"; end
    end
    local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
    local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
    -- use_item,slot=trinket1,if=(variable.cds_active)&(variable.trinket_priority=1|variable.trinket_2_exclude|!trinket.2.has_cooldown|(trinket.2.cooldown.remains|variable.trinket_priority=2&cooldown.summon_darkglare.remains>20&!pet.darkglare.active&trinket.2.cooldown.remains<cooldown.summon_darkglare.remains))&variable.trinket_1_buffs&!variable.trinket_1_manual|(variable.trinket_1_buff_duration+1>=fight_remains)
    if Trinket1ToUse and (VarCDsActive and (VarTrinketPriority == 1 or VarTrinket2Exclude or not Trinket2:HasCooldown() or (Trinket2:CooldownDown() or VarTrinketPriority == 2 and S.SummonDarkglare:CooldownRemains() > 20 and not DarkglareActive() and Trinket2:CooldownRemains() < S.SummonDarkglare:CooldownRemains())) and VarTrinket1Buffs and not VarTrinket1Manual or (VarTrinket1BuffDuration + 1 >= BossFightRemains)) then
      if Cast(Trinket1ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 4"; end
    end
    -- use_item,slot=trinket2,if=(variable.cds_active)&(variable.trinket_priority=2|variable.trinket_1_exclude|!trinket.1.has_cooldown|(trinket.1.cooldown.remains|variable.trinket_priority=1&cooldown.summon_darkglare.remains>20&!pet.darkglare.active&trinket.1.cooldown.remains<cooldown.summon_darkglare.remains))&variable.trinket_2_buffs&!variable.trinket_2_manual|(variable.trinket_2_buff_duration+1>=fight_remains)
    if Trinket2ToUse and (VarCDsActive and (VarTrinketPriority == 2 or VarTrinket1Exclude or not Trinket1:HasCooldown() or (Trinket1:CooldownDown() or VarTrinketPriority == 1 and S.SummonDarkglare:CooldownRemains() > 20 and not DarkglareActive() and Trinket1:CooldownRemains() < S.SummonDarkglare:CooldownRemains())) and VarTrinket2Buffs and not VarTrinket2Manual or (VarTrinket2BuffDuration + 1 >= BossFightRemains)) then
      if Cast(Trinket2ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 6"; end
    end
    -- use_item,name=time_thiefs_gambit,if=variable.cds_active|fight_remains<15|((trinket.1.cooldown.duration<cooldown.summon_darkglare.remains_expected+5)&active_enemies=1)|(active_enemies>1&havoc_active)
    -- Note: I believe havoc_active is a copy/paste error, since Havoc is a Destruction spec thing...
    if I.TimeThiefsGambit:IsEquippedAndReady() and (VarCDsActive or BossFightRemains < 15 or ((Trinket1:Cooldown() < S.SummonDarkglare:CooldownRemains() + 5) and EnemiesCount10ySplash == 1) or (EnemiesCount10ySplash > 1)) then
      if Cast(I.TimeThiefsGambit, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "time_thiefs_gambit items 8"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket1,if=!variable.trinket_1_buffs&!variable.trinket_1_manual&(!variable.trinket_1_buffs&(trinket.2.cooldown.remains|!variable.trinket_2_buffs)|talent.summon_darkglare&cooldown.summon_darkglare.remains_expected>20|!talent.summon_darkglare)
    if Trinket1ToUse and (not VarTrinket1Buffs and not VarTrinket1Manual and (not VarTrinket1Buffs and (Trinket2:CooldownDown() or not VarTrinket2Buffs) or S.SummonDarkglare:IsAvailable() and S.SummonDarkglare:CooldownRemains() > 20 or not S.SummonDarkglare:IsAvailable())) then
      if Cast(Trinket1ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "trinket1 (" .. Trinket1:Name() .. ") items 10"; end
    end
    -- use_item,use_off_gcd=1,slot=trinket2,if=!variable.trinket_2_buffs&!variable.trinket_2_manual&(!variable.trinket_2_buffs&(trinket.1.cooldown.remains|!variable.trinket_1_buffs)|talent.summon_darkglare&cooldown.summon_darkglare.remains_expected>20|!talent.summon_darkglare)
    if Trinket2ToUse and (not VarTrinket2Buffs and not VarTrinket2Manual and (not VarTrinket2Buffs and (Trinket1:CooldownDown() or not VarTrinket1Buffs) or S.SummonDarkglare:IsAvailable() and S.SummonDarkglare:CooldownRemains() > 20 or not S.SummonDarkglare:IsAvailable())) then
      if Cast(Trinket2ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "trinket2 (" .. Trinket2:Name() .. ") items 12"; end
    end
  end
  -- use_item,use_off_gcd=1,slot=main_hand
  if Settings.Commons.Enabled.Items then
    local MainHandOnUse, _, MainHandRange = Player:GetUseableItems(OnUseExcludes, 16)
    if MainHandOnUse and MainHandOnUse:IsReady() then
      if Cast(MainHandOnUse, nil, Settings.CommonsDS.DisplayStyle.Items, not Target:IsInRange(MainHandRange)) then return "Generic use_item for MH " .. MainHandOnUse:Name(); end
    end
  end
end

local function oGCD()
  if VarCDsActive then
    -- potion,if=variable.cds_active
    if Settings.Commons.Enabled.Potions then
      local PotionSelected = Everyone.PotionSelected()
      if PotionSelected and PotionSelected:IsReady() then
        if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion ogcd 2"; end
      end
    end
    -- berserking,if=variable.cds_active
    if S.Berserking:IsCastable() then
      if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking ogcd 4"; end
    end
    -- blood_fury,if=variable.cds_active
    if S.BloodFury:IsCastable() then
      if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury ogcd 6"; end
    end
    -- invoke_external_buff,name=power_infusion,if=variable.cds_active&(trinket.1.is.nymues_unraveling_spindle&trinket.1.cooldown.remains|trinket.2.is.nymues_unraveling_spindle&trinket.2.cooldown.remains|!equipped.nymues_unraveling_spindle)
    -- Note: Not handling external buffs
    -- fireblood,if=variable.cds_active
    if S.Fireblood:IsCastable() then
      if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood ogcd 8"; end
    end
    -- ancestral_call,if=variable.cds_active
    if S.AncestralCall:IsCastable() then
      if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call ogcd 10"; end
    end
  end
end

local function AoE()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- cycling_variable,name=min_agony,op=min,value=dot.agony.remains+(99*!dot.agony.ticking)
  -- cycling_variable,name=min_vt,op=min,default=10,value=dot.vile_taint.remains+(99*!dot.vile_taint.ticking)
  -- cycling_variable,name=min_ps,op=min,default=16,value=dot.phantom_singularity.remains+(99*!dot.phantom_singularity.ticking)
  -- variable,name=min_ps1,op=set,value=(variable.min_vt*talent.vile_taint<?variable.min_ps*talent.phantom_singularity)
  -- Calculating these in APL() so they're calculated each cycle.
  -- haunt,if=debuff.haunt.remains<3
  if S.Haunt:IsReady() and (Target:DebuffRemains(S.HauntDebuff) < 3) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt aoe 2"; end
  end
  -- vile_taint,if=(talent.souleaters_gluttony.rank=2&(variable.min_agony<1.5|cooldown.soul_rot.remains<=execute_time))|((talent.souleaters_gluttony.rank=1&cooldown.soul_rot.remains<=execute_time))|(talent.souleaters_gluttony.rank=0&(cooldown.soul_rot.remains<=execute_time|cooldown.vile_taint.remains>25))
  if S.VileTaint:IsReady() and ((S.SouleatersGluttony:TalentRank() == 2 and (VarMinAgony < 1.5 or S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime())) or (S.SouleatersGluttony:TalentRank() == 1 and S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime()) or (not S.SouleatersGluttony:IsAvailable() and (S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() or S.VileTaint:CooldownRemains() > 25))) then
    if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint aoe 4"; end
  end
  -- phantom_singularity,if=(cooldown.soul_rot.remains<=execute_time|talent.souleaters_gluttony.rank<1&(!talent.soul_rot|cooldown.soul_rot.remains<=execute_time|cooldown.soul_rot.remains>=25))&dot.agony.ticking
  if S.PhantomSingularity:IsCastable() and ((S.SoulRot:IsAvailable() and S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or not S.SouleatersGluttony:IsAvailable() and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or S.SoulRot:CooldownRemains() >= 25)) and Target:DebuffUp(S.AgonyDebuff)) then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity aoe 6"; end
  end
  -- unstable_affliction,if=remains<5
  if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction aoe 8"; end
  end
  -- agony,target_if=min:remains,if=active_dot.agony<8&(remains<cooldown.vile_taint.remains+action.vile_taint.cast_time|!talent.vile_taint)&gcd.max+action.soul_rot.cast_time+gcd.max<(variable.min_vt*talent.vile_taint<?variable.min_ps*talent.phantom_singularity)&remains<5
  if S.Agony:IsReady() and (S.AgonyDebuff:AuraActiveCount() < 8 and GCDMax * 2 + S.SoulRot:CastTime() < VarMinPS1) then
    if Everyone.CastTargetIf(S.Agony, Enemies40y, "min", EvaluateTargetIfFilterAgony, EvaluateTargetIfAgony3, not Target:IsSpellInRange(S.Agony)) then return "agony aoe 9"; end
  end
  -- siphon_life,target_if=remains<5,if=active_dot.siphon_life<6&cooldown.summon_darkglare.up&time<20&gcd.max+action.soul_rot.cast_time+gcd.max<(variable.min_vt*talent.vile_taint<?variable.min_ps*talent.phantom_singularity)&dot.agony.ticking
  if S.SiphonLife:IsReady() and (S.SiphonLifeDebuff:AuraActiveCount() < 6 and S.SummonDarkglare:CooldownUp() and HL.CombatTime() < 20 and GCDMax * 2 + S.SoulRot:CastTime() < VarMinPS1) then
    if Everyone.CastTargetIf(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLife2, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life aoe 10"; end
  end
  -- soul_rot,if=variable.vt_up&(variable.ps_up|talent.souleaters_gluttony.rank!=1)&dot.agony.ticking
  if S.SoulRot:IsReady() and (VarVTUp and (VarPSUp or S.SouleatersGluttony:TalentRank() ~= 1) and Target:DebuffUp(S.AgonyDebuff)) then
    if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot aoe 12"; end
  end
  -- seed_of_corruption,if=dot.corruption.remains<5&!(action.seed_of_corruption.in_flight|dot.seed_of_corruption.remains>0)
  if S.SeedofCorruption:IsReady() and (Target:DebuffRemains(S.CorruptionDebuff) < 5 and not (S.SeedofCorruption:InFlight() or Target:DebuffUp(S.SeedofCorruptionDebuff))) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption aoe 14"; end
  end
  -- corruption,target_if=min:remains,if=remains<5&!talent.seed_of_corruption
  if S.Corruption:IsReady() and (not S.SeedofCorruption:IsAvailable()) then
    if Everyone.CastTargetIf(S.Corruption, Enemies40y, "min", EvaluateTargetIfFilterCorruption, EvaluateTargetIfCorruption, not Target:IsSpellInRange(S.Corruption)) then return "corruption aoe 15"; end
  end
  -- summon_darkglare,if=variable.ps_up&variable.vt_up&variable.sr_up|cooldown.invoke_power_infusion_0.duration>0&cooldown.invoke_power_infusion_0.up&!talent.soul_rot
  -- Note: Not handling Power Infusion
  if CDsON() and S.SummonDarkglare:IsCastable() and (VarPSUp and VarVTUp and VarSRUp) then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare aoe 18"; end
  end
  -- drain_life,target_if=min:dot.soul_rot.remains,if=buff.inevitable_demise.stack>30&buff.soul_rot.up&buff.soul_rot.remains<=gcd.max&active_enemies>3
  if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) > 30 and Player:BuffUp(S.SoulRot) and Player:BuffRemains(S.SoulRot) <= GCDMax and EnemiesCount10ySplash > 3) then
    if Everyone.CastTargetIf(S.DrainLife, Enemies40y, "min", EvaluateTargetIfFilterSoulRot, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life aoe 19"; end
  end
  -- malefic_rapture,if=buff.umbrafire_kindling.up&(((active_enemies<6|time<30)&pet.darkglare.active)|!talent.doom_blossom)
  if S.MaleficRapture:IsReady() and (Player:BuffUp(S.UmbrafireKindlingBuff) and (((EnemiesCount10ySplash < 6 or HL.CombatTime() < 30) and DarkglareActive()) or not S.DoomBlossom:IsAvailable())) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture aoe 20"; end
  end
  -- seed_of_corruption,if=talent.sow_the_seeds
  if S.SeedofCorruption:IsReady() and S.SowTheSeeds:IsAvailable() then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption aoe 22"; end
  end
  -- malefic_rapture,if=((cooldown.summon_darkglare.remains>15|soul_shard>3)&!talent.sow_the_seeds)|buff.tormented_crescendo.up
  if S.MaleficRapture:IsReady() and (((S.SummonDarkglare:CooldownRemains() > 15 or SoulShards > 3) and not S.SowTheSeeds:IsAvailable()) or Player:BuffUp(S.TormentedCrescendoBuff)) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture aoe 24"; end
  end
  -- drain_life,target_if=min:dot.soul_rot.remains,if=(buff.soul_rot.up|!talent.soul_rot)&buff.inevitable_demise.stack>10
  if S.DrainLife:IsReady() and (Player:BuffUp(S.SoulRot) or not S.SoulRot:IsAvailable()) and Player:BuffStack(S.InevitableDemiseBuff) > 10 then
    if Everyone.CastTargetIf(S.DrainLife, Enemies40y, "min", EvaluateTargetIfFilterSoulRot, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life aoe 26"; end
  end
  -- drain_soul,cycle_targets=1,if=buff.nightfall.react&talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
  if S.DrainSoul:IsReady() and (Player:BuffUp(S.NightfallBuff) and S.ShadowEmbrace:IsAvailable()) then
    if Everyone.CastCycle(S.DrainSoul, Enemies40y, EvaluateCycleDrainSoul, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul aoe 28"; end
  end
  -- summon_soulkeeper,if=buff.tormented_soul.stack=10|buff.tormented_soul.stack>3&fight_remains<10
  if S.SummonSoulkeeper:IsReady() and (S.SummonSoulkeeper:Count() == 10 or S.SummonSoulkeeper:Count() > 3 and FightRemains < 10) then
    if Cast(S.SummonSoulkeeper) then return "soul_strike aoe 32"; end
  end
  -- siphon_life,target_if=remains<5,if=active_dot.siphon_life<5&(active_enemies<8|!talent.doom_blossom)
  if S.SiphonLife:IsReady() and (S.SiphonLifeDebuff:AuraActiveCount() < 5 and (EnemiesCount10ySplash < 8 or not S.DoomBlossom:IsAvailable())) then
    if Everyone.CastCycle(S.SiphonLife, Enemies40y, EvaluateCycleSiphonLife, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life aoe 34"; end
  end
  -- drain_soul,cycle_targets=1,interrupt_global=1,if=(talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3))|!talent.shadow_embrace
  if S.DrainSoul:IsReady() then
    if Everyone.CastCycle(S.DrainSoul, Enemies40y, EvaluateCycleDrainSoul2, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul aoe 36"; end
  end
  -- shadow_bolt
  if S.ShadowBolt:IsReady() then
    if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt aoe 38"; end
  end
end

local function Cleave()
  -- call_action_list,name=ogcd
  if CDsON() then
    local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
  end
  -- call_action_list,name=items
  if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
    local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
  end
  -- malefic_rapture,if=talent.dread_touch&debuff.dread_touch.remains<2&(dot.agony.remains>gcd.max&dot.corruption.ticking&(!talent.siphon_life|dot.siphon_life.ticking)&dot.unstable_affliction.ticking)&(!talent.phantom_singularity|!cooldown.phantom_singularity.ready)&(!talent.vile_taint|!cooldown.vile_taint.ready)&(!talent.soul_rot|!cooldown.soul_rot.ready)|soul_shard>4
  if S.MaleficRapture:IsReady() and (S.DreadTouch:IsAvailable() and Target:DebuffRemains(S.DreadTouchDebuff) < 2 and (Target:DebuffRemains(S.AgonyDebuff) > GCDMax and Target:DebuffUp(S.CorruptionDebuff) and (not S.SiphonLife:IsAvailable() or Target:DebuffUp(S.SiphonLifeDebuff)) and Target:DebuffUp(S.UnstableAfflictionDebuff)) and (not S.PhantomSingularity:IsAvailable() or S.PhantomSingularity:CooldownDown()) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownDown()) and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownDown()) or SoulShards > 4) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 2"; end
  end
  -- vile_taint,if=!talent.soul_rot|(variable.min_agony<1.5|cooldown.soul_rot.remains<=execute_time+gcd.max)|talent.souleaters_gluttony.rank<1&cooldown.soul_rot.remains>=12
  if S.VileTaint:IsReady() and (not S.SoulRot:IsAvailable() or (VarMinAgony < 1.5 or S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() + GCDMax) or not S.SouleatersGluttony:IsAvailable() and S.SoulRot:CooldownRemains() >= 12) then
    if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint cleave 4"; end
  end
  -- phantom_singularity,if=(cooldown.soul_rot.remains<=execute_time|talent.souleaters_gluttony.rank<1&(!talent.soul_rot|cooldown.soul_rot.remains<=execute_time|cooldown.soul_rot.remains>=25))&active_dot.agony=2
  if S.PhantomSingularity:IsReady() and ((S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or not S.SouleatersGluttony:IsAvailable() and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or S.SoulRot:CooldownRemains() >= 25)) and S.AgonyDebuff:AuraActiveCount() >= 2) then
    if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity cleave 6"; end
  end
  -- soul_rot,if=(variable.vt_up&(variable.ps_up|talent.souleaters_gluttony.rank!=1))&active_dot.agony=2
  if S.SoulRot:IsReady() and ((VarVTUp and (VarPSUp or S.SouleatersGluttony:TalentRank() ~= 1)) and S.AgonyDebuff:AuraActiveCount() >= 2) then
    if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot cleave 8"; end
  end
  -- agony,target_if=min:remains,if=(remains<cooldown.vile_taint.remains+action.vile_taint.cast_time|!talent.vile_taint)&remains<5&fight_remains>5
  if S.Agony:IsReady() then
    if Everyone.CastTargetIf(S.Agony, Enemies40y, "min", EvaluateTargetIfFilterAgony, EvaluateTargetIfAgony4, not Target:IsSpellInRange(S.Agony)) then return "agony cleave 10"; end
  end
  -- unstable_affliction,if=remains<5&fight_remains>3
  if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5 and FightRemains > 3) then
    if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction cleave 12"; end
  end
  -- seed_of_corruption,if=!talent.absolute_corruption&dot.corruption.remains<5&talent.sow_the_seeds&can_seed
  if S.SeedofCorruption:IsReady() and (not S.AbsoluteCorruption:IsAvailable() and Target:DebuffRemains(S.CorruptionDebuff) < 5 and S.SowTheSeeds:IsAvailable() and CanSeed(Enemies40y)) then
    if Cast(S.SeedofCorruption, nil, nil, not Target:IsSpellInRange(S.SeedofCorruption)) then return "seed_of_corruption cleave 14"; end
  end
  -- haunt,if=debuff.haunt.remains<3
  if S.Haunt:IsReady() and (Target:DebuffRemains(S.HauntDebuff) < 3) then
    if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt cleave 16"; end
  end
  -- corruption,target_if=min:remains,if=remains<5&!(action.seed_of_corruption.in_flight|dot.seed_of_corruption.remains>0)&fight_remains>5
  if S.Corruption:IsReady() and (not (S.SeedofCorruption:InFlight() or Target:DebuffRemains(S.SeedofCorruptionDebuff) > 0) and FightRemains > 5) then
    if Everyone.CastTargetIf(S.Corruption, Enemies40y, "min", EvaluateTargetIfFilterCorruption, EvaluateTargetIfCorruption, not Target:IsSpellInRange(S.Corruption)) then return "corruption cleave 18"; end
  end
  -- siphon_life,target_if=min:remains,if=refreshable&fight_remains>5
  if S.SiphonLife:IsReady() and (FightRemains > 5) then
    if Everyone.CastTargetIf(S.SiphonLife, Enemies40y, "min", EvaluateTargetIfFilterSiphonLife, EvaluateTargetIfSiphonLife, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life cleave 20"; end
  end
  -- summon_darkglare,if=(!talent.shadow_embrace|debuff.shadow_embrace.stack=3)&variable.ps_up&variable.vt_up&variable.sr_up|cooldown.invoke_power_infusion_0.duration>0&cooldown.invoke_power_infusion_0.up&!talent.soul_rot
  if S.SummonDarkglare:IsReady() and ((not S.ShadowEmbrace:IsAvailable() or Target:DebuffStack(S.ShadowEmbraceDebuff) == 3) and VarPSUp and VarVTUp and VarSRUp) then
    if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare cleave 22"; end
  end
  -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.stack=1&soul_shard>3
  if S.MaleficRapture:IsReady() and (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 1 and SoulShards > 3) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 24"; end
  end
  -- drain_soul,interrupt=1,if=talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
  if S.DrainSoul:IsReady() and (S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < 3 or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3)) then
    if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul cleave 26"; end
  end
  -- drain_soul,target_if=min:debuff.shadow_embrace.remains,if=buff.nightfall.react&(talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)|!talent.shadow_embrace)
  -- shadow_bolt,target_if=min:debuff.shadow_embrace.remains,if=buff.nightfall.react&(talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)|!talent.shadow_embrace)
  if DSSB:IsReady() and (Player:BuffUp(S.NightfallBuff)) then
    if Everyone.CastTargetIf(DSSB, Enemies40y, "min", EvaluateTargetIfFilterShadowEmbrace, EvaluateTargetIfDrainSoul, not Target:IsSpellInRange(DSSB)) then return "drain_soul/shadow_bolt cleave 28"; end
  end
  -- malefic_rapture,if=!talent.dread_touch&buff.tormented_crescendo.up
  if S.MaleficRapture:IsReady() and not S.DreadTouch:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 30"; end
  end
  -- malefic_rapture,if=variable.cd_dots_up|variable.vt_ps_up
  if S.MaleficRapture:IsReady() and (VarCDDoTsUp or VarVTPSUp) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 32"; end
  end
  -- malefic_rapture,if=soul_shard>3
  if S.MaleficRapture:IsReady() and (SoulShards > 3) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 34"; end
  end
  -- drain_life,if=buff.inevitable_demise.stack>48|buff.inevitable_demise.stack>20&fight_remains<4
  if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) > 48 or Player:BuffStack(S.InevitableDemiseBuff) > 20 and FightRemains < 4) then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life cleave 36"; end
  end
  -- drain_life,if=buff.soul_rot.up&buff.inevitable_demise.stack>30
  if S.DrainLife:IsReady() and (Player:BuffUp(S.SoulRot) and Player:BuffStack(S.InevitableDemiseBuff) > 30) then
    if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life cleave 38"; end
  end
  -- agony,target_if=refreshable
  if S.Agony:IsReady() then
    if Everyone.CastCycle(S.Agony, Enemies40y, EvaluateCycleAgonyRefreshable, not Target:IsSpellInRange(S.Agony)) then return "agony cleave 40"; end
  end
  -- corruption,target_if=refreshable
  if S.Corruption:IsCastable() then
    if Everyone.CastCycle(S.Corruption, Enemies40y, EvaluateCycleCorruptionRefreshable, not Target:IsSpellInRange(S.Corruption)) then return "corruption cleave 42"; end
  end
  -- malefic_rapture,if=soul_shard>1
  if S.MaleficRapture:IsReady() and (SoulShards > 1) then
    if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture cleave 44"; end
  end
  -- drain_soul,interrupt_global=1
  -- shadow_bolt
  if DSSB:IsReady() then
    if Cast(DSSB, nil, nil, not Target:IsSpellInRange(DSSB)) then return "drain_soul/shadow_bolt cleave 46"; end
  end
end

--- ======= MAIN =======
local function APL()
  -- Unit Update
  Enemies40y = Player:GetEnemiesInRange(40)
  Enemies10ySplash = Target:GetEnemiesInSplashRange(10)
  if AoEON() then
    EnemiesCount10ySplash = Target:GetEnemiesInSplashRangeCount(10)
  else
    EnemiesCount10ySplash = 1
  end

  if Everyone.TargetIsValid() or Player:AffectingCombat() then
    -- Calculate fight_remains
    BossFightRemains = HL.BossFightRemains()
    FightRemains = BossFightRemains
    if FightRemains == 11111 then
      FightRemains = HL.FightRemains(Enemies10ySplash, false)
    end

    -- SoulShards variable
    SoulShards = Player:SoulShardsP()

    -- Calculate "Min" Variables
    VarMinAgony = CalcMinDoT(Enemies10ySplash, S.AgonyDebuff)
    VarMinVT = CalcMinDoT(Enemies10ySplash, S.VileTaintDebuff)
    VarMinPS = CalcMinDoT(Enemies10ySplash, S.PhantomSingularityDebuff)
    VarMinPS1 = mathmax(VarMinVT * num(S.VileTaint:IsAvailable()), VarMinPS * num(S.PhantomSingularity:IsAvailable()))

    -- Calculate GCDMax
    GCDMax = Player:GCD() + 0.25
  end

  -- summon_pet 
  if S.SummonPet:IsCastable() then
    if Cast(S.SummonPet, Settings.Affliction.GCDasOffGCD.SummonPet) then return "summon_pet ooc"; end
  end

  if Everyone.TargetIsValid() then
    -- Precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=variables
    Variables()
    -- call_action_list,name=cleave,if=active_enemies!=1&active_enemies<3|variable.cleave_apl
    -- Note: Not using variable.cleave_apl to force Cleave for now.
    if (EnemiesCount10ySplash > 1 and EnemiesCount10ySplash < 3) then
      local ShouldReturn = Cleave(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=aoe,if=active_enemies>2
    if (EnemiesCount10ySplash > 2) then
      local ShouldReturn = AoE(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=ogcd
    if CDsON() then
      local ShouldReturn = oGCD(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=items
    if Settings.Commons.Enabled.Trinkets or Settings.Commons.Enabled.Items then
      local ShouldReturn = Items(); if ShouldReturn then return ShouldReturn; end
    end
    -- malefic_rapture,if=talent.dread_touch&debuff.dread_touch.remains<2&(dot.agony.remains>gcd.max&dot.corruption.ticking&(!talent.siphon_life|dot.siphon_life.ticking)&dot.unstable_affliction.ticking)&(!talent.phantom_singularity|!cooldown.phantom_singularity.ready)&(!talent.vile_taint|!cooldown.vile_taint.ready)&(!talent.soul_rot|!cooldown.soul_rot.ready)
    if S.MaleficRapture:IsReady() and (S.DreadTouch:IsAvailable() and Target:DebuffRemains(S.DreadTouchDebuff) < 2 and (Target:DebuffRemains(S.AgonyDebuff) > GCDMax and Target:DebuffUp(S.CorruptionDebuff) and (not S.SiphonLife:IsAvailable() or Target:DebuffUp(S.SiphonLifeDebuff)) and Target:DebuffUp(S.UnstableAfflictionDebuff)) and (not S.PhantomSingularity:IsAvailable() or S.PhantomSingularity:CooldownDown()) and (not S.VileTaint:IsAvailable() or S.VileTaint:CooldownDown()) and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownDown())) then
      if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 2"; end
    end
    -- malefic_rapture,if=fight_remains<4
    if S.MaleficRapture:IsReady() and (FightRemains < 4) then
      if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 4"; end
    end
    -- vile_taint,if=!talent.soul_rot|(variable.min_agony<1.5|cooldown.soul_rot.remains<=execute_time+gcd.max)|talent.souleaters_gluttony.rank<1&cooldown.soul_rot.remains>=12
    if S.VileTaint:IsReady() and (not S.SoulRot:IsAvailable() or (VarMinAgony < 1.5 or S.SoulRot:CooldownRemains() <= S.VileTaint:ExecuteTime() + GCDMax) or not S.SouleatersGluttony:IsAvailable() and S.SoulRot:CooldownRemains() >= 12) then
      if Cast(S.VileTaint, nil, nil, not Target:IsInRange(40)) then return "vile_taint main 6"; end
    end
    -- phantom_singularity,if=(cooldown.soul_rot.remains<=execute_time|talent.souleaters_gluttony.rank<1&(!talent.soul_rot|cooldown.soul_rot.remains<=execute_time|cooldown.soul_rot.remains>=25))&dot.agony.ticking
    if S.PhantomSingularity:IsCastable() and ((S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or not S.SouleatersGluttony:IsAvailable() and (not S.SoulRot:IsAvailable() or S.SoulRot:CooldownRemains() <= S.PhantomSingularity:ExecuteTime() or S.SoulRot:CooldownRemains() >= 25)) and Target:DebuffUp(S.AgonyDebuff)) then
      if Cast(S.PhantomSingularity, Settings.Affliction.GCDasOffGCD.PhantomSingularity, nil, not Target:IsSpellInRange(S.PhantomSingularity)) then return "phantom_singularity main 8"; end
    end
    -- soul_rot,if=(variable.vt_up&(variable.ps_up|talent.souleaters_gluttony.rank!=1))&dot.agony.ticking
    if S.SoulRot:IsReady() and (VarVTUp and (VarPSUp or S.SouleatersGluttony:TalentRank() ~= 1) and Target:DebuffUp(S.AgonyDebuff)) then
      if Cast(S.SoulRot, nil, nil, not Target:IsSpellInRange(S.SoulRot)) then return "soul_rot main 10"; end
    end
    -- agony,if=(remains<cooldown.vile_taint.remains+action.vile_taint.cast_time|!talent.vile_taint)&remains<5&fight_remains>5
    -- Note: Swapped vile_taint conditions to avoid potential nil errors.
    if S.Agony:IsCastable() and ((not S.VileTaint:IsAvailable() or Target:DebuffRemains(S.AgonyDebuff) < S.VileTaint:CooldownRemains() + S.VileTaint:CastTime()) and Target:DebuffRemains(S.AgonyDebuff) < 5 and FightRemains > 5) then
      if Cast(S.Agony, nil, nil, not Target:IsSpellInRange(S.Agony)) then return "agony main 12"; end
    end
    -- unstable_affliction,if=remains<5&fight_remains>3
    if S.UnstableAffliction:IsReady() and (Target:DebuffRemains(S.UnstableAfflictionDebuff) < 5 and FightRemains > 3) then
      if Cast(S.UnstableAffliction, nil, nil, not Target:IsSpellInRange(S.UnstableAffliction)) then return "unstable_affliction main 14"; end
    end
    -- haunt,if=debuff.haunt.remains<5
    if S.Haunt:IsReady() and (Target:DebuffRemains(S.HauntDebuff) < 5) then
      if Cast(S.Haunt, nil, nil, not Target:IsSpellInRange(S.Haunt)) then return "haunt main 16"; end
    end
    -- corruption,if=refreshable&fight_remains>5
    if S.Corruption:IsCastable() and (Target:DebuffRefreshable(S.CorruptionDebuff) and FightRemains > 5) then
      if Cast(S.Corruption, nil, nil, not Target:IsSpellInRange(S.Corruption)) then return "corruption main 18"; end
    end
    -- siphon_life,if=refreshable&fight_remains>5
    if S.SiphonLife:IsCastable() and (Target:DebuffRefreshable(S.SiphonLifeDebuff) and FightRemains > 5) then
      if Cast(S.SiphonLife, nil, nil, not Target:IsSpellInRange(S.SiphonLife)) then return "siphon_life main 20"; end
    end
    -- summon_darkglare,if=(!talent.shadow_embrace|debuff.shadow_embrace.stack=3)&variable.ps_up&variable.vt_up&variable.sr_up|cooldown.invoke_power_infusion_0.duration>0&cooldown.invoke_power_infusion_0.up&!talent.soul_rot
    if S.SummonDarkglare:IsReady() and ((not S.ShadowEmbrace:IsAvailable() or Target:DebuffStack(S.ShadowEmbraceDebuff) == 3) and VarPSUp and VarVTUp and VarSRUp) then
      if Cast(S.SummonDarkglare, Settings.Affliction.GCDasOffGCD.SummonDarkglare) then return "summon_darkglare main 22"; end
    end
    -- drain_soul,interrupt=1,if=talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
    if S.DrainSoul:IsReady() and (S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < 3 or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3)) then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 24"; end
    end
    -- shadow_bolt,if=talent.shadow_embrace&(debuff.shadow_embrace.stack<3|debuff.shadow_embrace.remains<3)
    if S.ShadowBolt:IsReady() and (S.ShadowEmbrace:IsAvailable() and (Target:DebuffStack(S.ShadowEmbraceDebuff) < 3 or Target:DebuffRemains(S.ShadowEmbraceDebuff) < 3)) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 26"; end
    end
    if S.MaleficRapture:IsReady() and (
      -- malefic_rapture,if=soul_shard>4|(talent.tormented_crescendo&buff.tormented_crescendo.stack=1&soul_shard>3)
      (SoulShards > 4 or (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 1 and SoulShards > 3)) or
      -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.react&!debuff.dread_touch.react
      (S.TormentedCrescendo:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and Target:DebuffDown(S.DreadTouchDebuff)) or
      -- malefic_rapture,if=talent.tormented_crescendo&buff.tormented_crescendo.stack=2
      (S.TormentedCrescendo:IsAvailable() and Player:BuffStack(S.TormentedCrescendoBuff) == 2) or
      -- malefic_rapture,if=variable.cd_dots_up|variable.vt_ps_up&soul_shard>1
      (VarCDDoTsUp or VarVTPSUp and SoulShards > 1) or
      -- malefic_rapture,if=talent.tormented_crescendo&talent.nightfall&buff.tormented_crescendo.react&buff.nightfall.react
      (S.TormentedCrescendo:IsAvailable() and S.Nightfall:IsAvailable() and Player:BuffUp(S.TormentedCrescendoBuff) and Player:BuffUp(S.NightfallBuff))
    ) then
        if Cast(S.MaleficRapture, nil, nil, not Target:IsInRange(100)) then return "malefic_rapture main 28"; end
    end
    -- drain_life,if=buff.inevitable_demise.stack>48|buff.inevitable_demise.stack>20&fight_remains<4
    if S.DrainLife:IsReady() and (Player:BuffStack(S.InevitableDemiseBuff) > 48 or Player:BuffStack(S.InevitableDemiseBuff) > 20 and FightRemains < 4) then
      if Cast(S.DrainLife, nil, nil, not Target:IsSpellInRange(S.DrainLife)) then return "drain_life main 30"; end
    end
    -- drain_soul,if=buff.nightfall.react
    if S.DrainSoul:IsReady() and (Player:BuffUp(S.NightfallBuff)) then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 32"; end
    end
    -- shadow_bolt,if=buff.nightfall.react
    if S.ShadowBolt:IsReady() and (Player:BuffUp(S.NightfallBuff)) then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 34"; end
    end
    -- drain_soul,interrupt=1
    if S.DrainSoul:IsReady() then
      if Cast(S.DrainSoul, nil, nil, not Target:IsSpellInRange(S.DrainSoul)) then return "drain_soul main 36"; end
    end
    -- shadow_bolt
    if S.ShadowBolt:IsReady() then
      if Cast(S.ShadowBolt, nil, nil, not Target:IsSpellInRange(S.ShadowBolt)) then return "shadow_bolt main 38"; end
    end
  end
end

local function OnInit()
  S.AgonyDebuff:RegisterAuraTracking()
  S.CorruptionDebuff:RegisterAuraTracking()
  S.SiphonLifeDebuff:RegisterAuraTracking()
  S.UnstableAfflictionDebuff:RegisterAuraTracking()

  HR.Print("Affliction Warlock rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(265, APL, OnInit)