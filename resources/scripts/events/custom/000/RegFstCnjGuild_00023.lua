-- Madelle, Conjurers' Guild receptionist (New Gridania)
--
-- Confirmed live: talking to her while doing "Close to Home" (quest 124)
-- dispatches THIS generic CustomTalk handler (id 23), not a QUEST-type
-- HandlerId at all - an earlier guess (a separate "Way of the Conjurer"
-- quest 22) never actually matched what the client sends. So this quest's
-- guild-visit objective is completed here, the same pattern as Miounne's
-- own CustomTalk turn-in script (RegFstCarlineCanopy_00156.lua).

-- Scenes
SCENE_00000 = 00000 -- Default greeting
SCENE_00001 = 00001 -- Regular menu asking stuff like "What do you do here?"

QUEST_CLOSE_TO_HOME = 65536 + 124
QUEST_WAY_OF_THE_CONJURER = 65536 + 22
FLAG_ATTUNE = 0
FLAG_CLASS = 1
FLAG_TRADE = 2
SEQ_ACCEPTED = 1
SEQ_READY_TO_TURN_IN = 255

function onTalk(target, player)
    local sequence = player:get_quest_sequence(QUEST_CLOSE_TO_HOME)
    print("[CloseToHome/23] onTalk sequence=" .. tostring(sequence))

    if sequence == SEQ_ACCEPTED then
        player:quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_CLASS, true)
        print("[CloseToHome/23] FLAG_CLASS set, finishing QUEST_WAY_OF_THE_CONJURER")

        -- The client independently checks whether quest 22 ("Way of the
        -- Conjurer") is genuinely completed before allowing "Close to
        -- Home" to be turned in - confirmed live: setting only quest 124's
        -- own FLAG_CLASS bit was not enough, Miounne refused to finish the
        -- quest with "You do not meet the requirements for completing this
        -- quest." Since quest 22's real combat content isn't implemented
        -- (see the stub note above), just finish it directly here to grant
        -- its real rewards and satisfy that check.
        player:finish_quest(QUEST_WAY_OF_THE_CONJURER)

        -- Opportunistically pick up the other two sub-objectives here too -
        -- every quest 124 touchpoint checks all three flags, since which
        -- NPC/handler the client dispatches for a given interaction has
        -- turned out to be unpredictable (confirmed live for Miounne).
        local attuned = player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_ATTUNE)
        if not attuned and player:has_aetheryte(2) then
            player:quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_ATTUNE, true)
            attuned = true
        end

        if attuned and player:get_quest_bit_flag(QUEST_CLOSE_TO_HOME, FLAG_TRADE) then
            player:quest_sequence(QUEST_CLOSE_TO_HOME, SEQ_READY_TO_TURN_IN)
            print("[CloseToHome/23] all 3 flags set, sequence -> SEQ_READY_TO_TURN_IN")
        end
    end

    player:play_scene(SCENE_00000, HIDE_HOTBAR, {})
end

function onReturn(scene, results, player)
    if scene == SCENE_00000 then
        player:play_scene(SCENE_00001, HIDE_HOTBAR, {})
    else
        player:finish_event()
    end
end
