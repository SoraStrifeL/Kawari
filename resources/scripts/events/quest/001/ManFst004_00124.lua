-- Quest: Close to Home (Gridania), for Conjurers
--
-- State machine ported from the real retail server-emulator reference
-- (SapphireServer/Sapphire, src/scripts/quest/mainquest/gridania/ManFst004.cpp),
-- cross-checked against this quest's own Excel row (65660).
--
-- Live-confirmed finding #1: Madelle and Parsemontret's interactions for
-- this quest do NOT dispatch through this script's own onTalk at all, even
-- though Quest.csv lists them as this quest's ACTOR2/ACTOR3 - talking to
-- them instead dispatches entirely separate quests (HandlerId{CUSTOM_TALK,23}
-- for Madelle, HandlerId{QUEST,38} for Parsemontret; see
-- RegFstCnjGuild_00023.lua and SubFst012_00038.lua). Those two scripts flip
-- this quest's bit flags directly on their own completion. Same story for
-- the aetheryte attunement, which routes through the shared
-- HandlerType::Aetheryte handler (events/generic/Aetheryte.lua), not here.
--
-- Live-confirmed finding #2: Miounne's own actor object_id is NOT stable -
-- Kawari assigns every map NPC a random id at zone-instance creation
-- (servers/world/src/server/instance.rs: `ObjectId(fastrand::u32(..))`), so
-- a hardcoded id here only ever matches until the next zone instance is
-- created (server restart, or just a fresh instance). Since HandlerId{QUEST,
-- 124}'s onTalk can only ever be triggered by interacting with Miounne
-- (that's what the client's own quest-linking data guarantees), matching
-- target.object_id isn't needed at all - any onTalk call for this
-- HandlerId IS Miounne, unconditionally.
--
-- IMPORTANT: `sequence` must stay one of exactly these three values - the
-- client's own quest data only understands specific predefined steps for
-- it, so anything else (we originally tried packing extra bits into it)
-- silently breaks the quest journal on a fresh load (confirmed live: it
-- worked mid-session but the quest vanished after a relog). The three
-- parallel sub-objectives (attune/guild/market, completable in any order)
-- are tracked via the quest's bit flags instead (quest_bit_flag/
-- get_quest_bit_flag), which the client does NOT need to recognize any
-- particular value for.
SEQ_NOT_ACCEPTED = 0
SEQ_ACCEPTED = 1
SEQ_READY_TO_TURN_IN = 255

FLAG_ATTUNE = 0
FLAG_CLASS = 1
FLAG_TRADE = 2

-- Quest-interaction log: one line per onTalk/onReturn, showing the current
-- sequence and all 3 sub-objective flags. Cheap and permanent (unlike the
-- one-off diagnostic prints used earlier this session) - meant to make
-- future debugging of this quest's flow-through-multiple-scripts design
-- possible without re-adding ad-hoc prints each time.
function log_state(where, player)
    print("[CloseToHome/124] " .. where
        .. " sequence=" .. tostring(player:get_quest_sequence(EVENT_ID))
        .. " attune=" .. tostring(player:get_quest_bit_flag(EVENT_ID, FLAG_ATTUNE))
        .. " class=" .. tostring(player:get_quest_bit_flag(EVENT_ID, FLAG_CLASS))
        .. " trade=" .. tostring(player:get_quest_bit_flag(EVENT_ID, FLAG_TRADE)))
end

function onTalk(target, player)
    local sequence = player:get_quest_sequence(EVENT_ID)
    log_state("onTalk", player)

    if sequence == SEQ_NOT_ACCEPTED then
        player:play_scene(0, HIDE_HOTBAR, {})
        return
    end

    if sequence ~= SEQ_READY_TO_TURN_IN then
        -- Opportunistically pick up the aetheryte sub-objective here,
        -- since attuning itself happens through the shared Aetheryte.lua
        -- handler (deliberately left untouched after an earlier change
        -- there broke attunement for every aetheryte in the game, not
        -- just this quest's).
        local attuned = player:get_quest_bit_flag(EVENT_ID, FLAG_ATTUNE)
        if not attuned and player:has_aetheryte(2) then
            player:quest_bit_flag(EVENT_ID, FLAG_ATTUNE, true)
            attuned = true
            print("[CloseToHome/124] onTalk picked up FLAG_ATTUNE from has_aetheryte(2)")
        end

        if attuned
            and player:get_quest_bit_flag(EVENT_ID, FLAG_CLASS)
            and player:get_quest_bit_flag(EVENT_ID, FLAG_TRADE) then
            player:quest_sequence(EVENT_ID, SEQ_READY_TO_TURN_IN)
            sequence = SEQ_READY_TO_TURN_IN
            print("[CloseToHome/124] onTalk all 3 flags set, sequence -> SEQ_READY_TO_TURN_IN")
        end
    end

    if sequence == SEQ_READY_TO_TURN_IN then
        -- Play the actual turn-in scene/dialogue (matching Sapphire's
        -- reference Scene5, FADE_OUT|CONDITION_CUTSCENE|HIDE_UI) instead of
        -- silently calling finish_quest() with no prompt at all - confirmed
        -- live that skipping this played no dialogue and just completed the
        -- quest with no visible confirmation.
        player:play_scene(5, HIDE_HOTBAR, {})
        return
    end

    player:send_message("Finish your other tasks first, then come back and see me.", 0)
    player:finish_event()
end

function onReturn(scene, results, player)
    print("[CloseToHome/124] onReturn scene=" .. tostring(scene) .. " results[1]=" .. tostring(results[1]))

    if scene == 50 then
        -- Accept the quest, this also matches up with the client-side UI
        player:accept_quest(EVENT_ID)
        player:quest_sequence(EVENT_ID, SEQ_ACCEPTED)

        local old_position = player.position
        local old_rotation = player.rotation

        -- Just like in retail, "seamlessly" transition them to the real zone:
        player:change_territory(TERRITORYTYPE0, { x = old_position.x, y = old_position.y, z = old_position.z }, old_rotation)
        -- Note: upstream added a "you reached the end of this quest, it won't
        -- advance any further" warning here (commit 624a6b44) - deliberately
        -- NOT carried over, since this quest genuinely does advance further
        -- now (see scene == 5 below and the rest of this file).
    elseif scene == 5 then
        if results[1] == 1 then
            player:finish_quest(EVENT_ID)
        end
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
