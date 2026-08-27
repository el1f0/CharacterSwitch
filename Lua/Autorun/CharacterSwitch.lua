if SERVER then return end

local frame = GUI.Frame(
    GUI.RectTransform(
        Vector2.One
    ),
    nil
)
frame.CanBeFocused = false

local menu = GUI.Frame(
    GUI.RectTransform(
        Vector2.One,
        frame.RectTransform,
        GUI.Anchor.Center
    ),
    nil
)
menu.CanBeFocused = false
menu.Visible = false

local closeButton = GUI.Button(
    GUI.RectTransform(
        Vector2.One,
        menu.RectTransform,
        GUI.Anchor.Center
    ),
    "",
    GUI.Alignment.Center,
    nil
)
closeButton.OnClicked = function()
    menu.Visible = not menu.Visible
end

local button = GUI.Button(
    GUI.RectTransform(
        Vector2(0.2, 0.2),
        frame.RectTransform,
        GUI.Anchor.TopRight
    ),
    "Character Switch",
    GUI.Alignment.Center,
    "GUIButtonLarge"
)
button.RectTransform.AbsoluteOffset = Point(25, 100)
button.OnClicked = function()
    menu.Visible = not menu.Visible
end

local menuContent = GUI.Frame(
    GUI.RectTransform(
        Vector2(0.3, 0.6),
        menu.RectTransform,
        GUI.Anchor.Center
    )
)

local menuList = GUI.ListBox(
    GUI.RectTransform(
        Vector2.One,
        menuContent.RectTransform,
        GUI.Anchor.BottomCenter
    )
)

local localClient = nil
local mainCharacter = nil
local myTeamID = nil
local playableCharacterList = {}
local currentCharacterIndex = nil

local function FindMainCharacter()
    print("Finding main character")
    for _, client in pairs(Client.ClientList) do
        if client.Character == Character.Controlled and Character.Controlled ~= nil then
            localClient = client
            mainCharacter = localClient.Character
            myTeam = mainCharacter.TeamID
            return true
        end
    end
    print("Failed to find main character")
    return false
end

local function RefreshCharacterList()
    print("Refreshing player list")
    menuList.Content.ClearChildren()

    local function CreateCharacterButton(character, isMain)
        local scale = GUI.Scale

        local characterSelectButton = GUI.Button(
            GUI.RectTransform(Vector2(1, 0.025), menuList.Content.RectTransform), character.Name, GUI.Alignment.Left
        )

        local jobSprite = character.Info.Job.Prefab.Icon
        local jobColor = character.Info.Job.Prefab.UIColor
        if jobSprite then
            local iconSize = math.floor(32 * scale)
            local iconMargin = math.floor(150 * scale)
            local textMargin = math.floor(200 * scale)

            local iconImage = GUI.Image(
                GUI.RectTransform(
                    Point(iconSize, iconSize),
                    characterSelectButton.RectTransform,
                    GUI.Anchor.CenterLeft
                ),
                jobSprite,
                true
            )
            iconImage.Color = jobColor
            iconImage.RectTransform.AbsoluteOffset = Point(iconMargin, 0)
            iconImage.CanBeFocused = false

            characterSelectButton.TextBlock.RectTransform.AbsoluteOffset = Point(textMargin, 0)
        end
        characterSelectButton.OnClicked = function(userdata)
            ChangeCharacter(character)
            if isMain == false then end
            menu.Visible = false
        end
    end

    CreateCharacterButton(mainCharacter, true)

    for character in playableCharacterList do
        if Util.FindClientCharacter(character) == nil then
            CreateCharacterButton(character, false)
        end
    end
end

function ChangeCharacter(targetChar)
    local msg = Networking.Start("ChangeCharacter")
    msg.WriteString(targetChar.Name)
    Networking.Send(msg)
    return
end

local function RefreshPlayableCharacterList()

    local crewManager = Game.GameSession.CrewManager

    playableCharacterList = {}
    currentCharacterIndex = nil

    for _, character in pairs(crewManager.GetCharacters()) do
        if character ~= nil
            and not character.IsDead
            and character.TeamID == myTeam then
            table.insert(playableCharacterList, character)
        end
    end
end

local function CycleCharacter(offset)
    local startOffset = offset
    for _, character in pairs(playableCharacterList) do
        if character == localClient.Character then
            currentCharacterIndex = _
            break
        end
    end
    while true do
        if (currentCharacterIndex + offset > #playableCharacterList) then
            currentCharacterIndex = 0
            offset = startOffset
        elseif (currentCharacterIndex + offset <= 0) then
            currentCharacterIndex = #playableCharacterList + 1
            offset = startOffset
        end
        if Util.FindClientCharacter(playableCharacterList[currentCharacterIndex+offset]) == nil then
            ChangeCharacter(playableCharacterList[currentCharacterIndex+offset])
            break
        else
            if offset > 0 then
                offset = offset + 1
            elseif offset < 0 then
                offset = offset - 1
            end
        end
    end
end

local function RefreshData(loop)
    if loop==true then
        Timer.Wait(function()
            if FindMainCharacter() then
                RefreshPlayableCharacterList()
                RefreshCharacterList()
                print("Refresh complete")
            else
                RefreshData(true)
            end
        end, 500)
    else
        if FindMainCharacter() then
            RefreshPlayableCharacterList()
            RefreshCharacterList()
            print("Refresh complete")
        end
    end
end

Hook.Add("think", "CycleCharacter", function()
    if PlayerInput.KeyHit(Keys.Z) then
        print("Keypress Z")
        CycleCharacter(1)
    elseif PlayerInput.KeyHit(Keys.X) then
        print("Keypress X")
        CycleCharacter(-1)
    end
end)

Hook.Patch("Barotrauma.GameScreen", "AddToGUIUpdateList", function()
    if menu.Visible and PlayerInput.SecondaryMouseButtonClicked() then
        menu.Visible = false
    end

    frame.AddToGUIUpdateList()
end)

Hook.Add("roundStart", "UpdateCharacterSwitchMenu", function()
    print("ROUND START")
    RefreshData(true)
end)

Hook.Patch(
    "CrewOrderReordered",
    "Barotrauma.CrewManager",
    "OnCrewListRearranged",
    {
        "Barotrauma.GUIListBox",
        "System.Object"
    },
    function(instance, ptable)

        local crewList = ptable["crewList"]
        local draggedElementData = ptable["draggedElementData"]
        local character = draggedElementData
        local children = crewList.Content.Children

        if (crewList.HasDraggedElementIndexChanged) then
            print("=== CREW REORDERED ===")
            playableCharacterList = {}
            for component in children do
                if component ~= nil then
                    table.insert(playableCharacterList, component.UserData)
                end
            end
        else
            for playableCharacter in playableCharacterList do
                if character == playableCharacter and Util.FindClientCharacter(character) == nil then
                    ChangeCharacter(character)
                end
            end
        end


        return nil
    end,
    Hook.HookMethodType.After
)

RefreshData(false)
