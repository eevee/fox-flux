local conversations = {}

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
    { "...", "Of course.", speaker = 'lexy', pose = { blush = false, sweat = 'default', eyes = 'down lidded' } },
    {
        "In summary, you don't stand a chance, little rubber fox!",
        "But feel free to dial if you need a hint.",
        "I'll be waiting for you~!",
        speaker = 'cerise',
    },
    { pose = false, speaker = 'cerise' },
    { "...", speaker = 'lexy', pose = { blush = 'default', eyes = 'down' } },
}

conversations.insufficient_hearts = {
    rubber = {
        {
            {
                "I don't have enough hearts yet.  I need 69.",
                "Hee hee.",  -- TODO expression?
                speaker = 'lexy',
            },
        },
    },
    slime = {
        {
            {
                speaker = 'lexy',
                "Ah, not yet!  I need some 69.",
                "Also, I need to find more hearts!",
            },
        }, {
            {
                speaker = 'lexy',
                "Ah, not yet!  I need some 69.",
                "Also, I need to find more hearts!",
            },
        },
    },
    glass = {
        {{ "oh", "not enough", speaker = 'lexy' }},
        {{ "i need", "i need more", speaker = 'lexy' }},
        {{ "i can't", speaker = 'lexy' }},
    },
}

conversations.need_passcode = {
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

conversations.defeat_lop = {
    rubber = {
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
    },
    -- FIXME need to...  write these
    slime = {
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
    },
    glass = {
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
    },
}

conversations.followup_lop = {
    rubber = {
        {
            { "Hey, why don't you come with me?  Jumping around a lot is more your forte.", speaker = 'lexy' },
            { "Rrf murf.", speaker = 'lop' },
            { "Yeah, I figured.", speaker = 'lexy', pose = { eyes = 'lidded' } },
        },
    },
}

conversations.random = {
    cherry_hearts = {
        -- TODO
        { "", speaker = 'lexy' },
    },
    -- how did you build all this
    -- dry joke about jumping around not being sexy
}

return conversations
