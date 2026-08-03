-- Quest: Close to Home (Gridania), for Conjurers
--
-- Real NPCs/sequence numbers verified against xivapi/ffxiv-datamining's
-- Quest.csv, row 65660 (this quest's raw HandlerId). Sub-objectives can be
-- done in any order (aetheryte, guild, market all advance from whatever
-- sequence they're gated at), matching retail's parallel-todo structure.
--
-- NOTE: Quest.csv's ACTOR0/ACTOR2/ACTOR3 values are cutscene-internal actor
-- references (used for camera/positioning alongside LOC_ACTOR0/BIND_ACTOR0),
-- NOT the actual clickable overworld ENpcBase id. Confirmed for Miounne:
-- ManFst001_00039.lua ("Coming to Gridania", also involves Miounne) uses
-- 1985113, not this quest's own ACTOR0 (1001140) - using the wrong value
-- meant target.object_id never matched and onTalk silently fell through to
-- finish_event() with no prompt ever shown. Madelle/Parsemontret below are
-- still the raw Quest.csv ACTOR2/ACTOR3 values and unverified against a
-- known-working reference the way Miounne's now is - check these the same
-- way if their branches don't fire either.
ENPC_MIOUNNE = 1985113
ENPC_MADELLE = 1000323
ENPC_PARSEMONTRET = 1000768

SEQ_NOT_ACCEPTED = 0
SEQ_AETHERYTE = 1
SEQ_GUILD = 2
SEQ_MARKET = 3
SEQ_READY_TO_TURN_IN = 4

function onTalk(target, player)
    local sequence = player:get_quest_sequence(EVENT_ID)

    if target.object_id == ENPC_MIOUNNE then
        if sequence == SEQ_NOT_ACCEPTED then
            -- Show the quest prompt
            player:play_scene(0, HIDE_HOTBAR, {})
            return
        elseif sequence == SEQ_READY_TO_TURN_IN then
            player:finish_quest(EVENT_ID)
        else
            player:send_message("Finish your other tasks first, then come back and see me.", 0)
        end
    end

    player:finish_event()
end

function onReturn(scene, results, player)
    if scene == 50 then
        -- Accept the quest, this also matches up with the client-side UI
        player:accept_quest(EVENT_ID)
        player:quest_sequence(EVENT_ID, SEQ_AETHERYTE)

        local old_position = player.position
        local old_rotation = player.rotation

        -- Just like in retail, "seamlessly" transition them to the real zone:
        player:change_territory(TERRITORYTYPE0, { x = old_position.x, y = old_position.y, z = old_position.z }, old_rotation)

        -- Send a message to remind the player that the rest of the quest won't function
        player:send_message("You reached the end of this quest! Interacting with the quest giver will not advance it any further.")
    end

    player:finish_event()
end

function onYield(scene, id, results, player)
    if scene == 0 and results[1] == 1 then
        -- Play the introductory text if accepted (this has to be played from Momodi)
        player:play_scene(50, HIDE_HOTBAR, {})
        return
    end

    player:finish_event()
end
