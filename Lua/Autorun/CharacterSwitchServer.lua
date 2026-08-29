if CLIENT then return end

print("SCRIPT LOADED")

local clientNameList = {}

local function UpdateClientNameList()
    clientNameList = {}
    for _, client in pairs(Client.ClientList) do
        if client.Character ~= nil then
            table.insert(clientNameList, client.Name)
        end
    end
end

local function ChangeCharacter(clientName, targetName)
    local command = string.format('setclientcharacter "%s" "%s"', clientName, targetName)
    Game.ExecuteCommand(command)
    print("[CharacterSwitch] Changed Character")
end

Networking.Receive("ChangeCharacter", function(msg, client)
    local text = msg.ReadString()
    ChangeCharacter(client.Name, text)
end)

Hook.Patch(
    "EnableCharacterAI",
    "Barotrauma.Character",
    "Create",
    {
        "Barotrauma.CharacterPrefab",
        "Microsoft.Xna.Framework.Vector2",
        "System.String",
        "Barotrauma.CharacterInfo",
        "System.UInt16",
        "System.Boolean",
        "System.Boolean",
        "System.Boolean",
        "Barotrauma.RagdollParams",
        "System.Boolean"
    },
    function(instance, ptable)
        if ptable["isRemotePlayer"] == true and ptable["hasAi"] == false then
            print("*** PLAYER CHARACTER ***")
            print("forcing hasAi=true")

            ptable["hasAi"] = true
        end

        return nil
    end,
    Hook.HookMethodType.Before
)

Hook.Patch(
    "ChangeCharacterBeforeSave",
    "Barotrauma.Networking.GameServer",
    "ClientReadServerCommand",
    function(instance, ptable)
        local inc = ptable["inc"]

        local oldPosition = inc.BitPosition

        local command = inc.ReadUInt16()

        if command == 1 then
            local ending = inc.ReadBoolean()

            if ending then
                local save = inc.ReadBoolean()
                local quitCampaign = inc.ReadBoolean()

                if ending then
                    UpdateClientNameList()
                    for clientName in clientNameList do
                        ChangeCharacter(clientName, clientName)
                    end
                    if save then
                        print("SAVE & QUIT")
                    end
                end
            end
        end

        inc.BitPosition = oldPosition
    end
)

Hook.Add("roundEnd", "ChangeCharacterAtRoundEnd", function()
    print("ENDING ROUND")
    UpdateClientNameList()
    for clientName in clientNameList do
        ChangeCharacter(clientName, clientName)
    end
end)
