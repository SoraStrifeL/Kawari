-- Quest: Parsemontrenomics (Parsemontret, Gridania market tour)
--
-- This is "Close to Home" (quest 124)'s market objective in disguise: live
-- testing confirmed talking to Parsemontret while doing quest 124 dispatches
-- THIS quest's own HandlerId (38), not a branch inside ManFst004_00124.lua's
-- onTalk (Quest.csv lists Parsemontret as quest 124's own ACTOR3, but that
-- branch never actually fires - same pattern as Madelle/quest 22). So this
-- quest's completion is what flips quest 124's market bit flag, not
-- anything in ManFst004_00124.lua itself.
--
-- State machine ported from the real retail server-emulator reference
-- (SapphireServer/Sapphire, src/scripts/quest/subquest/gridania/SubFst012.cpp):
-- talk to Parsemontret to accept, then visit 3 market vendors in any order
-- (Gurthcid, Admiranda, Alaric), then return to a 4th NPC (Ceinguled) to
-- hand over the Handmade Eel Pie (Quest.csv's NPCTRADEOK=100/NPCTRADENO=99
-- result codes for that step - Sapphire's reference doesn't call any
-- inventory/item-grant API for this either, it's tracked as a quest-scoped
-- virtual flag, not a real inventory item).
--
-- `sequence` is kept to exactly 0/1/255 (see ManFst004_00124.lua's note on
-- why - anything else breaks the quest journal on relog). The 3 "visited
-- this vendor" flags are tracked via this quest's own bit flags instead.
--
-- Live-confirmed finding: `target.object_id` is NOT a usable identifier for
-- distinguishing these 5 NPCs (it's the actor's randomly-assigned runtime
-- id, same issue as Miounne's - see ManFst004_00124.lua). The BASE_ID
-- global (set from a separate NPC-base-id cache, populated fresh for
-- whichever NPC triggered this specific dispatch) correctly reflects the
-- real ENpcBase id instead - confirmed live: BASE_ID=1000768 when talking
-- to Parsemontret, matching ENPC_PARSEMONTRET below exactly.
ENPC_PARSEMONTRET = 1000768
ENPC_GURTHCID = 1000214
ENPC_ADMIRANDA = 1000218
ENPC_ALARIC = 1000238
ENPC_CEINGULED = 1000248

QUEST_CLOSE_TO_HOME = 65536 + 124
CLOSE_TO_HOME_FLAG_ATTUNE = 0
CLOSE_TO_HOME_FLAG_CLASS = 1
CLOSE_TO_HOME_FLAG_TRADE = 2
CLOSE_TO_HOME_SEQ_ACCEPTED = 1
CLOSE_TO_HOME_SEQ_READY_TO_TURN_IN = 255

SEQ_NOT_ACCEPTED = 0
SEQ_ACCEPTED = 1
SEQ_READY_FOR_TRADE = 255

FLAG_VISITED_GURTHCID = 0
FLAG_VISITED_ADMIRANDA = 1
FLAG_VISITED_ALARIC = 2

function onTalk(target, player)
    local sequence = player:get_quest_sequence(EVENT_ID)
    print("[CloseToHome/38] onTalk BASE_ID=" .. tostring(BASE_ID) .. " sequence=" .. tostring(sequence))

    if BASE_ID == ENPC_PARSEMONTRET then
        if sequence == SEQ_NOT_ACCEPTED then
            player:play_scene(0, HIDE_HOTBAR, {})
            return
        end
    elseif BASE_ID == ENPC_GURTHCID then
        if sequence == SEQ_ACCEPTED and not player:get_quest_bit_flag(EVENT_ID, FLAG_VISITED_GURTHCID) then
            player:play_scene(1, HIDE_HOTBAR, {})
            return
        end
    elseif BASE_ID == ENPC_ADMIRANDA then
        if sequence == SEQ_ACCEPTED and not player:get_quest_bit_flag(EVENT_ID, FLAG_VISITED_ADMIRANDA) then
            player:play_scene(2, HIDE_HOTBAR, {})
            return
        end
    elseif BASE_ID == ENPC_ALARIC then
        if sequence == SEQ_ACCEPTED and not player:get_quest_bit_flag(EVENT_ID, FLAG_VISITED_ALARIC) then
            player:play_scene(3, HIDE_HOTBAR, {})
            return
        end
    elseif BASE_ID == ENPC_CEINGULED then
        if sequence == SEQ_READY_FOR_TRADE then
            player:play_scene(4, HIDE_HOTBAR, {})
            return
        end
    end

    player:finish_event()
end

-- Shared between onReturn and onYield: which of the two callbacks actually
-- fires for a given scene depends on whether the client treats it as a
-- mid-scene menu choice (yield) or a finished scene (return), which isn't
-- verifiable without live-testing - see ManFst004_00124.lua's own scene 0
-- (accept prompt) using onYield rather than onReturn for the same reason.
-- Handling both here means whichever one the client actually sends still
-- reaches the right logic.
function handle_scene(scene, results, player)
    print("[CloseToHome/38] handle_scene scene=" .. tostring(scene) .. " results[1]=" .. tostring(results[1]))

    if scene == 0 then
        if results[1] == 1 then
            player:accept_quest(EVENT_ID)
            player:quest_sequence(EVENT_ID, SEQ_ACCEPTED)
        end
    elseif scene == 1 then
        player:quest_bit_flag(EVENT_ID, FLAG_VISITED_GURTHCID, true)
        if player:get_quest_bit_flag(EVENT_ID, FLAG_VISITED_ADMIRANDA)
            and player:get_quest_bit_flag(EVENT_ID, FLAG_VISITED_ALARIC) then
            player:quest_sequence(EVENT_ID, SEQ_READY_FOR_TRADE)
        end
    elseif scene == 2 then
        player:quest_bit_flag(EVENT_ID, FLAG_VISITED_ADMIRANDA, true)
        if player:get_quest_bit_flag(EVENT_ID, FLAG_VISITED_GURTHCID)
            and player:get_quest_bit_flag(EVENT_ID, FLAG_VISITED_ALARIC) then
            player:quest_sequence(EVENT_ID, SEQ_READY_FOR_TRADE)
        end
    elseif scene == 3 then
        player:quest_bit_flag(EVENT_ID, FLAG_VISITED_ALARIC, true)
        if player:get_quest_bit_flag(EVENT_ID, FLAG_VISITED_GURTHCID)
            and player:get_quest_bit_flag(EVENT_ID, FLAG_VISITED_ADMIRANDA) then
            player:quest_sequence(EVENT_ID, SEQ_READY_FOR_TRADE)
        end
    elseif scene == 4 then
        if results[1] == 1 then
            player:finish_quest(EVENT_ID)

            if player:get_quest_sequence(QUEST_CLOSE_TO_HOME) == CLOSE_TO_HOME_SEQ_ACCEPTED then
                player:quest_bit_flag(QUEST_CLOSE_TO_HOME, CLOSE_TO_HOME_FLAG_TRADE, true)

                -- Opportunistically pick up the other two sub-objectives
                -- here too, same reasoning as RegFstCnjGuild_00023.lua -
                -- which handler/NPC the client dispatches to has turned out
                -- to be unpredictable, so every touchpoint re-checks all 3.
                local attuned = player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, CLOSE_TO_HOME_FLAG_ATTUNE)
                if not attuned and player:has_aetheryte(2) then
                    player:quest_bit_flag(QUEST_CLOSE_TO_HOME, CLOSE_TO_HOME_FLAG_ATTUNE, true)
                    attuned = true
                end

                if attuned and player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, CLOSE_TO_HOME_FLAG_CLASS) then
                    player:quest_sequence(QUEST_CLOSE_TO_HOME, CLOSE_TO_HOME_SEQ_READY_TO_TURN_IN)
                end
            end
        end
    end
end

function onReturn(scene, results, player)
    handle_scene(scene, results, player)
    player:finish_event()
end

function onYield(scene, id, results, player)
    handle_scene(scene, results, player)
    player:finish_event()
end
