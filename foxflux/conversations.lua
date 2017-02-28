local conversations = {}

local _last_index  -- avoid picking the same index twice in a row
local function _pick(list)
    local i
    if #list == 1 then
        i = 1
    elseif _last_index and _last_index <= #list then
        i = math.random(1, #list - 1)
        if i >= _last_index then
            i = i + 1
        end
    else
        i = math.random(1, #list)
    end
    _last_index = i
    return list[i]
end

-- Pick a conversation from one of the sets below, which are mostly organized
-- as form => list of conversations.  This function picks a conversation at
-- random from those available.
local function pick_conversation(name, form)
    local convos = conversations[name]
    if convos == nil then
        error(("No such conversation %s"):format(name))
    end

    convos = convos[form]
    if convos == nil or #convos == 0 then
        error(("Conversation %s has no candidates for form %s"):format(name, form))
    end

    return _pick(convos)
end


conversations.intro = {
    {
        "Gnngh.",
        "This...  isn't...  my room.",
        "Why isn't this my room.",
        "Why am I wearing my collar...?  What did I do last night?",
        "...I read a book in bed.  Hm.",
        speaker = 'lexy',
        pose = { eyes = 'tired' },
    },
    { speaker = 'lexy', pose = { body = 'compact', eyes = 'down lidded' } },
    { "Ha HA!", speaker = 'cerise', pose = { 'compact', 'villain' } },
    { "Uhh.", speaker = 'lexy' },
    {
        "Yes, it is I, your eternal nemesis!",
        "I've stolen away your sweet Cerise!",
        speaker = 'cerise',
    },
    -- FIXME eyes looking up to the left?
    { "Oh!  Please save me, Lexy!", speaker = 'cerise', pose = 'not villain' },
    {
        "Ho ho!  Not too likely!  She'd have to get through my many nefarious puzzles!  Only some kind of super cute, super puzzle genius could do that!",
        speaker = 'cerise',
        pose = 'villain',
    },
    {
        "Wha.",
        "What is happening.",
        speaker = 'lexy',
    },

    { "Aw, we thought this would be right up your alley, too.  We worked so hard on it!", speaker = 'cerise', pose = 'not villain' },
    { "I'm.  I'm tire.  What is \"this\"?", speaker = 'lexy' },
    { "Your present!  I was trying to explain.", speaker = 'cerise' },
    { "Huh?  It's not my birthday.", "I think.", speaker = 'lexy' },
    { "Do you not know what day it is?", speaker = 'cerise' },
    { "It's...  9:03.", speaker = 'lexy' },  -- FIXME use actual time?
    { "No, silly!  Well, yes.  But it's also Hearts Day!", speaker = 'cerise' },
    { "Oh.", "...", speaker = 'lexy' },
    { "OH.", speaker = 'lexy', pose = { eyes = 'down', blush = 'default' } },
    { "That's more the expression I was hoping to see!", "Now, where was I?", speaker = 'cerise' },
    { "Something about how I'm super cute.", speaker = 'lexy' },

    { "Ahem!  Yes!  I have your precious Cerise and her sweet titties in my clutches!", speaker = 'cerise', pose = 'villain' },
    { "Oh noo!", speaker = 'cerise', pose = 'not villain' },
    { "Ha HA!  Give up now!  Only a rubber fox could ever make it past my defenses!", speaker = 'cerise', pose = 'villain' },
    { "Um...  but I'm a rubber fox?", speaker = 'lexy' },
    {
        "Avast!  How did you know my only weakness?!",
        "No matter!  Just in case, I filled my PUZZLE ZONES with all manner of creatures that can mutate tender rubber into all manner of helpless shapes!",
        speaker = 'cerise',
    },
    { "DID you now.  You, uh, should've led with that.", speaker = 'lexy' },
    {
        "I sure did!  All to protect the STRAWBERRY HEARTS you'll need to unlock the boss door!",
        "But don't even think about collecting them!  You'll need a whole lot!  Better give up now!",
        speaker = 'cerise',
    },
    { "How many is a whole lot, exactly?", speaker = 'lexy' },
    { "Sixty-nine!", speaker = 'cerise' },
    { "...", "Of course.", speaker = 'lexy', pose = { 'compact sweatdrop' } },
    {
        "In summary, you don't stand a chance, little rubber fox!",
        "But feel free to dial if you need a hint.",
        "I'll be waiting for you~!",
        speaker = 'cerise',
    },
    { pose = false, speaker = 'cerise' },
    { "...", speaker = 'lexy', pose = { blush = 'default', eyes = 'down' } },
}

conversations['insufficient hearts'] = {
    rubber = {
        {{ "I don't have enough hearts yet.  I need 69.", "Hee hee.", speaker = 'lexy' }},
    },
    slime = {
        {{ "Ah, not yet!  I need some 69.", "Also, I need to find more hearts!", speaker = 'lexy' }},
    },
    glass = {
        {{ "oh", "not enough", speaker = 'lexy' }},
        {{ "i need", "i need more", speaker = 'lexy' }},
        {{ "i can't", speaker = 'lexy' }},
    },
}

conversations['need passcode'] = {
    rubber = {
        {{ "It's asking for a passcode.", speaker = 'lexy' }},
        {{ "I don't have the passcode, or the patience to bruteforce it.", speaker = 'lexy' }},
        {{ "I need a passcode.", speaker = 'lexy' }},
    },
    slime = {
        -- TODO
    },
    glass = {
        {{ "need a passcode", speaker = 'lexy' }},
        {{ "passcode is missing", speaker = 'lexy' }},
    },
}

conversations['defeat lop'] = {
    rubber = {{
        { speaker = 'lop', pose = { decor = 'letter' } },
        { "Hey, boy.  I see you got roped into this somehow.  Is that for me?", speaker = 'lexy' },
        { "Mrrf.", speaker = 'lop' },
        { speaker = 'lop', pose = { decor = false } },
        {
            "Let's see here...",
            "Unfathomable...  defeated my mounted army...  truly a worthy opponent...  waiting for you in my fortified inner lair...",
            "And there's a passcode.",
            speaker = 'lexy',
            pose = { body = 'paper', eyes = 'down' },
        },
        {
            -- FIXME this could conceivably use `set`, but i'd have to fix
            -- dialogue to use game:set_flag(), which doesn't exist outside of
            -- this game.  so maybe later
            execute = function()
                game:set_flag('has forest passcode')
            end,
        },
        {
            "Cool.  Thanks, Lop.",
            speaker = 'lexy',
            pose = { body = 'neutral', eyes = 'default' },
        },
        { "Mrurf!", speaker = 'lop' },
    }},
    -- FIXME need to...  write these
    slime = {{
        { speaker = 'lop', pose = { decor = 'letter' } },
        { "Hey, boy.  I see you got roped into this somehow.  Is that for me?", speaker = 'lexy' },
        { "Mrrf.", speaker = 'lop' },
        { speaker = 'lop', pose = { decor = false } },
        {
            "Let's see here...",
            "Unfathomable...  defeated my mounted army...  truly a worthy opponent...  waiting for you in my fortified inner lair...",
            "And there's a passcode.",
            speaker = 'lexy',
            pose = { body = 'paper', eyes = 'down' },
        },
        {
            execute = function()
                game:set_flag('has forest passcode')
            end,
        },
        {
            "Cool.  Thanks, Lop.",
            speaker = 'lexy',
            pose = { body = 'neutral', eyes = 'default' },
        },
        { "Mrurf!", speaker = 'lop' },
    }},
    glass = {{
        { speaker = 'lop', pose = { decor = 'letter' } },
        { "Hey, boy.  I see you got roped into this somehow.  Is that for me?", speaker = 'lexy' },
        { "Mrrf.", speaker = 'lop' },
        { speaker = 'lop', pose = { decor = false } },
        {
            "Let's see here...",
            "Unfathomable...  defeated my mounted army...  truly a worthy opponent...  waiting for you in my fortified inner lair...",
            "And there's a passcode.",
            speaker = 'lexy',
            pose = { body = 'paper', eyes = 'down' },
        },
        {
            execute = function()
                game:set_flag('has forest passcode')
            end,
        },
        {
            "Cool.  Thanks, Lop.",
            speaker = 'lexy',
            pose = { body = 'neutral', eyes = 'default' },
        },
        { "Mrurf!", speaker = 'lop' },
    }},
}

conversations['lop followup'] = {
    rubber = {
        {
            { "Hey, why don't you come with me?  Jumping around a lot is more your forte.", speaker = 'lexy' },
            { "Rrf murf.", speaker = 'lop' },
            { "Yeah, I figured.", speaker = 'lexy', pose = { eyes = 'lidded' } },
        },
    },
}

-- ========================================================================== --
-- Random dialogue

-- Here's how this works.
-- 1. As you play through the game, doing various things calls unlock_topic,
--    which makes some conversation (or set of conversations) available.
-- 2. When you call Cerise, if unlock_topic was called within the last N
--    seconds, the topic it unlocked is played automatically.
-- 3. Otherwise, if you called Cerise no more than M seconds ago, you won't get
--    an answer.  (So you can't just spam to see all the chitchat.)
-- 4. Otherwise, you'll get a random unlocked topic, assuming its conditions
--    are still valid.  (For example, being turned into slime unlocks a
--    conversation about slime, but it only makes sense if you are actually
--    still slime.)  You can also get one of a random set of totally generic
--    conversations.

local topical_conversations = {}
local last_topic = nil
local LAST_TOPIC_DELAY = 10
local last_dial
local DIALING_DELAY = 5  -- FIXME? this includes the time spent in the conversation itself...

local function unlock_topic(name)
    if game.progress.topics[name] then
        return
    end

    game.progress.topics[name] = true
    game.is_dirty = true
    last_topic = name
    worldscene.tick:delay(function()
        if last_topic == name then
            last_topic = nil
        end
    end, LAST_TOPIC_DELAY)
end

local function _check_conditions(convo)
    if convo.condition and not convo.condition() then
        return false
    end
    if convo.topic and not game.progress.topics[convo.topic] then
        return false
    end
    if convo.map and worldscene.map.path ~= convo.map then
        return false
    end
    if convo.form and worldscene.player.form ~= convo.form then
        return false
    end
    return true
end

local function pick_topical_conversation()
    local form = worldscene.player.form
    local now = love.timer.getTime()
    if last_dial and now - last_dial < DIALING_DELAY then
        return pick_conversation('no answer', form)
    end
    last_dial = now

    local candidates = {}
    local last_topic_candidates = {}
    for _, convo in ipairs(topical_conversations) do
        if _check_conditions(convo) then
            table.insert(candidates, convo)
            if last_topic and last_topic == convo.topic then
                table.insert(last_topic_candidates, convo)
            end
        end
    end

    if #last_topic_candidates > 0 then
        local convo = _pick(last_topic_candidates)
        return {
            { speaker = 'lexy', pose = { 'compact' } },
            { speaker = 'cerise', pose = { 'compact', 'villain' } },
            unpack(convo),
        }
    elseif #candidates > 0 then
        local convo = _pick(candidates)
        return {
            { speaker = 'lexy', pose = { 'compact' } },
            { speaker = 'cerise', pose = { 'compact', 'villain' } },
            unpack(convo),
        }
    else
        local convo = pick_conversation('no answer', form)
        return {
            { speaker = 'lexy', pose = { 'compact' } },
            { speaker = 'cerise', pose = false },
            unpack(convo),
        }
    end
end


-- FIXME cerise still appears in the no answer scripts
-- FIXME cerise isn't a villain by default; probably just need some general setup for this
conversations['no answer'] = {
    rubber = {
        {{ "There's no answer.", speaker = 'lexy' }},
        {{ "Cerise isn't answering.", speaker = 'lexy' }},
        {{ "No response.", speaker = 'lexy' }},
    },
    slime = {
        {{ "Nada!  Guess I'll have to play by myself for a while.", speaker = 'lexy' }},
    },
    glass = {
        {{ "silence", speaker = 'lexy' }},
        {{ "no one", speaker = 'lexy' }},
    },
}

-- Special conditions
local function IN_SPIKES()
    for _ in pairs(worldscene.player.in_spikes) do
        return true
    end
    return false
end


topical_conversations = {
--------------------------------------------------------------------------------
-- Transformations

    {
        -- nb: rubber doesn't need unlocking
        form = 'rubber',
        { "I can't believe you knew my sole weakness!", speaker = 'cerise' },
        { "Yes, you, uh...  fiend?  What is it, by the way?", speaker = 'lexy' },
        { "I told you!  Rubber foxes!", speaker = 'cerise' },
        { "What a curiously specific weakness!  Also didn't you put the collar on me?", speaker = 'lexy' },
        { "I did!  All part of my master plan to make you vulnerable to my PUZZLE CRITTERS!", speaker = 'cerise' },
        { "I'm getting mixed messages here.", speaker = 'lexy' },
        { "I think you're thinking about this a little too hard, hun.", speaker = 'cerise', pose = 'smiling' },
    }, {
        form = 'slime',
        topic = 'slime',
        { "Muahahaha!  How does it feel, being reduced to a glob of quivering slime?!", speaker = 'cerise' },
        { "Gooey!", speaker = 'lexy' },
        { "Yes!  Gooey and helpless!!", speaker = 'cerise' },
        { "I know!  It's great!  Like I'm barely holding together.  I bet you could sink your fingers right into me.", speaker = 'lexy' },
        { "...", "Yes!  Uh!  You should probably get back to solving puzzles!  I mean, trying to solve them, and failing, so you can taste defeat at my hands!  As quickly as possible.", speaker = 'cerise' },
        { "I will!  I'm looking forward to tasting my sweet defeat.", speaker = 'lexy' },
    }, {
        form = 'slime',
        topic = 'slime',
        { "Hey, Cerise!  Look, I'm all gooey like you!", "Well, almost.  I seem to drip a lot more.", speaker = 'lexy' },
        { "Yes!  Well!  You're slime, not gel.", speaker = 'cerise' },
        { "Oh?  What are these slimes, if they're not related to gelbeasts?", speaker = 'lexy' },
        { "They're like golems, but a bit less solid.  Totally artificial, though.", speaker = 'cerise' },
        { "Just like me!", speaker = 'lexy' },
        { "I suppose so!  Even moreso, now.", speaker = 'cerise' },
    }, {
        form = 'rubber',
        topic = 'slime revert',
        { "Hang on, why does fire turn me back from being slime?", speaker = 'lexy' },
        { "It burns the slime away, of course!", speaker = 'cerise' },
        { "That makes no sense!  I was all slime; there'd be nothing left!", speaker = 'lexy' },
        { "Look, I don't make the rules, only the puzzles!  It's just how your collar works.", speaker = 'cerise' },
        { "How do you know how my collar works?  I don't even know how my collar works.", speaker = 'lexy' },
        { "Wow, still?  I thought it was obvious.", "I don't want to spoil it, though.", speaker = 'cerise', pose = 'smiling' },
        { speaker = 'cerise', pose = 'neutral' },
        { "...come to think of it, shouldn't fire melt rubber too?", speaker = 'lexy' },
        { "Or superheat glass?", speaker = 'lexy', condition = function() return game.progress.topics['glass'] end },
        { "Ah, yes, that would make sense!  But we ran out of time.", speaker = 'cerise' },
        { "Oh.", "Wait, what?", speaker = 'lexy' },
        -- TODO should this one only play once?  maybe afterwards it should unlock some other comments about slime that would make sense generally?
    }, {
        form = 'slime',
        topic = 'slime revert',
        { "Yarr!  Transformed into mere sentient ooze!  ...Yet again!  Almost like you wanted it!", speaker = 'cerise' },
        { "I did and do!  It's quite lovely.  Like I'm my own warm, deep waterbed.", speaker = 'lexy' },
        { "So, not filling you with despair?", speaker = 'cerise' },
        { "No way!  If I could climb ladders, I'd just stay like this.", speaker = 'lexy' },
        { "Ho ho!  My delectable slime has even infected your mind!", speaker = 'cerise' },
        { "Ooh, do you think so?", speaker = 'lexy' },
        { "I'm afraid so.  You'd better hurry and get here so we can investigate this more thoroughly.", speaker = 'cerise' },
        { "Okay, I'm coming!", speaker = 'lexy' },
    }, {
        form = 'glass',
        topic = 'glass',
        { "I see you've encountered a draclear!  Natural enemy of the rubber fox!!", speaker = 'cerise' },
        { "ah", speaker = 'lexy' },
        { "Now you're totally drained of all your delectable colors, and squishiness!", speaker = 'cerise' },
        { "yes", "there's barely anything left", speaker = 'lexy' },
        { "Watch your step, or you'll lose the rest of you!", speaker = 'cerise' },
        { "oh", speaker = 'lexy' },
    }, {
        form = 'glass',
        topic = 'glass revert',
        { "Succumbed to the fearsome draclear once again!", speaker = 'cerise' },
        { "yes", speaker = 'lexy' },
        { "I...  can't tell if you're enjoying this or not!  I thought you would, but you're not even blushing.", "Unless you are, but it's transparent too?", speaker = 'cerise' },
        { "ah", "sorry", "i need", "filling", speaker = 'lexy' },
        { "I think that's a good sign!", speaker = 'cerise' },
    }, {
        form = 'rubber',
        topic = 'glass',
        { "So!  How are my fearsome draclear?!  Do they strike terror into your rubber heart?", speaker = 'cerise' },
        {
            "Actually, huh, they really are a bit more imposing when I'm like this.",
            "Remember that one that bit me a few months ago?  My ear fur was white for two days.",
            "But now they suck out...  everything?",
            "It's an interesting change in perspective, I guess.",
            speaker = 'lexy',
        },
        { "I will take that as a very complicated yes!", speaker = 'cerise' },
    }, {
        form = 'rubber',
        topic = 'glass',
        { "Hey!", speaker = 'cerise' },
        { "Hey.", speaker = 'lexy' },
        { "I don't know how to say this in character!  Now that you're a bit more talkative again, how did you like the draclear?", speaker = 'cerise' },
        { "Um...", speaker = 'lexy', pose = 'blush' },
        { "That's all I needed to know!", speaker = 'cerise', pose = 'smiling' },
    }, {
        form = 'rubber',
        topic = 'stone',
        { "What the heck was that weird chicken?!", speaker = 'lexy' },
        { "Our finest creation: the reverse cockatrice!", speaker = 'cerise' },
        { "What.", speaker = 'lexy' },
        { "Yes, the body of a cock and the head of a...  trice?  Is a trice some kind of dragon?", speaker = 'cerise' },
        { "I don't know.  Huh.  Now I'm going to be wondering about that forever.", speaker = 'lexy' },
        { "Just as planned!  Ensnared by my nerd sniping trap!", speaker = 'cerise' },
    }, {
        form = 'rubber',
        topic = 'stone',
        { "How are you liking my PUZZLE...  um, COUNTRY?  Are you quaking in fear of my overwhelming power?", speaker = 'cerise' },
        { "Oh, definitely!  I'm...  petrified.", speaker = 'lexy' },
        { "...", speaker = 'cerise' },
    }, {
        form = 'rubber',
        topic = 'stone revert',
        { "I'm just curious, but, why does a gecko revert stoning?", speaker = 'lexy' },
        {
            "Good question!  I don't know.  It's a folklore remedy from ages ago.  Who knows if it even works for real.  Good thing it worked on you!",
            "I mean, no, it's the worst!  Muahaha!",
            speaker = 'cerise',
        },
        { "You didn't know for sure?!", speaker = 'lexy' },
        { "I had a hunch!  And hey, worst case, I'd have a very cute fox statue to put in my garden.", speaker = 'cerise', pose = 'smiling' },
        { "...", speaker = 'lexy', pose = 'blush' },
        { "I haven't ruled that out yet!  Who knows, maybe I forgot to put a gecko in one of the puzzles...", speaker = 'cerise' },
        { "........................", speaker = 'lexy' },
    },


--------------------------------------------------------------------------------
-- Generic smalltalk about the levels themselves

    {
        map = 'data/maps/forest-1.tmx.json',
        topic = 'data/maps/forest-1.tmx.json',
        {
            "Welcome to the first of my diabolical PUZZLE ZONES!",
            "This one serves as a gentle introduction to my many PUZZLE ELEMENTS!  Like... jumping!  And, well, mostly just jumping.",
            speaker = 'cerise',
        },
        { "Hmm.  Aren't you trying to stop me from getting there?  Why would you give me a gentle introduction?", speaker = 'lexy' },
        { "I may be evil, but I'm still fair!", speaker = 'cerise' },
    }, {
        map = 'data/maps/forest-2.tmx.json',
        topic = 'data/maps/forest-2.tmx.json',
        form = 'rubber',
        {
            "Ah, you've arrived at my discombobulating SLIME ZONE!",
            "Beware the slimes, which seek to consume you whole!  Definitely don't let them do that, since it'll help you progress!",
            speaker = 'cerise',
        },
        { "Hmm.  Aren't you trying to stop me from getting there?  Why would you give me a gentle introduction?", speaker = 'lexy' },
        { "I may be evil, but I'm still fair!", speaker = 'cerise' },
    }, {
        map = 'data/maps/forest-2.tmx.json',
        topic = 'data/maps/forest-2.tmx.json',
        form = 'slime',
        {
            "I see you've encountered some of my pet slimes, in my SLIME ZONE!",
            "I hope they enjoyed feasting on your bones!",
            "Hmm, do you even have bones with the collar on?",
            speaker = 'cerise',
        },
        { "I don't know, but I sure don't now!  I just have bright green slime and dark green slime.", speaker = 'lexy' },
        { "I can see that!  You look like you need someone to give you a good stir.", speaker = 'cerise' },
        { "That sounds nice!  Maybe we could try stirring some pink in too.", speaker = 'cerise' },
    }, {
        map = 'data/maps/forest-3.tmx.json',
        topic = 'data/maps/forest-3.tmx.json',
        form = 'rubber',
        {
            "Beware, all ye who enter my GLASS ZONE!",
            "Can you make it to the very bottom without being captured by one of the many draclear?!  Probably!",
            speaker = 'cerise',
        },
        { "You're really selling this.", speaker = 'lexy' },
        { "Shush!", speaker = 'cerise' },
    }, {
        map = 'data/maps/forest-4.tmx.json',
        topic = 'data/maps/forest-4.tmx.json',
        form = 'rubber',
        { "Welcome, to the STONE ZONE!", speaker = 'cerise' },
        { "Did you just say \"bone zone\"?", speaker = 'lexy' },
        { "What!  No!  I said STONE ZONE!  What sort of smutty obstacle course do you think this is?!", speaker = 'cerise' },
        { "Uhh...", speaker = 'lexy', pose = 'sweatdrop' },
    }, {
        map = 'data/maps/forest-4.tmx.json',
        topic = 'data/maps/forest-4.tmx.json',
        form = 'rubber',
        { "Behold, my STONE ZONE!  Home to evil creatures", speaker = 'cerise' },
        { "Did you just say \"bone zone\"?", speaker = 'lexy' },
        { "What!  No!  I said STONE ZONE!  What sort of smutty obstacle course do you think this is?!", speaker = 'cerise' },
        { "Uhh...", speaker = 'lexy', pose = 'sweatdrop' },
    }, {
        map = 'data/maps/tech-overworld.tmx.json',
        form = 'rubber',
        { "Hey, what's this force field in the lower right?", speaker = 'lexy' },
        { "Don't worry about that!  Some construction leftovers.  Pardon our progress and all.", speaker = 'cerise' },
        { "Hmm...", speaker = 'lexy' },
    },


--------------------------------------------------------------------------------
-- Puzzle elements

    {
        -- TODO should this have different versions for different forms, argh
        condition = IN_SPIKES,
        form = 'rubber',
        topic = 'spikes',
        { "Ha HA!  Now you're trapped, impaled on my deadly spikes!", speaker = 'cerise' },
        { "Oh noo!", "...", "Wait, DEADLY?", speaker = 'lexy' },
        { "Yes?  They're sharp spikes.  I can see them sticking out of you right now.", speaker = 'cerise' },
        { "Isn't...  this...  extremely dangerous?", speaker = 'lexy' },
        { "That's why you're wearing the collar, hun.  I wouldn't recommend flinging your fluffy self down a twenty-foot drop, either.", speaker = 'cerise', pose = 'smiling' },
        { "I...  suppose so...", speaker = 'lexy', pose = { blush = 'default' } },
    }, {
        topic = 'spring',
        form = 'rubber',
        { "I see my ultimate trap has finally...  SPRUNG!", speaker = 'cerise' },
        { "........", "I'm hanging up on you now.", speaker = 'lexy' },
    },


--------------------------------------------------------------------------------
-- Other smalltalk

    {
        form = 'rubber',
        { "I can't believe how elaborate this is.  How did you manage to build all this?", speaker = 'lexy' },
        {
            "Well, as a supervillainess, I have infinite resources.",
            "Also, Robin helped with most of the heavy lifting.",
            speaker = 'cerise',
        },
        { "Ha!", "Still, this place is huge.  Where are we, anyway?", speaker = 'lexy' },
        { "Um...  That's...  a very complicated question.", speaker = 'cerise' },
        { "Isaac's in on it too, then.", speaker = 'lexy', pose = { 'compact sweatdrop' } },
        { "Arrgh!  You've even solved my lizard wizard puzzle!", speaker = 'cerise' },
        { "Mm.  Are either of them...  playing along?", speaker = 'lexy' },
        { "Unfortunately, no.  We didn't have time to finish their costumes.", speaker = 'cerise' },
        -- FIXME should be silent
        { "..............", speaker = 'lexy' },
    }, {
        form = 'rubber',
        { "Hey.", speaker = 'lexy' },
        { "Buahaha!  Hello.", speaker = 'cerise' },
        { "I know I'm kind of nitpicky and all, but...", speaker = 'lexy' },
        -- TODO look up and away?
        { "Well...", "You know...", speaker = 'lexy', pose = { 'blush' } },
        { "Spit it out, dastardly heroine!  I must get back to torturing your cute girlfriend!", speaker = 'cerise' },
        { "UGH.", "Thanks.  For this.  It's cute.  I like it.", speaker = 'lexy' },
        { "Oh!  That's just like how I feel about you!", speaker = 'cerise', pose = { eyes = 'smiling' } },
        { speaker = 'lexy', pose = 'blush' },
        { "Now tremble before my might as I crush you with sexy puzzles!", speaker = 'cerise', pose = { eyes = 'default' } },
        { "Ahh!  I will!", speaker = 'lexy' },
    }, {
        form = 'rubber',
        { "You know what's my favorite thing?  Just absolute favorite.  Gets me right in the mood.", speaker = 'lexy' },
        { "Hmmmmm.  Threatened loss of bodily autonomy?", speaker = 'cerise' },
        { "AHEM.", speaker = 'lexy', pose = 'blush' },
        { "Physical exertion.  Running and jumping and climbing stuff.  Can't get enough of it.  My knees are jelly already.", speaker = 'lexy', pose = 'no blush' },
        { "Ha!  Your pleas for mercy fall upon deaf ears!  ALL of me is jelly, and I had to build it in the first place!", speaker = 'cerise' },
        { "That's...  not...  hmm.", speaker = 'lexy' },
    },

    {
        form = 'slime',
        { "Hey, Cerise!  How long is all this, anyway?", speaker = 'lexy' },
        { "Not that long!  Or, um, EXTREMELY LONG, because it's very impossible, and so on.", speaker = 'cerise' },
        { "I'd better pick up the pace, then!  I miss you.", speaker = 'lexy' },
        { "Aw, you're talking to me right now!", speaker = 'cerise' },
        { "Yeah, but I want to spend Hearts Day with you, not just talking on the compact!", speaker = 'lexy' },
        { "Well!  Hurry and come save me then!", speaker = 'cerise', pose = { 'not villain', 'smiling' } },
    },
}


return {
    pick_conversation = pick_conversation,
    unlock_topic = unlock_topic,
    pick_topical_conversation = pick_topical_conversation,
}
