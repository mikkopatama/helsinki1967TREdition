-- Helsinki 1967 Tube-Ribbon Edition - Floe sample library
-- Copyright Mikko Patama 2026
--
-- Converted from the DecentSampler "Tube-Ribbon Full" preset (v1.1).
-- Mapping data lives in Lua/mapping.lua; this file turns it into instruments.
--
-- Floe has no per-group mixer inside an instrument. The mixer of the
-- DecentSampler version is rebuilt from Floe's 3 layers instead: each microphone
-- is its own instrument, so the layer volume knobs are the mic faders.

floe.set_required_floe_version("2.0.3")

--------------------------------------------------------------------------------
-- Settings
--------------------------------------------------------------------------------

-- Level of the release and hammer samples when they are built into a piano
-- instrument. -14 dB equals the DecentSampler default knob position (0.20).
-- The instruments in the "Noises" folder are left at 0 dB (knob at 1.0) so
-- that the layer volume sets their level.
local RELEASE_GAIN_DB = -14
local HAMMER_GAIN_DB = -14

local SAMPLES = "Samples/"
local TUBE = "CV" -- mono tube condenser (modified CV-12)
local RIBBON = "RB" -- stereo Blumlein ribbon pair

--------------------------------------------------------------------------------
-- Library
--------------------------------------------------------------------------------

local library = floe.new_library({
    name = "Helsinki 1967 Tube-Ribbon Edition",
    tagline = "Finnish upright piano from 1967, tube and ribbon microphones",
    author = "Mikko Patama",
    author_url = "https://www.mikkopatama.com",
    description = "An upright piano built in Nurmijärvi, Finland in 1967 (Helsinki No 9962, Renner action), "
        .. "sampled with a custom modified CV-12 tube condenser and a stereo Blumlein ribbon pair.\n"
        .. "35 sampled keys, 5 velocity layers, 2 round robins, plus release and hammer samples.\n"
        .. "Load Tube and Ribbon into separate layers and balance the microphones with the layer volumes.",
    revision = 1,
    background_image_path = "Images/background.jpg", -- alternative: "Images/walnut.png"
    icon_image_path = "Images/icon.png",
    background_overlay = {
        vignette = {
            colour = 0x00000099,
            inner_radius = 0.2,
        },
        panel_tint = {
            colour = 0x0000004D,
        },
    },
})

--------------------------------------------------------------------------------
-- Mapping
--------------------------------------------------------------------------------

local mapping = dofile("Lua/mapping.lua")

-- DecentSampler key ranges are inclusive, Floe's end is exclusive.
local function key_range(low, high)
    return { low, high + 1 }
end

-- Sustain samples of one microphone: 5 velocity layers, 2 round robins.
-- Volume comes from the recorded velocity layers alone, as in the original.
local function add_sustain(instrument, mic)
    for _, s in ipairs(mapping.sustain) do
        local name, root, low, high, low_vel, high_vel, rr = table.unpack(s)
        local trigger = {
            trigger_event = "note-on",
            key_range = key_range(low, high),
            velocity_range_high_resolution = floe.midi_range_to_thousand_range({ low_vel, high_vel }),
        }
        -- Layers recorded with a single take have no round_robin_index, so
        -- they play on every key press.
        if rr > 0 then
            trigger.round_robin_index = rr - 1
        end
        floe.add_region(instrument, {
            path = SAMPLES .. name .. mic .. ".flac",
            root_key = root,
            trigger_criteria = trigger,
            loop = { loop_requirement = "never-loop" },
        })
    end
end

-- Samples played when a key is released. In Floe these are one-shots: no
-- volume envelope, no loop, played to the end.
local function add_note_off(instrument, path, root, low, high, gain_db)
    floe.add_region(instrument, {
        path = path,
        root_key = root,
        trigger_criteria = {
            trigger_event = "note-off",
            key_range = key_range(low, high),
        },
        loop = { loop_requirement = "never-loop" },
        audio_properties = { gain_db = gain_db },
    })
end

local function add_release(instrument, mic, gain_db)
    for _, s in ipairs(mapping.release) do
        local name, root, low, high = table.unpack(s)
        add_note_off(instrument, SAMPLES .. name .. mic .. ".flac", root, low, high, gain_db)
    end
end

local function add_hammer(instrument, gain_db)
    for _, s in ipairs(mapping.hammer) do
        local name, root, low, high = table.unpack(s)
        add_note_off(instrument, SAMPLES .. name .. ".flac", root, low, high, gain_db)
    end
end

--------------------------------------------------------------------------------
-- Instruments
--------------------------------------------------------------------------------

local PIANO_TAGS = { "acoustic", "piano", "keys", "struck strings", "solo", "studio", "warm", "nostalgic", "jazz", "pop" }
local NOISE_TAGS = { "acoustic", "piano", "noise" }
local TUBE_WAVEFORM = SAMPLES .. "C3_C3-C#3_71-99_RR01CV.flac"
local RIBBON_WAVEFORM = SAMPLES .. "C3_C3-C#3_71-99_RR01RB.flac"

-- Complete instruments: one layer per microphone, release noises included.

local tube = floe.new_instrument(library, {
    name = "Tube",
    folder = "Piano",
    description = "Mono tube condenser microphone with its release samples.",
    tags = PIANO_TAGS,
    waveform_audio_path = TUBE_WAVEFORM,
})
add_sustain(tube, TUBE)
add_release(tube, TUBE, RELEASE_GAIN_DB)

local ribbon = floe.new_instrument(library, {
    name = "Ribbon",
    folder = "Piano",
    description = "Stereo Blumlein ribbon microphones with their release and hammer samples.",
    tags = PIANO_TAGS,
    waveform_audio_path = RIBBON_WAVEFORM,
})
add_sustain(ribbon, RIBBON)
add_release(ribbon, RIBBON, RELEASE_GAIN_DB)
add_hammer(ribbon, HAMMER_GAIN_DB)

-- Sustain only: combine with an instrument from the Noises folder in the third
-- layer to set the release level independently of the microphones.

local tube_sustain = floe.new_instrument(library, {
    name = "Tube - Sustain Only",
    folder = "Piano",
    description = "Mono tube condenser microphone without release samples.",
    tags = PIANO_TAGS,
    waveform_audio_path = TUBE_WAVEFORM,
})
add_sustain(tube_sustain, TUBE)

local ribbon_sustain = floe.new_instrument(library, {
    name = "Ribbon - Sustain Only",
    folder = "Piano",
    description = "Stereo Blumlein ribbon microphones without release or hammer samples.",
    tags = PIANO_TAGS,
    waveform_audio_path = RIBBON_WAVEFORM,
})
add_sustain(ribbon_sustain, RIBBON)

-- Noises: these only sound when a key is released.

local release_hammer = floe.new_instrument(library, {
    name = "Release + Hammer",
    folder = "Noises",
    description = "Release samples of both microphones and hammer noise, played on key release.",
    tags = NOISE_TAGS,
    waveform_audio_path = SAMPLES .. "C3_C3-C#3_0-127_RELRB.flac",
})
add_release(release_hammer, TUBE, 0)
add_release(release_hammer, RIBBON, 0)
add_hammer(release_hammer, 0)

local release_tube = floe.new_instrument(library, {
    name = "Release - Tube",
    folder = "Noises",
    description = "Release samples of the tube microphone, played on key release.",
    tags = NOISE_TAGS,
    waveform_audio_path = SAMPLES .. "C3_C3-C#3_0-127_RELCV.flac",
})
add_release(release_tube, TUBE, 0)

local release_ribbon = floe.new_instrument(library, {
    name = "Release - Ribbon",
    folder = "Noises",
    description = "Release samples of the ribbon microphones, played on key release.",
    tags = NOISE_TAGS,
    waveform_audio_path = SAMPLES .. "C3_C3-C#3_0-127_RELRB.flac",
})
add_release(release_ribbon, RIBBON, 0)

local hammer = floe.new_instrument(library, {
    name = "Hammer",
    folder = "Noises",
    description = "Hammer noise of the ribbon microphones, played on key release.",
    tags = NOISE_TAGS,
    waveform_audio_path = SAMPLES .. "C3_C3-C#3_0-127_HAMMERRB.flac",
})
add_hammer(hammer, 0)

--------------------------------------------------------------------------------
-- Reverb impulse responses (same set as the DecentSampler version)
--------------------------------------------------------------------------------

local IR = SAMPLES .. "IR/"

floe.add_ir(library, { name = "Lady Chapel", path = IR .. "stalbans.flac", tags = { "acoustic", "church" } })
floe.add_ir(library, { name = "Plate", path = IR .. "Plate.flac" })
floe.add_ir(library, { name = "Small Room", path = IR .. "Small Room.flac", tags = { "acoustic", "small room" } })
floe.add_ir(library, { name = "Medium Room", path = IR .. "Medium Room.flac", tags = { "acoustic" } })
floe.add_ir(library, { name = "Large Room", path = IR .. "Large Room.flac", tags = { "acoustic", "large room" } })
floe.add_ir(library, { name = "Grandmother Spring", path = IR .. "Grandmother.flac" })

return library
