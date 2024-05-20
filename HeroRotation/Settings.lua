--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, HR = ...;
  -- HeroLib
  local HL = HeroLib;
  -- File Locals
  local GUI = HL.GUI;
  local CreatePanel = GUI.CreatePanel;
  local CreateChildPanel = GUI.CreateChildPanel;
  local CreatePanelOption = GUI.CreatePanelOption;


--- ============================ CONTENT ============================
  -- Default settings
  HR.GUISettings = {
    General = {
      -- Main Frame Strata
      MainFrameStrata = "BACKGROUND",
      -- Nameplate Icon Anchor
      NamePlateIconAnchor = "Clickable Area",
      -- Show while mounted
      ShowWhileMounted = false,
      -- Always show the Icon
      ForceReadyStatus = false,
      -- Black Border Icon (Enable if you want clean black borders)
      BlackBorderIcon = false,
      HideKeyBinds = false,
      -- Interrupt
      InterruptEnabled = false,
      InterruptWithStun = false, -- EXPERIMENTAL
      -- SoloMode try to maximize survivability at the cost of dps
      SoloMode = false,
      -- Remove the toggle icon buttons.
      HideToggleIcons = false,
      --
      NotEnoughManaEnabled = false,
      SetAlpha = 1,
      -- MoP Remix
      EnableMoPRemix = false,
    },
    Scaling = {
      ScaleUI = 1,
      ScaleButtons = 1,
      ScaleHotkey = 1,
      ScaleNameplateIcon = 1,
    },
    APL = {}
  };

  function HR.GUI.CorePanelSettingsInit ()
    -- GUI
    local ARPanel = CreatePanel(HR.GUI, "HeroRotation", "PanelFrame", HR.GUISettings, HeroRotationDB.GUISettings);
    -- Child Panel
    local CP_General = CreateChildPanel(ARPanel, "General");
    local CP_Scaling = CreateChildPanel(ARPanel, "Scaling");
    -- Controls
    CreatePanelOption("Dropdown", CP_General, "General.MainFrameStrata", {"HIGH", "MEDIUM", "LOW", "BACKGROUND"}, "Main Frame Strata", "Choose the frame strata to use for icons.", {ReloadRequired = true});
    CreatePanelOption("Dropdown", CP_General, "General.NamePlateIconAnchor", {"Clickable Area", "Life Bar", "Disable"}, "Nameplate Icon Anchor", "Choose the frame to anchor the Nameplate icon to (or disable it).", {ReloadRequired = true});
    CreatePanelOption("CheckButton", CP_General, "General.ShowWhileMounted", "Show While Mounted", "Enable if you want the HeroRotation icon to show while mounted.");
    CreatePanelOption("CheckButton", CP_General, "General.ForceReadyStatus", "Force Ready Status", "Enable if you want HeroRotation to always force a ready status. NOTE: The HeroRotation team does not suggest using this setting.");
    CreatePanelOption("CheckButton", CP_General, "General.BlackBorderIcon", "Black Border Icon", "Enable if you want clean black borders icons.", {ReloadRequired = true});
    CreatePanelOption("CheckButton", CP_General, "General.HideKeyBinds", "Hide Keybinds", "Enable if you want to hide the keybind on the icons.");
    CreatePanelOption("CheckButton", CP_General, "General.InterruptEnabled", "Interrupt", "Enable if you want to interrupt.");
    CreatePanelOption("CheckButton", CP_General, "General.InterruptWithStun", "Interrupt With Stun", "EXPERIMENTAL: Enable if you want to interrupt with stuns.");
    CreatePanelOption("CheckButton", CP_General, "General.SoloMode", "Solo Mode", "Enable if you want to try to maximize survivability at the cost of dps.");
    CreatePanelOption("CheckButton", CP_General, "General.HideToggleIcons", "Hide toggle icons", "Enable if you want to hide the toggle buttons on the icon frame.", {ReloadRequired = true});
    CreatePanelOption("CheckButton", CP_General, "General.NotEnoughManaEnabled", "Not enough mana/energy", "Enable if you want a faded icon when you have not enough mana or energy.");
    CreatePanelOption("CheckButton", CP_General, "General.EnableMoPRemix", "Enable for MoP Remix", "Enable if you want the addon to work for MoP Remix. NOTE: We cannot guarantee the APL will be optimized for this game mode.", {ReloadRequired = true})
  end
