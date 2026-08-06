-- Generic aetheryte, use this for all of the aethernet shards

-- Scenes
SCENE_00000                 = 00000 -- does nothing
SCENE_00001                 = 00001 -- does nothing
SCENE_SHOW_MENU             = 00002 -- aetheryte menu
SCENE_HAVE_AETHERNET_ACCESS = 00003 -- "you have aethernet access" message and vfx
SCENE_00100                 = 00000 -- "According to the message engraved in the base, special permission is required to use this aetheryte." (Eulmore-specific)
SCENE_00200                 = 00200 -- "The aetheryte has ceased functioning." (Eulmore-specific)

function aetheryteId()
    return EVENT_ID & 0xFFFF
end

-- Retail's real attunement action id (ACTION_ATTUNE), same as the big
-- aetherytes - confirmed against the SapphireServer/Sapphire reference
-- (src/scripts/common/aethernet/Aetheryte.cpp, its aethernet() function).
ACTION_ATTUNE = 0x13

function onTalk(target, player)
    if not player:has_aetheryte(aetheryteId()) then
        -- Plays the client's own attunement animation/channel bar, then
        -- calls back into onEventActionComplete below once it's done -
        -- matching retail's real eventActionStart flow instead of silently
        -- unlocking with no visible interaction at all.
        player:event_action(ACTION_ATTUNE, target.object_id)
        return
    end

    player:play_scene(SCENE_SHOW_MENU, HIDE_HOTBAR, {0})
end

function onEventActionComplete(player)
    player:unlock_aetheryte(1, aetheryteId())
    -- Matches retail: show the "you have aethernet access" confirmation
    -- scene (already defined above) instead of just silently finishing.
    player:play_scene(SCENE_HAVE_AETHERNET_ACCESS, NO_DEFAULT_CAMERA, {})
end

function onReturn(scene, results, player)
    local AETHERNET_MENU_CANCEL = 0
    local destination = results[1]

    if scene == SCENE_SHOW_MENU then
        if destination ~= AETHERNET_MENU_CANCEL then
            player:finish_event() -- Need to finish the event here, because warping does not return to this callback (the game will crash or softlock otherwise)
            player:warp_aetheryte(destination)
            return
        end
    end

    player:finish_event()
end
