-- Mother Miounne in New Gridania
--
-- This is where the player returns to turn in "Close to Home" (quest 124).
-- Confirmed live that talking to her dispatches this generic CustomTalk
-- handler AND quest 124's own HandlerId at different times (the client
-- seems to alternate unpredictably, not tied to any state we control), so
-- the attune-pickup/completion-check logic is duplicated here from
-- ManFst004_00124.lua's onTalk - whichever handler the client picks, the
-- same checks run.

-- Scenes
SCENE_00000 = 00000 -- Greeting based on quest completion

QUEST_CLOSE_TO_HOME = 65536 + 124
SEQ_ACCEPTED = 1
SEQ_READY_TO_TURN_IN = 255

FLAG_ATTUNE = 0
FLAG_CLASS = 1
FLAG_TRADE = 2

function onTalk(target, player)
    local sequence = player:get_quest_sequence(QUEST_CLOSE_TO_HOME)
    print("[CloseToHome/156] onTalk sequence=" .. tostring(sequence)
        .. " attune=" .. tostring(player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_ATTUNE))
        .. " class=" .. tostring(player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_CLASS))
        .. " trade=" .. tostring(player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_TRADE)))

    if sequence ~= 0 and sequence ~= SEQ_READY_TO_TURN_IN then
        local attuned = player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_ATTUNE)
        if not attuned and player:has_aetheryte(2) then
            player:quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_ATTUNE, true)
            attuned = true
            print("[CloseToHome/156] onTalk picked up FLAG_ATTUNE from has_aetheryte(2)")
        end

        if attuned
            and player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_CLASS)
            and player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_TRADE) then
            player:quest_sequence(QUEST_CLOSE_TO_HOME, SEQ_READY_TO_TURN_IN)
            sequence = SEQ_READY_TO_TURN_IN
            print("[CloseToHome/156] onTalk all 3 flags set, sequence -> SEQ_READY_TO_TURN_IN")
        end
    end

    -- Confirmed live that calling finish_quest() here directly (skipping
    -- any scene) completed the quest with no visible dialogue/prompt at
    -- all. This handler's own scene 0 is labeled "Greeting based on quest
    -- completion" - i.e. the client already renders different dialogue for
    -- it depending on server-reported quest state, so just always play it
    -- and let the result tell us whether the player confirmed the turn-in.
    player:play_scene(SCENE_00000, HIDE_HOTBAR, {0})
end

function onReturn(scene, results, player)
    print("[CloseToHome/156] onReturn scene=" .. tostring(scene) .. " results[1]=" .. tostring(results[1]))

    if scene == SCENE_00000 then
        local sequence = player:get_quest_sequence(QUEST_CLOSE_TO_HOME)
        if sequence == SEQ_READY_TO_TURN_IN and results[1] == 1 then
            player:finish_quest(QUEST_CLOSE_TO_HOME)
            print("[CloseToHome/156] finish_quest called")
        end
    end

    player:finish_event()
end
