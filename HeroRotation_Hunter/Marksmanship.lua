--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroDBC
local DBC        = HeroDBC.DBC
-- HeroLib
local HL         = HeroLib
local Cache      = HeroCache
local Unit       = HL.Unit
local Player     = Unit.Player
local Target     = Unit.Target
local Pet        = Unit.Pet
local Spell      = HL.Spell
local MultiSpell = HL.MultiSpell
local Item       = HL.Item
-- HeroRotation
local HR         = HeroRotation
local Cast       = HR.Cast
local CDsON      = HR.CDsON
local AoEON      = HR.AoEON
-- Num/Bool Helper Functions
local num        = HR.Commons.Everyone.num
local bool       = HR.Commons.Everyone.bool
-- lua
local GetTime    = GetTime
-- File Locals
local Hunter     = HR.Commons.Hunter

--- ============================ CONTENT ===========================
--- ======= APL LOCALS =======
-- luacheck: max_line_length 9999

-- Define S/I for spell and item arrays
local S = Spell.Hunter.Marksmanship
local I = Item.Hunter.Marksmanship

-- Define array of summon_pet spells
local SummonPetSpells = { S.SummonPet, S.SummonPet2, S.SummonPet3, S.SummonPet4, S.SummonPet5 }

-- Create table to exclude above trinkets from On Use function
local OnUseExcludes = {
  -- I.ItemName:ID(),
}

-- Trinket Item Objects
local Equip = Player:GetEquipment()
local Trinket1 = (Equip[13]) and Item(Equip[13]) or Item(0)
local Trinket2 = (Equip[14]) and Item(Equip[14]) or Item(0)

-- Rotation Var
local SteadyShotTracker = { LastCast = 0, Count = 0 }
local VarTrueshotReady
local BossFightRemains = 11111
local FightRemains = 11111
local VarSyncActive = false
local VarSyncReady = false
local VarSyncRemains = 0
local VarTrinket1Stronger = not Trinket2:HasCooldown() or Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() or not Trinket1:ID() == I.MirrorofFracturedTomorrows:ID() and (Trinket2:ID() == I.MirrorofFracturedTomorrows:ID() or Trinket2:Cooldown() < Trinket1:Cooldown() or Trinket2:CastTime() < Trinket1:CastTime() or Trinket2:CastTime() == Trinket1:CastTime() and Trinket2:Cooldown() == Trinket1:Cooldown())) or not Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() and (Trinket2:Cooldown() < Trinket1:Cooldown() or Trinket2:CastTime() < Trinket1:CastTime() or Trinket2:CastTime() == Trinket1:CastTime() and Trinket2:Cooldown() == Trinket1:Cooldown()))
local VarTrinket2Stronger = not VarTrinket1Stronger

-- Enemy Range Variables
local Enemies40y
local Enemies10ySplash
local EnemiesCount10ySplash
local TargetInRange40y

-- GUI Settings
local Everyone = HR.Commons.Everyone;
local Settings = {
  General = HR.GUISettings.General,
  Commons = HR.GUISettings.APL.Hunter.Commons,
  CommonsDS = HR.GUISettings.APL.Hunter.CommonsDS,
  CommonsOGCD = HR.GUISettings.APL.Hunter.CommonsOGCD,
  Marksmanship = HR.GUISettings.APL.Hunter.Marksmanship
};

-- Variables
local VarCAExecute = Target:HealthPercentage() > 70 and S.CarefulAim:IsAvailable()

-- Interrupts
local StunInterrupts = {
  { S.Intimidation, "Cast Intimidation (Interrupt)", function () return true; end },
};

HL:RegisterForEvent(function()
  Equip = Player:GetEquipment()
  Trinket1 = (Equip[13]) and Item(Equip[13]) or Item(0)
  Trinket2 = (Equip[14]) and Item(Equip[14]) or Item(0)
  VarTrinket1Stronger = not Trinket2:HasCooldown() or Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() or not Trinket1:ID() == I.MirrorofFracturedTomorrows:ID() and (Trinket2:ID() == I.MirrorofFracturedTomorrows:ID() or Trinket2:Cooldown() < Trinket1:Cooldown() or Trinket2:CastTime() < Trinket1:CastTime() or Trinket2:CastTime() == Trinket1:CastTime() and Trinket2:Cooldown() == Trinket1:Cooldown())) or not Trinket1:HasUseBuff() and (not Trinket2:HasUseBuff() and (Trinket2:Cooldown() < Trinket1:Cooldown() or Trinket2:CastTime() < Trinket1:CastTime() or Trinket2:CastTime() == Trinket1:CastTime() and Trinket2:Cooldown() == Trinket1:Cooldown()))
  VarTrinket2Stronger = not VarTrinket1Stronger
end, "PLAYER_EQUIPMENT_CHANGED")

HL:RegisterForEvent(function()
  SteadyShotTracker = { LastCast = 0, Count = 0 }
  BossFightRemains = 11111
  FightRemains = 11111
end, "PLAYER_REGEN_ENABLED")

HL:RegisterForEvent(function()
  S.SerpentSting:RegisterInFlight()
  S.SteadyShot:RegisterInFlight()
  S.AimedShot:RegisterInFlight()
end, "LEARNED_SPELL_IN_TAB")
S.SerpentSting:RegisterInFlight()
S.SteadyShot:RegisterInFlight()
S.AimedShot:RegisterInFlight()

-- TODO(mrdmnd) - if you're casting (aimed or rapid fire) with volley up, you actually only have trick shots for next
-- aimed shot if volley buff is still up at the end of the cast. also conceivably build in buffer here.
-- test Player:BuffRemains(S.VolleyBuff) against S.Trueshot:ExecuteTime() for more accuracy
local function TrickShotsBuffCheck()
  return (Player:BuffUp(S.TrickShotsBuff) and not Player:IsCasting(S.AimedShot) and not Player:IsChanneling(S.RapidFire)) or Player:BuffUp(S.VolleyBuff)
end

-- Update our SteadyFocus count
local function SteadyFocusUpdate()
  -- The LastCast < GetTime - CastTime check is to try to not double count a single cast
  if (SteadyShotTracker.Count == 0 or SteadyShotTracker.Count == 1) and Player:IsCasting(S.SteadyShot) and SteadyShotTracker.LastCast < GetTime() - S.SteadyShot:CastTime() then
    SteadyShotTracker.LastCast = GetTime()
    SteadyShotTracker.Count = SteadyShotTracker.Count + 1
  end
  -- Reset the counter if we cast anything that's not SteadyShot
  if not (Player:IsCasting(S.SteadyShot) or Player:PrevGCDP(1, S.SteadyShot)) then SteadyShotTracker.Count = 0 end
  -- Reset the counter if the last time we had the buff is newer than the last time we cast SteadyShot
  if S.SteadyFocusBuff.LastAppliedOnPlayerTime > SteadyShotTracker.LastCast then SteadyShotTracker.Count = 0 end
end

local function EvaluateTargetIfFilterSerpentRemains(TargetUnit)
  -- target_if=min:remains
  return (TargetUnit:DebuffRemains(S.SerpentStingDebuff))
end

local function EvaluateTargetIfFilterAimedShot(TargetUnit)
  -- target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99
  return (TargetUnit:DebuffRemains(S.SerpentStingDebuff) + num(S.SerpentSting:InFlight()) * 99)
end

local function EvaluateTargetIfFilterLatentPoison(TargetUnit)
  -- target_if=max:debuff.latent_poison.stack
  return (TargetUnit:DebuffStack(S.LatentPoisonDebuff))
end

local function EvaluateTargetIfSerpentSting(TargetUnit)
  -- if=refreshable&!talent.serpentstalkers_trickery&buff.trueshot.down
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and not S.SerpentstalkersTrickery:IsAvailable())
end

local function EvaluateTargetIfSerpentSting2(TargetUnit)
  -- if=refreshable&talent.hydras_bite&!talent.serpentstalkers_trickery
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and S.HydrasBite:IsAvailable() and not S.SerpentstalkersTrickery:IsAvailable())
end

local function EvaluateTargetIfSerpentSting3(TargetUnit)
  -- if=refreshable&talent.poison_injection&!talent.serpentstalkers_trickery
  return (TargetUnit:DebuffRefreshable(S.SerpentStingDebuff) and S.PoisonInjection:IsAvailable() and not S.SerpentstalkersTrickery:IsAvailable())
end

local function EvaluateTargetIfAimedShot(TargetUnit)
  -- if=talent.serpentstalkers_trickery&(buff.precise_shots.down|(buff.trueshot.up|full_recharge_time<gcd+cast_time)&(!talent.chimaera_shot|active_enemies<2|ca_active)|buff.trick_shots.remains>execute_time&active_enemies>1)
  return (S.SerpentstalkersTrickery:IsAvailable() and (Player:BuffDown(S.PreciseShotsBuff) or (Player:BuffUp(S.TrueshotBuff) or S.AimedShot:FullRechargeTime() < Player:GCD() + S.AimedShot:CastTime()) and (not S.ChimaeraShot:IsAvailable() or EnemiesCount10ySplash < 2 or TargetUnit:HealthPercentage() > 70) or Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:ExecuteTime() and EnemiesCount10ySplash > 1))
end

local function EvaluateTargetIfAimedShot2(TargetUnit)
  -- if=buff.precise_shots.down|(buff.trueshot.up|full_recharge_time<gcd+cast_time)&(!talent.chimaera_shot|active_enemies<2|ca_active)|buff.trick_shots.remains>execute_time&active_enemies>1
  return (Player:BuffDown(S.PreciseShotsBuff) or (Player:BuffUp(S.TrueshotBuff) or S.AimedShot:FullRechargeTime() < Player:GCD() + S.AimedShot:CastTime()) and (not S.ChimaeraShot:IsAvailable() or EnemiesCount10ySplash < 2 or TargetUnit:HealthPercentage() > 70) or Player:BuffRemains(S.TrickShotsBuff) > S.AimedShot:ExecuteTime() and EnemiesCount10ySplash > 1)
end

local function EvaluateTargetIfAimedShot3(TargetUnit)
  -- if=talent.serpentstalkers_trickery&(buff.trick_shots.remains>=execute_time&(buff.precise_shots.down|buff.trueshot.up|full_recharge_time<cast_time+gcd))
  return (S.SerpentstalkersTrickery:IsAvailable() and (Player:BuffRemains(S.TrickShotsBuff) >= S.AimedShot:ExecuteTime() and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.TrueshotBuff) or S.AimedShot:FullRechargeTime() < S.AimedShot:CastTime() + Player:GCD())))
end

local function EvaluateTargetIfAimedShot4(TargetUnit)
  -- if=(buff.trick_shots.remains>=execute_time&(buff.precise_shots.down|buff.trueshot.up|full_recharge_time<cast_time+gcd))
  return (Player:BuffRemains(S.TrickShotsBuff) >= S.AimedShot:ExecuteTime() and (Player:BuffDown(S.PreciseShotsBuff) or Player:BuffUp(S.TrueshotBuff) or S.AimedShot:FullRechargeTime() < S.AimedShot:CastTime() + Player:GCD()))
end

local function Precombat()
  -- flask
  -- augmentation
  -- food
  -- summon_pet,if=!talent.lone_wolf
  -- Note: Moved pet management to APL()
  -- snapshot_stats
  -- variable,name=trinket_1_stronger,value=!trinket.2.has_cooldown|trinket.1.has_use_buff&(!trinket.2.has_use_buff|!trinket.1.is.mirror_of_fractured_tomorrows&(trinket.2.is.mirror_of_fractured_tomorrows|trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))|!trinket.1.has_use_buff&(!trinket.2.has_use_buff&(trinket.2.cooldown.duration<trinket.1.cooldown.duration|trinket.2.cast_time<trinket.1.cast_time|trinket.2.cast_time=trinket.1.cast_time&trinket.2.cooldown.duration=trinket.1.cooldown.duration))
  -- variable,name=trinket_2_stronger,value=!variable.trinket_1_stronger
  -- Note: Moved to variable declarations and PLAYER_EQUIPMENT_CHANGED registration.
  -- salvo,precast_time=10
  if S.Salvo:IsCastable() then
    if Cast(S.Salvo, Settings.Marksmanship.OffGCDasOffGCD.Salvo) then return "salvo precombat 3"; end
  end
  -- use_item,name=algethar_puzzle_box
  if Settings.Commons.Enabled.Trinkets and I.AlgetharPuzzleBox:IsEquippedAndReady() then
    if Cast(I.AlgetharPuzzleBox, nil, Settings.CommonsDS.DisplayStyle.Trinkets) then return "algethar_puzzle_box precombat 4"; end
  end
  -- aimed_shot,if=active_enemies<3&(!talent.volley|active_enemies<2)
  -- Note: We can't actually get target counts before combat begins.
  if S.AimedShot:IsReady() and not Player:IsCasting(S.AimedShot) and (EnemiesCount10ySplash < 3 and (not S.Volley:IsAvailable() or EnemiesCount10ySplash < 2)) then
    if Cast(S.AimedShot, nil, nil, not TargetInRange40y) then return "aimed_shot precombat 6"; end
  end
  -- wailing_arrow,if=active_enemies>2|!talent.steady_focus
  -- Note: We can't actually get target counts before combat begins.
  if S.WailingArrow:IsReady() and not Player:IsCasting(S.WailingArrow) and (EnemiesCount10ySplash > 2 or not S.SteadyFocus:IsAvailable()) then
    if Cast(S.WailingArrow, Settings.Marksmanship.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow precombat 8"; end
  end
  -- steady_shot,if=active_enemies>2|talent.volley&active_enemies=2
  -- Note: We can't actually get target counts before combat begins.
  if S.SteadyShot:IsCastable() and (EnemiesCount10ySplash > 2 or S.Volley:IsAvailable() and EnemiesCount10ySplash == 2) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot precombat 10"; end
  end
end

local function Cds()
  -- invoke_external_buff,name=power_infusion,if=buff.trueshot.remains>12
  -- Note: Not handling external buffs.
  -- berserking,if=buff.trueshot.up|fight_remains<13
  if S.Berserking:IsReady() and (Player:BuffUp(S.TrueshotBuff) or FightRemains < 13) then
    if Cast(S.Berserking, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "berserking cds 2"; end
  end
  -- blood_fury,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<16
  if S.BloodFury:IsReady() and (Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30 or FightRemains < 16) then
    if Cast(S.BloodFury, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "blood_fury cds 4"; end
  end
  -- ancestral_call,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<16
  if S.AncestralCall:IsReady() and (Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30 or FightRemains < 16) then
    if Cast(S.AncestralCall, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "ancestral_call cds 6"; end
  end
  -- fireblood,if=buff.trueshot.up|cooldown.trueshot.remains>30|fight_remains<9
  if S.Fireblood:IsReady() and (Player:BuffUp(S.TrueshotBuff) or S.Trueshot:CooldownRemains() > 30 or FightRemains < 9) then
    if Cast(S.Fireblood, Settings.CommonsOGCD.OffGCDasOffGCD.Racials) then return "fireblood cds 8"; end
  end
  -- lights_judgment,if=buff.trueshot.down
  if S.LightsJudgment:IsReady() and (Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.LightsJudgment, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.LightsJudgment)) then return "lights_judgment cds 10"; end
  end
  -- potion,if=buff.trueshot.up&(buff.bloodlust.up|target.health.pct<20)|fight_remains<26
  if Settings.Commons.Enabled.Potions and (Player:BuffUp(S.TrueshotBuff) and (Player:BloodlustUp() or Target:HealthPercentage() < 20) or FightRemains < 26) then
    local PotionSelected = Everyone.PotionSelected()
    if PotionSelected and PotionSelected:IsReady() then
      if Cast(PotionSelected, nil, Settings.CommonsDS.DisplayStyle.Potions) then return "potion cds 12"; end
    end
  end
  -- salvo,if=active_enemies>2|cooldown.volley.remains<10
  if S.Salvo:IsCastable() and (EnemiesCount10ySplash > 2 or S.Volley:CooldownRemains() < 10) then
    if Cast(S.Salvo, Settings.Marksmanship.OffGCDasOffGCD.Salvo) then return "salvo cds 14"; end
  end
end

local function St()
  -- steady_shot,if=talent.steady_focus&steady_focus_count&(buff.steady_focus.remains<8|buff.steady_focus.down&!buff.trueshot.up)
  if S.SteadyShot:IsCastable() and (S.SteadyFocus:IsAvailable() and SteadyShotTracker.Count == 1 and (Player:BuffRemains(S.SteadyFocusBuff) < 8 or Player:BuffDown(S.SteadyFocusBuff) and Player:BuffDown(S.TrueshotBuff) and SteadyShotTracker.Count ~= 2)) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 2"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains<execute_time
  if S.RapidFire:IsCastable() and (Target:DebuffRemains(S.TrickShotsBuff) < S.RapidFire:ExecuteTime()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire st 4"; end
  end
  -- kill_shot,if=focus+cast_regen<focus.max
  if S.KillShot:IsReady() and (Player:FocusP() + Player:FocusCastRegen(S.KillShot:ExecuteTime()) < Player:FocusMax()) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot st 6"; end
  end
  -- volley,if=buff.salvo.up|variable.trueshot_ready|cooldown.trueshot.remains>45|fight_remains<12
  if S.Volley:IsReady() and (Player:BuffUp(S.SalvoBuff) or VarTrueshotReady or S.Trueshot:CooldownRemains() > 45 or FightRemains < 12) then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley, nil, not TargetInRange40y)  then return "volley st 8"; end
  end
  -- serpent_sting,target_if=min:dot.serpent_sting.remains,if=refreshable&!talent.serpentstalkers_trickery&buff.trueshot.down
  if S.SerpentSting:IsReady() and (Player:BuffDown(S.TrueshotBuff)) then
    if Everyone.CastTargetIf(S.SerpentSting, Enemies40y, "min", EvaluateTargetIfFilterSerpentRemains, EvaluateTargetIfSerpentSting, not TargetInRange40y) then return "serpent_sting st 10"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot st 12"; end
  end
  -- stampede
  if S.Stampede:IsCastable() then
    if Cast(S.Stampede, nil, nil, not Target:IsInRange(30)) then return "stampede st 14"; end
  end
  -- death_chakram
  if S.DeathChakram:IsReady() then
    if Cast(S.DeathChakram, nil, Settings.CommonsDS.DisplayStyle.Signature, not TargetInRange40y) then return "dark_chakram st 16"; end
  end
  -- wailing_arrow,if=active_enemies>1
  if S.WailingArrow:IsReady() and (EnemiesCount10ySplash > 1) then
    if Cast(S.WailingArrow, Settings.Marksmanship.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow st 18"; end
  end
  -- rapid_fire,if=(talent.surging_shots|action.aimed_shot.full_recharge_time>action.aimed_shot.cast_time+cast_time)&(focus+cast_regen<focus.max)
  if S.RapidFire:IsCastable() and ((S.SurgingShots:IsAvailable() or S.AimedShot:FullRechargeTime() > S.AimedShot:CastTime() + S.RapidFire:CastTime()) and (Player:FocusP() + Player:FocusCastRegen(S.RapidFire:ExecuteTime()) < Player:FocusMax())) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire st 20"; end
  end
  -- trueshot,if=variable.trueshot_ready
  if S.Trueshot:IsReady() and CDsON() and (VarTrueshotReady) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot) then return "trueshot st 22"; end
  end
  -- multishot,if=buff.salvo.up&!talent.volley
  if S.MultiShot:IsReady() and (Player:BuffUp(S.SalvoBuff) and not S.Volley:IsAvailable()) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot st 24"; end
  end
  -- aimed_shot,target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99,if=talent.serpentstalkers_trickery&(buff.precise_shots.down|(buff.trueshot.up|full_recharge_time<gcd+cast_time)&(!talent.chimaera_shot|active_enemies<2|ca_active)|buff.trick_shots.remains>execute_time&active_enemies>1)
  if S.AimedShot:IsReady() then
    if Everyone.CastTargetIf(S.AimedShot, Enemies40y, "min", EvaluateTargetIfFilterAimedShot, EvaluateTargetIfAimedShot, not TargetInRange40y) then return "aimed_shot st 26"; end
  end
  -- aimed_shot,target_if=max:debuff.latent_poison.stack,if=buff.precise_shots.down|(buff.trueshot.up|full_recharge_time<gcd+cast_time)&(!talent.chimaera_shot|active_enemies<2|ca_active)|buff.trick_shots.remains>execute_time&active_enemies>1
  if S.AimedShot:IsReady() then
    if Everyone.CastTargetIf(S.AimedShot, Enemies40y, "max", EvaluateTargetIfFilterLatentPoison, EvaluateTargetIfAimedShot2, not TargetInRange40y) then return "aimed_shot st 28"; end
  end
  -- wailing_arrow,if=buff.trueshot.down
  if S.WailingArrow:IsReady() and (Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.WailingArrow, Settings.Marksmanship.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow st 30"; end
  end
  -- kill_command,if=buff.trueshot.down
  if S.KillCommand:IsCastable() and (Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.KillCommand, nil, nil, not Target:IsInRange(50)) then return "kill_command st 32"; end
  end
  -- steel_trap
  if S.SteelTrap:IsCastable() then
    if Cast(S.SteelTrap, Settings.CommonsOGCD.GCDasOffGCD.SteelTrap, nil, not Target:IsInRange(40)) then return "steel_trap st 34"; end
  end
  -- chimaera_shot,if=buff.precise_shots.up|focus>cost+action.aimed_shot.cost
  if S.ChimaeraShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) or Player:FocusP() > S.ChimaeraShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "chimaera_shot st 36"; end
  end
  -- arcane_shot,if=buff.precise_shots.up|focus>cost+action.aimed_shot.cost
  if S.ArcaneShot:IsReady() and (Player:BuffUp(S.PreciseShotsBuff) or Player:FocusP() > S.ArcaneShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.ArcaneShot, nil, nil, not TargetInRange40y) then return "arcane_shot st 38"; end
  end
  -- bag_of_tricks,if=buff.trueshot.down
  if S.BagofTricks:IsReady() then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks st 40"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot st 42"; end
  end
end

local function Trickshots()
  -- steady_shot,if=talent.steady_focus&steady_focus_count&buff.steady_focus.remains<8
  if S.SteadyShot:IsCastable() and (S.SteadyFocus:IsAvailable() and SteadyShotTracker.Count == 1 and Player:BuffRemains(S.SteadyFocusBuff) < 8) then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 2"; end
  end
  -- kill_shot,if=buff.razor_fragments.up
  if S.KillShot:IsReady() and (Player:BuffUp(S.RazorFragmentsBuff)) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot trickshots 4"; end
  end
  -- explosive_shot
  if S.ExplosiveShot:IsReady() then
    if Cast(S.ExplosiveShot, Settings.CommonsOGCD.GCDasOffGCD.ExplosiveShot, nil, not TargetInRange40y) then return "explosive_shot trickshots 8"; end
  end
  -- death_chakram
  if S.DeathChakram:IsReady() then
    if Cast(S.DeathChakram, nil, Settings.CommonsDS.DisplayStyle.Signature, not TargetInRange40y) then return "death_chakram trickshots 10"; end
  end
  -- stampede
  if S.Stampede:IsReady() then
    if Cast(S.Stampede, nil, nil, not Target:IsInRange(30)) then return "stampede trickshots 12"; end
  end
  -- wailing_arrow
  if S.WailingArrow:IsReady() then
    if Cast(S.WailingArrow, Settings.Marksmanship.GCDasOffGCD.WailingArrow, nil, not TargetInRange40y) then return "wailing_arrow trickshots 14"; end
  end
  -- serpent_sting,target_if=min:dot.serpent_sting.remains,if=refreshable&talent.hydras_bite&!talent.serpentstalkers_trickery
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, Enemies40y, "min", EvaluateTargetIfFilterSerpentRemains, EvaluateTargetIfSerpentSting2, not TargetInRange40y) then return "serpent_sting trickshots 16"; end
  end
  -- barrage,if=active_enemies>7
  if S.Barrage:IsReady() and (EnemiesCount10ySplash > 7) then
    if Cast(S.Barrage, nil, nil, not TargetInRange40y) then return "barrage trickshots 18"; end
  end
  -- volley
  if S.Volley:IsReady() then
    if Cast(S.Volley, Settings.Marksmanship.GCDasOffGCD.Volley)  then return "volley trickshots 20"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>=execute_time&talent.surging_shots
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) >= S.RapidFire:ExecuteTime() and S.SurgingShots:IsAvailable()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire trickshots 22"; end
  end
  -- trueshot,if=variable.trueshot_ready
  -- Note: Can't handle raid_event conditions.
  if S.Trueshot:IsReady() and CDsON() and (VarTrueshotReady) then
    if Cast(S.Trueshot, Settings.Marksmanship.OffGCDasOffGCD.Trueshot, nil, not TargetInRange40y) then return "trueshot trickshots 24"; end
  end
  -- aimed_shot,target_if=min:dot.serpent_sting.remains+action.serpent_sting.in_flight_to_target*99,if=talent.serpentstalkers_trickery&(buff.trick_shots.remains>=execute_time&(buff.precise_shots.down|buff.trueshot.up|full_recharge_time<cast_time+gcd))
  if S.AimedShot:IsReady() then
    if Everyone.CastTargetIf(S.AimedShot, Enemies40y, "min", EvaluateTargetIfFilterAimedShot, EvaluateTargetIfAimedShot3, not TargetInRange40y) then return "aimed_shot trickshots 26"; end
  end
  -- aimed_shot,target_if=max:debuff.latent_poison.stack,if=(buff.trick_shots.remains>=execute_time&(buff.precise_shots.down|buff.trueshot.up|full_recharge_time<cast_time+gcd))
  if S.AimedShot:IsReady() then
    if Everyone.CastTargetIf(S.AimedShot, Enemies40y, "max", EvaluateTargetIfFilterLatentPoison, EvaluateTargetIfAimedShot4, not TargetInRange40y) then return "aimed_shot trickshots 28"; end
  end
  -- rapid_fire,if=buff.trick_shots.remains>=execute_time
  if S.RapidFire:IsCastable() and (Player:BuffRemains(S.TrickShotsBuff) >= S.RapidFire:ExecuteTime()) then
    if Cast(S.RapidFire, Settings.Marksmanship.GCDasOffGCD.RapidFire, nil, not TargetInRange40y) then return "rapid_fire trickshots 30"; end
  end
  -- chimaera_shot,if=buff.trick_shots.up&buff.precise_shots.up&focus>cost+action.aimed_shot.cost&active_enemies<4
  if S.ChimaeraShot:IsReady() and (Player:BuffUp(S.TrickShotsBuff) and Player:BuffUp(S.PreciseShotsBuff) and Player:FocusP() > S.ChimaeraShot:Cost() + S.AimedShot:Cost() and EnemiesCount10ySplash < 4) then
    if Cast(S.ChimaeraShot, nil, nil, not TargetInRange40y) then return "chimaera_shot trickshots 32"; end
  end
  -- multishot,if=buff.trick_shots.down|(buff.precise_shots.up|buff.bulletstorm.stack=10)&focus>cost+action.aimed_shot.cost
  if S.MultiShot:IsReady() and (not TrickShotsBuffCheck() or (Player:BuffUp(S.PreciseShotsBuff) or Player:BuffStack(S.BulletstormBuff) == 10) and Player:FocusP() > S.MultiShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot trickshots 34"; end
  end
  -- serpent_sting,target_if=min:dot.serpent_sting.remains,if=refreshable&talent.poison_injection&!talent.serpentstalkers_trickery
  if S.SerpentSting:IsReady() then
    if Everyone.CastTargetIf(S.SerpentSting, Enemies40y, "min", EvaluateTargetIfFilterSerpentRemains, EvaluateTargetIfSerpentSting3, not TargetInRange40y) then return "serpent_sting trickshots 36"; end
  end
  -- steel_trap,if=buff.trueshot.down
  if S.SteelTrap:IsCastable() and (Player:BuffDown(S.TrueshotBuff)) then
    if Cast(S.SteelTrap, Settings.CommonsOGCD.GCDasOffGCD.SteelTrap, nil, not Target:IsInRange(40)) then return "steel_trap trickshots 38"; end
  end
  -- kill_shot,if=focus>cost+action.aimed_shot.cost
  if S.KillShot:IsReady() and (Player:FocusP() > S.KillShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.KillShot, nil, nil, not TargetInRange40y) then return "kill_shot trickshots 40"; end
  end
  -- multishot,if=focus>cost+action.aimed_shot.cost
  if S.MultiShot:IsReady() and (Player:FocusP() > S.MultiShot:Cost() + S.AimedShot:Cost()) then
    if Cast(S.MultiShot, nil, nil, not TargetInRange40y) then return "multishot trickshots 42"; end
  end
  -- bag_of_tricks,if=buff.trueshot.down
  if S.BagofTricks:IsReady() and (Player:BuffDown(S.Trueshot)) then
    if Cast(S.BagofTricks, Settings.CommonsOGCD.OffGCDasOffGCD.Racials, nil, not Target:IsSpellInRange(S.BagofTricks)) then return "bag_of_tricks trickshots 44"; end
  end
  -- steady_shot
  if S.SteadyShot:IsCastable() then
    if Cast(S.SteadyShot, nil, nil, not TargetInRange40y) then return "steady_shot trickshots 46"; end
  end
end

local function Trinkets()
  -- variable,name=sync_ready,value=variable.trueshot_ready
  VarSyncReady = VarTrueshotReady
  -- variable,name=sync_active,value=buff.trueshot.up
  VarSyncActive = Player:BuffUp(S.TrueshotBuff)
  -- variable,name=sync_remains,value=cooldown.trueshot.remains_guess
  VarSyncRemains = S.Trueshot:CooldownRemains()
  -- use_item,use_off_gcd=1,slot=trinket1,if=trinket.1.has_use_buff&(variable.sync_ready&(variable.trinket_1_stronger|trinket.2.cooldown.remains)|!variable.sync_ready&(variable.trinket_1_stronger&(variable.sync_remains>trinket.1.cooldown.duration%3&fight_remains>trinket.1.cooldown.duration+20|trinket.2.has_use_buff&trinket.2.cooldown.remains>variable.sync_remains-15&trinket.2.cooldown.remains-5<variable.sync_remains&variable.sync_remains+45>fight_remains)|variable.trinket_2_stronger&(trinket.2.cooldown.remains&(trinket.2.cooldown.remains-5<variable.sync_remains&variable.sync_remains>=20|trinket.2.cooldown.remains-5>=variable.sync_remains&(variable.sync_remains>trinket.1.cooldown.duration%3|trinket.1.cooldown.duration<fight_remains&(variable.sync_remains+trinket.1.cooldown.duration>fight_remains)))|trinket.2.cooldown.ready&variable.sync_remains>20&variable.sync_remains<trinket.2.cooldown.duration%3)))|!trinket.1.has_use_buff&(trinket.1.cast_time=0|!variable.sync_active)&(!trinket.2.has_use_buff&(variable.trinket_1_stronger|trinket.2.cooldown.remains)|trinket.2.has_use_buff&(variable.sync_remains>20|trinket.2.cooldown.remains>20))|fight_remains<25&(variable.trinket_1_stronger|trinket.2.cooldown.remains)
  local Trinket1ToUse, _, Trinket1Range = Player:GetUseableItems(OnUseExcludes, 13)
  if Trinket1ToUse and (Trinket1:HasUseBuff() and (VarSyncReady and (VarTrinket1Stronger or Trinket2:CooldownDown()) or not VarSyncReady and (VarTrinket1Stronger and (VarSyncRemains > Trinket1:Cooldown() / 3 and FightRemains > Trinket1:Cooldown() + 20 or Trinket2:HasUseBuff() and Trinket2:CooldownRemains() > VarSyncRemains - 15 and Trinket2:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains + 45 > FightRemains) or VarTrinket2Stronger and (Trinket2:CooldownDown() and (Trinket2:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains >= 20 or Trinket2:CooldownRemains() - 5 >= VarSyncRemains and (VarSyncRemains > Trinket1:Cooldown() / 3 or Trinket1:Cooldown() < FightRemains and (VarSyncRemains + Trinket1:Cooldown() > FightRemains))) or Trinket2:CooldownUp() and VarSyncRemains > 20 and VarSyncRemains < Trinket2:Cooldown() / 3))) or not Trinket1:HasUseBuff() and (Trinket1:CastTime() == 0 or not VarSyncActive) and (not Trinket2:HasUseBuff() and (VarTrinket1Stronger or Trinket2:CooldownDown()) or Trinket2:HasUseBuff() and (VarSyncRemains > 20 or Trinket2:CooldownRemains() > 20)) or FightRemains < 25 and (VarTrinket1Stronger or Trinket2:CooldownDown())) then
    if Cast(Trinket1ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket1Range)) then return "trinket1 ("..Trinket1ToUse:Name()..") trinkets 2"; end
  end
  -- use_item,use_off_gcd=1,slot=trinket2,if=trinket.2.has_use_buff&(variable.sync_ready&(variable.trinket_2_stronger|trinket.1.cooldown.remains)|!variable.sync_ready&(variable.trinket_2_stronger&(variable.sync_remains>trinket.2.cooldown.duration%3&fight_remains>trinket.2.cooldown.duration+20|trinket.1.has_use_buff&trinket.1.cooldown.remains>variable.sync_remains-15&trinket.1.cooldown.remains-5<variable.sync_remains&variable.sync_remains+45>fight_remains)|variable.trinket_1_stronger&(trinket.1.cooldown.remains&(trinket.1.cooldown.remains-5<variable.sync_remains&variable.sync_remains>=20|trinket.1.cooldown.remains-5>=variable.sync_remains&(variable.sync_remains>trinket.2.cooldown.duration%3|trinket.2.cooldown.duration<fight_remains&(variable.sync_remains+trinket.2.cooldown.duration>fight_remains)))|trinket.1.cooldown.ready&variable.sync_remains>20&variable.sync_remains<trinket.1.cooldown.duration%3)))|!trinket.2.has_use_buff&(trinket.2.cast_time=0|!variable.sync_active)&(!trinket.1.has_use_buff&(variable.trinket_2_stronger|trinket.1.cooldown.remains)|trinket.1.has_use_buff&(variable.sync_remains>20|trinket.1.cooldown.remains>20))|fight_remains<25&(variable.trinket_2_stronger|trinket.1.cooldown.remains)
  local Trinket2ToUse, _, Trinket2Range = Player:GetUseableItems(OnUseExcludes, 14)
  if Trinket2ToUse and (Trinket2:HasUseBuff() and (VarSyncReady and (VarTrinket2Stronger or Trinket1:CooldownDown()) or not VarSyncReady and (VarTrinket2Stronger and (VarSyncRemains > Trinket2:Cooldown() / 3 and FightRemains > Trinket2:Cooldown() + 20 or Trinket1:HasUseBuff() and Trinket1:CooldownRemains() > VarSyncRemains - 15 and Trinket1:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains + 45 > FightRemains) or VarTrinket1Stronger and (Trinket1:CooldownDown() and (Trinket1:CooldownRemains() - 5 < VarSyncRemains and VarSyncRemains >= 20 or Trinket1:CooldownRemains() - 5 >= VarSyncRemains and (VarSyncRemains > Trinket2:Cooldown() / 3 or Trinket2:Cooldown() < FightRemains and (VarSyncRemains + Trinket2:Cooldown() > FightRemains))) or Trinket1:CooldownUp() and VarSyncRemains > 20 and VarSyncRemains < Trinket1:Cooldown() / 3))) or not Trinket2:HasUseBuff() and (Trinket2:CastTime() == 0 or not VarSyncActive) and (not Trinket1:HasUseBuff() and (VarTrinket2Stronger or Trinket1:CooldownDown()) or Trinket1:HasUseBuff() and (VarSyncRemains > 20 or Trinket1:CooldownRemains() > 20)) or FightRemains < 25 and (VarTrinket2Stronger or Trinket1:CooldownDown())) then
    if Cast(Trinket2ToUse, nil, Settings.CommonsDS.DisplayStyle.Trinkets, not Target:IsInRange(Trinket2Range)) then return "trinket2 ("..Trinket2ToUse:Name()..") trinkets 4"; end
  end
end

--- ======= ACTION LISTS =======
local function APL()
  TargetInRange40y = Target:IsSpellInRange(S.AimedShot) -- Ranged abilities; Distance varies by Mastery
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
  end

  -- Pet Management
  if not S.LoneWolf:IsAvailable() and not (Player:IsMounted() or Player:IsInVehicle()) then
    if S.SummonPet:IsCastable() then
      if Cast(SummonPetSpells[Settings.Commons.SummonPetSlot], Settings.CommonsOGCD.GCDasOffGCD.SummonPet) then return "Summon Pet"; end
    end
  end

  if Everyone.TargetIsValid() then
    SteadyFocusUpdate()
    -- call precombat
    if not Player:AffectingCombat() then
      local ShouldReturn = Precombat(); if ShouldReturn then return ShouldReturn; end
    end
    -- Self heal, if below setting value
    if S.Exhilaration:IsReady() and Player:HealthPercentage() <= Settings.Commons.ExhilarationHP then
      if Cast(S.Exhilaration, Settings.CommonsOGCD.GCDasOffGCD.Exhilaration) then return "exhilaration"; end
    end
    -- Interrupts
    local ShouldReturn = Everyone.Interrupt(S.CounterShot, Settings.CommonsDS.DisplayStyle.Interrupts, StunInterrupts); if ShouldReturn then return ShouldReturn; end
    -- variable,name=trueshot_ready,value=cooldown.trueshot.ready&(!raid_event.adds.exists&(!talent.bullseye|fight_remains>cooldown.trueshot.duration_guess+buff.trueshot.duration%2|buff.bullseye.stack=buff.bullseye.max_stack)&(!trinket.1.has_use_buff|trinket.1.cooldown.remains>30|trinket.1.cooldown.ready)&(!trinket.2.has_use_buff|trinket.2.cooldown.remains>30|trinket.2.cooldown.ready)|raid_event.adds.exists&(!raid_event.adds.up&(raid_event.adds.duration+raid_event.adds.in<25|raid_event.adds.in>60)|raid_event.adds.up&raid_event.adds.remains>10)|fight_remains<25)
    -- Note: Can't handle the raid_event conditions.
    VarTrueshotReady = S.Trueshot:CooldownUp() and Player:BuffDown(S.TrueshotBuff)
    -- auto_shot
    -- call_action_list,name=cds
    if (CDsON()) then
      local ShouldReturn = Cds(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trinkets
    if Settings.Commons.Enabled.Trinkets then
      local ShouldReturn = Trinkets(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=st,if=active_enemies<3|!talent.trick_shots
    if EnemiesCount10ySplash < 3 or not S.TrickShots:IsAvailable() then
      local ShouldReturn = St(); if ShouldReturn then return ShouldReturn; end
    end
    -- call_action_list,name=trickshots,if=active_enemies>2
    if EnemiesCount10ySplash > 2 then
      local ShouldReturn = Trickshots(); if ShouldReturn then return ShouldReturn; end
    end
    -- Pool Focus if nothing else to do
    if HR.CastAnnotated(S.PoolFocus, false, "WAIT") then return "Pooling Focus"; end
  end
end

local function Init()
  HR.Print("Marksmanship Hunter rotation has been updated for patch 10.2.5.")
end

HR.SetAPL(254, APL, Init)
