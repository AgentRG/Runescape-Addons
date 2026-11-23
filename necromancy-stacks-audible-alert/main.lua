-- Necromancy Stacks Audible Alert
-- Requires the PrettyUI dependency declared in plugin.json for its settings views.
require("resources")

-- Settings defaults apply only when no saved value exists.
local defaultSettings = {
    microsoftDavid = true,
    microsoftZira = false,
    residual3 = true,
    residual5 = true,
    necrosis6 = true,
    necrosis12 = true,
}

local settings = {}
for key, defaultValue in pairs(defaultSettings) do
    local savedValue = PersistentDB:GetBool(key)
    settings[key] = savedValue
    if savedValue == nil then
        settings[key] = defaultValue
        PersistentDB:SetBool(key, defaultValue)
    end
end

local alertOptions = {
    { key = "residual3", text = "Enable Residual Soul alert at 3 stacks", tooltip = "Play an alert when Residual Soul reaches 3 stacks." },
    { key = "residual5", text = "Enable Residual Soul alert at 5 stacks", tooltip = "Play an alert when Residual Soul reaches 5 stacks." },
    { key = "necrosis6", text = "Enable Necrosis alert at 6 stacks", tooltip = "Play an alert when Necrosis reaches 6 stacks." },
    { key = "necrosis12", text = "Enable Necrosis alert at 12 stacks", tooltip = "Play an alert when Necrosis reaches 12 stacks." },
}

local settingsView
local ribbonSettingsView
local previousNecrosisStacks
local previousResidualSoulStacks

-- Voice 1 audio files contain Microsoft David; voice 2 files contain Microsoft Zira.
local actions = {
    residualSoul = {
        [3] = { setting = "residual3", resources = {
            microsoftDavid = Plugin.resources.residual_soul_3_stacks_voice1,
            microsoftZira = Plugin.resources.residual_soul_3_stacks_voice2,
        } },
        [5] = { setting = "residual5", resources = {
            microsoftDavid = Plugin.resources.residual_soul_5_stacks_voice1,
            microsoftZira = Plugin.resources.residual_soul_5_stacks_voice2,
        } },
    },
    necrosis = {
        [6] = { setting = "necrosis6", resources = {
            microsoftDavid = Plugin.resources.necrosis_6_stacks_voice1,
            microsoftZira = Plugin.resources.necrosis_6_stacks_voice2,
        } },
        [12] = { setting = "necrosis12", resources = {
            microsoftDavid = Plugin.resources.necrosis_12_stacks_voice1,
            microsoftZira = Plugin.resources.necrosis_12_stacks_voice2,
        } },
    },
}

local createSettingsView
local playAlert
local checkThresholds
local updateNecromancyStacks

createSettingsView = function(parent, existingView)
    if existingView ~= nil then
        existingView:Destroy()
    end

    local view = prettyui.SimpleView.new(parent, {
        width = parent.width,
        height = parent.height,
    })

    view:AddText("Voice")
    view:AddRadioButton({
        { text = "Microsoft David", value = "microsoftDavid", tooltip = "Use Microsoft David for alerts." },
        { text = "Microsoft Zira", value = "microsoftZira", tooltip = "Use Microsoft Zira for alerts." },
    }, {
        selectedValue = settings.microsoftDavid and "microsoftDavid" or "microsoftZira",
        onChange = function(_, value)
            settings.microsoftDavid = value == "microsoftDavid"
            settings.microsoftZira = value == "microsoftZira"
            PersistentDB:SetBool("microsoftDavid", settings.microsoftDavid)
            PersistentDB:SetBool("microsoftZira", settings.microsoftZira)
        end,
    })

    view:AddCheckboxButton({
        { text = alertOptions[1].text, value = alertOptions[1].key, selected = settings.residual3, tooltip = alertOptions[1].tooltip },
        { text = alertOptions[2].text, value = alertOptions[2].key, selected = settings.residual5, tooltip = alertOptions[2].tooltip },
        { text = alertOptions[3].text, value = alertOptions[3].key, selected = settings.necrosis6, tooltip = alertOptions[3].tooltip },
        { text = alertOptions[4].text, value = alertOptions[4].key, selected = settings.necrosis12, tooltip = alertOptions[4].tooltip },
    }, {
        onChange = function(_, _, key, selected)
            settings[key] = selected
            PersistentDB:SetBool(key, selected)
        end,
    })

    return view
end

Event.SettingsLayerReady.Subscribe("NecromancyStacksAudibleAlertSettings", function(event)
    settingsView = createSettingsView(event.component, settingsView)
end)

Event.ContentLayerReady.Subscribe("NecromancyStacksAudibleAlertRibbonSettings", function(event)
    ribbonSettingsView = createSettingsView(event.component, ribbonSettingsView)
end)

playAlert = function(alert)
    -- Each alert references its threshold's enable setting; skip disabled alerts.
    if not settings[alert.setting] then
        return
    end

    -- Select the matching audio file for the currently selected voice.
    local resource
    if settings.microsoftDavid then
        resource = alert.resources.microsoftDavid
    else
        resource = alert.resources.microsoftZira
    end

    -- Play the selected resource using the client's default audio settings in the SFX bus.
    audio.Play(resource)
end

checkThresholds = function(stacks, previousStacks, thresholds)
    -- The first Logic update establishes the baseline; there is no earlier value to compare.
    if previousStacks == nil then
        return
    end

    -- Trigger an alert only when the count moves from below a threshold to at or above it (e.g. 4 necrosis stacks to 6 necrosis stacks).
    for threshold, alert in pairs(thresholds) do
        if previousStacks < threshold and stacks >= threshold then
            playAlert(alert)
        end
    end
end

updateNecromancyStacks = function()
    -- Read the current stack counts from the player's server variables.
    local necrosisStacks = var.VarPlayer["COMBATV2_BUFF_NECROMANCY_NECROSIS_STACKS"].value
    local residualSoulStacks = var.VarPlayer["COMBATV2_BUFF_NECROMANCY_RESIDUAL_SOUL_STACKS"].value

    -- Compare each current value against its previous Logic update.
    checkThresholds(necrosisStacks, previousNecrosisStacks, actions.necrosis)
    checkThresholds(residualSoulStacks, previousResidualSoulStacks, actions.residualSoul)

    -- Save these values for the next update's crossing checks.
    previousNecrosisStacks = necrosisStacks
    previousResidualSoulStacks = residualSoulStacks
end

-- Poll stack values on each client Logic update.
Event.Logic.Subscribe("NecromancyStacksAudibleAlert", updateNecromancyStacks)
