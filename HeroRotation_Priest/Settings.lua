--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, addonTable = ...
-- HeroRotation
local HR = HeroRotation
-- HeroLib
local HL = HeroLib
-- File Locals
local GUI = HL.GUI
local CreateChildPanel = GUI.CreateChildPanel
local CreatePanelOption = GUI.CreatePanelOption
local CreateARPanelOption = HR.GUI.CreateARPanelOption
local CreateARPanelOptions = HR.GUI.CreateARPanelOptions

--- ============================ CONTENT ============================
-- All settings here should be moved into the GUI someday.
HR.GUISettings.APL.Priest = {
  Commons = {
    Enabled = {
      Potions = true,
      Trinkets = true,
      Items = true,
    },
  },
  CommonsDS = {
    DisplayStyle = {
      -- Common
      Interrupts = "Cooldown",
      Items = "Suggested",
      Potions = "Suggested",
      Trinkets = "Suggested",
      -- Class Specific
    },
  },
  CommonsOGCD = {
    GCDasOffGCD = {
      PowerWordFortitude = true,
    },
    OffGCDasOffGCD = {
      Racials = true,
    }
  },
  Shadow = {
    DesperatePrayerHP = 75,
    DispersionHP = 30,
    ForceDevourMatter = false,
    VTMinHP = 20,
    PreferVTWhenSTinDungeon = false,
    SelfPI = true,
    PotionType = {
      Selected = "Tempered",
    },
    -- {Display GCD as OffGCD, ForceReturn}
    GCDasOffGCD = {
      DarkAscension = true,
      DesperatePrayer = false,
      DivineStar = true,
      Halo = false,
      HolyNova = true,
      Mindbender = true,
      ShadowCrash = false,
      Shadowform = true,
      ShadowWordDeath = false,
      ShadowWordPain = false,
      VoidEruption = true,
      VoidTorrent = false,
    },
    -- {Display OffGCD as OffGCD, ForceReturn}
    OffGCDasOffGCD = {
      Dispersion = true,
      PowerInfusion = false,
    }
  },
}

HR.GUI.LoadSettingsRecursively(HR.GUISettings)

-- Child Panels
local ARPanel = HR.GUI.Panel
local CP_Priest = CreateChildPanel(ARPanel, "Priest")
local CP_PriestDS = CreateChildPanel(CP_Priest, "Class DisplayStyles")
local CP_PriestOGCD = CreateChildPanel(CP_Priest, "Class OffGCDs")
local CP_Shadow = CreateChildPanel(CP_Priest, "Shadow")
local CP_ShadowOGCD = CreateChildPanel(CP_Priest, "Shadow OffGCDs")

-- Commons
CreateARPanelOptions(CP_Priest, "APL.Priest.Commons")
CreateARPanelOptions(CP_PriestDS, "APL.Priest.CommonsDS")
CreateARPanelOptions(CP_PriestOGCD, "APL.Priest.CommonsOGCD")

-- Shadow
CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.DesperatePrayerHP", { 0, 100, 1 }, "Desperate Prayer HP", "Set the Desperate Prayer HP threshold.")
CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.DispersionHP", { 0, 100, 1 }, "Dispersion HP", "Set the Dispersion HP threshold.")
CreatePanelOption("Slider", CP_Shadow, "APL.Priest.Shadow.VTMinHP", { 0, 100, 1 }, "Minimum VT HP (in millions)", "Set the minimum HP of a target for Vampiric Touch to be suggested. This value is multiplied by 1,000,000. For example, a value of 10 checks for a target's minimum HP of 10,000,000.")
CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.SelfPI", "Assume Self-Power Infusion", "Assume the player will be using Power Infusion on themselves.")
CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.PreferVTWhenSTinDungeon", "Prefer VT for dungeon ST", "Prefer to use Vampiric Touch while in single target combat in dungeon content. (Note: This does not apply to raid content.)")
CreatePanelOption("CheckButton", CP_Shadow, "APL.Priest.Shadow.ForceDevourMatter", "Force Devour Matter", "Enable this option to raise the priority on Shadow Word: Death to force the bonus from Devour Matter.")

-- Shadow OffGCDs
CreateARPanelOptions(CP_ShadowOGCD, "APL.Priest.Shadow")
