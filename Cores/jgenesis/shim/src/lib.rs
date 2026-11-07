//! JGenesis behind GagaEmu's bridge. `JgenesisCore.c` holds the `GagaCoreInterface` table and calls these
//! `jg_*` functions, so the C compiler checks the table against `GagaBridge.h`; the structs below mirror it.
//! Every call runs on the host's serial queue and every callback fires inside one. Panics in upstream code
//! are caught here and become a FATAL event or a refused call, never an unwind into C.

use bincode::error::DecodeError;
use cdrom::reader::{CdRom, CdRomFileFormat};
use genesis_components::cartridge::Cartridge;
use genesis_config::cheats::GenesisCheatCodeType;
use genesis_config::{GenesisButton, GenesisController, GenesisControllerType, GenesisEmulatorConfig, GenesisInputs, GenesisRegion};
use genesis_core::GenesisEmulator;
use genesis_core::api::GenesisHardware;
use jgenesis_common::frontend::{
    AudioOutput, Color, ConstantInputPoller, EmulatorTrait, FrameSize, MappableInputs, RenderFrameOptions, Renderer,
    SaveWriter, TickEffect,
};
use jgenesis_common::input::Player;
use std::collections::HashMap;
use std::convert::Infallible;
use std::ffi::{CStr, c_char, c_void};
use std::fs::{self, File};
use std::io::{self, Write};
use std::panic::{AssertUnwindSafe, catch_unwind};
use std::path::{Path, PathBuf};

const SAMPLE_RATE: u32 = 48000;
const FLUSH_FRAMES: u32 = 300; // About 5 seconds: the most a crash can lose.
const MAX_ROM_BYTES: u64 = 16 << 20; // The largest mapped cartridges are 10 MB.
/// The version string upstream puts in its own state files. `self_test` fails if a new pin changes it.
const UPSTREAM_STATE_VERSION: &str = "0.14.0-1";
/// `state_version` in the interface table, from `UPSTREAM_STATE_VERSION`: 0.14.0, revision 1.
pub const STATE_VERSION: u32 = 0x000E_0001;
const STATE_MAGIC: &[u8; 4] = b"JGS1";
const STATE_HEADER: usize = 16; // Magic, STATE_VERSION, ROM hash.

const EVENT_FATAL: i32 = 2;
const EVENT_BAD_ROM: i32 = 1;
const EVENT_BAD_SAVE: i32 = 2;
const EVENT_STOPPED: i32 = 3;
const EVENT_NO_BIOS: i32 = 4;

// MARK: - GagaBridge.h mirrors

#[repr(C)]
pub struct GagaInputState {
    buttons: u32,
    left_x: i16,
    left_y: i16,
    right_x: i16,
    right_y: i16,
    trigger_l: f32,
    trigger_r: f32,
    accel_x: f32,
    accel_y: f32,
    accel_z: f32,
    pointer_x: i16,
    pointer_y: i16,
    pointer_down: bool,
}

#[repr(C)]
pub struct GagaFrameDescriptor {
    pixel_data: *const c_void,
    width: u32,
    height: u32,
    pitch: usize,
    pixel_format: u32,
}

#[repr(C)]
pub struct GagaAudioDescriptor {
    pcm_samples: *const i16,
    frames: usize,
    sample_rate: u32,
    channels: u8,
}

type VideoCallback = Option<unsafe extern "C" fn(*const GagaFrameDescriptor, *mut c_void)>;
type AudioCallback = Option<unsafe extern "C" fn(*const GagaAudioDescriptor, *mut c_void)>;
type EventCallback = Option<unsafe extern "C" fn(i32, i32, *const c_char, *mut c_void)>;

const BTN_UP: u32 = 1 << 0;
const BTN_DOWN: u32 = 1 << 1;
const BTN_LEFT: u32 = 1 << 2;
const BTN_RIGHT: u32 = 1 << 3;
const BTN_SOUTH: u32 = 1 << 4;
const BTN_EAST: u32 = 1 << 5;
const BTN_WEST: u32 = 1 << 6;
const BTN_NORTH: u32 = 1 << 7;
const BTN_L1: u32 = 1 << 8;
const BTN_R1: u32 = 1 << 9;
const BTN_START: u32 = 1 << 12;
const BTN_SELECT: u32 = 1 << 13;
const PIXEL_FORMAT_RGBA8888: u32 = 2;

/// The six-button pad by position, as libretro's Genesis cores lay it out: the bottom row A B C is the
/// controller's west, south and east buttons, the top row X Y Z is L1, north and R1, and Select is Mode.
const BUTTONS: [(u32, GenesisButton); 12] = [
    (BTN_UP, GenesisButton::Up),
    (BTN_DOWN, GenesisButton::Down),
    (BTN_LEFT, GenesisButton::Left),
    (BTN_RIGHT, GenesisButton::Right),
    (BTN_WEST, GenesisButton::A),
    (BTN_SOUTH, GenesisButton::B),
    (BTN_EAST, GenesisButton::C),
    (BTN_START, GenesisButton::Start),
    (BTN_L1, GenesisButton::X),
    (BTN_NORTH, GenesisButton::Y),
    (BTN_R1, GenesisButton::Z),
    (BTN_SELECT, GenesisButton::Mode),
];

// MARK: - Frontend pieces upstream calls back into

#[derive(Default)]
struct Video {
    pixels: Vec<u8>,
    width: u32,
    height: u32,
    fresh: bool,
}

impl Renderer for Video {
    type Err = Infallible;

    fn render_frame(&mut self, frame: &[Color], size: FrameSize, _fps: f64, _options: RenderFrameOptions) -> Result<(), Infallible> {
        self.pixels.clear();
        for color in &frame[..size.len() as usize] {
            self.pixels.extend_from_slice(&[color.r, color.g, color.b, 0xFF]);
        }
        (self.width, self.height, self.fresh) = (size.width, size.height, true);
        Ok(())
    }
}

#[derive(Default)]
struct Audio(Vec<i16>);

impl AudioOutput for Audio {
    type Err = Infallible;

    fn push_sample(&mut self, left: f64, right: f64) -> Result<(), Infallible> {
        let pcm = |sample: f64| (sample * 32767.0).round().clamp(-32768.0, 32767.0) as i16;
        self.0.extend_from_slice(&[pcm(left), pcm(right)]);
        Ok(())
    }
}

/// Battery memory by extension (`sav`, and `bram` and `ramc` for Mega-CD). Upstream hands over the bytes
/// whenever they change; they reach `<save_dir>/<rom stem>.<extension>` only on `flush`.
struct Saves {
    dir: PathBuf,
    stem: String,
    latest: HashMap<String, Vec<u8>>,
    written: HashMap<String, Vec<u8>>,
}

impl Saves {
    fn path(&self, extension: &str) -> PathBuf {
        self.dir.join(format!("{}.{extension}", self.stem))
    }

    /// Writes what changed since the last flush. False if any file failed; it is tried again next time.
    fn flush(&mut self) -> bool {
        let mut ok = true;
        for (extension, bytes) in &self.latest {
            if self.written.get(extension) == Some(bytes) {
                continue;
            }
            if write_file(&self.path(extension), bytes).is_ok() {
                self.written.insert(extension.clone(), bytes.clone());
            } else {
                ok = false;
            }
        }
        ok
    }
}

impl SaveWriter for Saves {
    type Err = io::Error;

    fn load_bytes(&mut self, extension: &str) -> io::Result<Vec<u8>> {
        // A hard reset reads the save again, and must get what the game wrote since the last flush.
        match self.latest.get(extension) {
            Some(bytes) => Ok(bytes.clone()),
            None => fs::read(self.path(extension)),
        }
    }

    fn persist_bytes(&mut self, extension: &str, bytes: &[u8]) -> io::Result<()> {
        let slot = self.latest.entry(extension.to_owned()).or_default();
        slot.clear();
        slot.extend_from_slice(bytes);
        Ok(())
    }

    // The Genesis and Mega-CD save only raw bytes.
    fn load_serialized<D: bincode::Decode<()>>(&mut self, _extension: &str) -> io::Result<D> {
        Err(io::Error::other("not used by this core"))
    }

    fn persist_serialized<E: bincode::Encode>(&mut self, _extension: &str, _data: E) -> io::Result<()> {
        Err(io::Error::other("not used by this core"))
    }
}

/// Temp file, fsync, rename: a crash leaves the old save or the new one, never half of one.
fn write_file(path: &Path, bytes: &[u8]) -> io::Result<()> {
    let mut temp = path.as_os_str().to_owned();
    temp.push(".tmp");
    let temp = PathBuf::from(temp);
    let result = (|| {
        let mut file = File::create(&temp)?;
        file.write_all(bytes)?;
        file.sync_all()?;
        fs::rename(&temp, path)
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temp);
    }
    result
}

/// FNV-1a, for telling ROMs apart, not for security: the host's checksum covers damage to the state file.
fn hash(bytes: &[u8]) -> u64 {
    bytes.iter().fold(0xcbf2_9ce4_8422_2325, |hash, &byte| (hash ^ u64::from(byte)).wrapping_mul(0x100_0000_01b3))
}

fn bincode_config() -> impl bincode::config::Config {
    // Upstream's own state-file settings (jgenesis-native-driver), so a state is the same bytes as theirs.
    bincode::config::standard().with_little_endian().with_fixed_int_encoding().with_limit::<{ 100 * 1024 * 1024 }>()
}

// MARK: - Instance

struct Cheat {
    id: u32,
    enabled: bool,
    codes: Vec<(u32, u16)>,
}

pub struct Instance {
    system_dir: PathBuf,
    save_dir: PathBuf,
    emulator: Option<GenesisEmulator>,
    stopped: bool,
    config: GenesisEmulatorConfig,
    inputs: GenesisInputs,
    saves: Option<Saves>,
    save_failed: bool,
    rom_hash: u64,
    frames_since_flush: u32,
    cheats: Vec<Cheat>,
    video: Video,
    audio: Audio,
    video_cb: VideoCallback,
    video_userdata: *mut c_void,
    audio_cb: AudioCallback,
    audio_userdata: *mut c_void,
    event_cb: EventCallback,
    event_userdata: *mut c_void,
}

impl Instance {
    fn emit(&self, severity: i32, code: i32, message: &str) {
        let Some(cb) = self.event_cb else { return };
        let text: Vec<u8> = message.bytes().filter(|&b| b != 0).chain([0]).collect();
        // SAFETY: the host's callback, on its queue; the message lives through the call.
        unsafe { cb(severity, code, text.as_ptr().cast(), self.event_userdata) };
    }

    fn fatal(&self, code: i32, message: &str) {
        self.emit(EVENT_FATAL, code, message);
    }

    fn flush(&mut self) {
        let Some(saves) = &mut self.saves else { return };
        // The player learns once that progress is not reaching storage. Every later flush still tries.
        if !saves.flush() && !self.save_failed {
            self.save_failed = true;
            self.fatal(EVENT_BAD_SAVE, "The save file for this game could not be written.");
        }
    }

    fn apply_cheats(&mut self) {
        self.config.cheat_codes = self.cheats.iter().filter(|c| c.enabled).flat_map(|c| c.codes.iter().copied()).collect();
        if let Some(emulator) = &mut self.emulator {
            emulator.reload_config(&self.config);
        }
    }

    fn load(&mut self, path: &Path) -> bool {
        let stem = path.file_stem().map(|s| s.to_string_lossy().into_owned()).unwrap_or_default();
        let mut saves = Saves { dir: self.save_dir.clone(), stem, latest: HashMap::new(), written: HashMap::new() };
        let created = match CdRomFileFormat::from_file_path(path) {
            Some(format) => self.load_disc(path, format, &mut saves),
            None => self.load_cartridge(path, &mut saves),
        };
        let Some(mut emulator) = created else { return false };
        emulator.update_audio_output_frequency(SAMPLE_RATE.into());
        self.emulator = Some(emulator);
        self.saves = Some(saves);
        true
    }

    fn load_cartridge(&mut self, path: &Path, saves: &mut Saves) -> Option<GenesisEmulator> {
        let Ok(length) = fs::metadata(path).map(|m| m.len()) else {
            self.fatal(EVENT_BAD_ROM, "The game file could not be opened.");
            return None;
        };
        let rom = if length <= MAX_ROM_BYTES { fs::read(path).ok() } else { None };
        let is_smd = path.extension().is_some_and(|e| e.eq_ignore_ascii_case("smd"));
        let Some(rom) = rom.filter(|rom| looks_like_a_cartridge(rom, is_smd)) else {
            self.fatal(EVENT_BAD_ROM, "This file is not a Mega Drive or Genesis game.");
            return None;
        };

        // Upstream starts with blank RAM when a save is the wrong size, and would then overwrite it. A
        // probe learns the size first, so another game's save under this name refuses the load instead.
        let probe = catch_unwind(|| Cartridge::new(rom.clone(), None, None, &[]));
        let Ok(probe) = probe else {
            self.fatal(EVENT_BAD_ROM, "JGenesis could not load this game.");
            return None;
        };
        if probe.is_ram_persistent() && !probe.external_ram().is_empty() {
            let blank = probe.external_ram();
            let file = saves.path("sav");
            let bytes = match fs::read(&file) {
                Ok(bytes) if bytes.len() == blank.len() => Some(bytes),
                Ok(_) => None,
                // Created now, so a folder that cannot be written refuses the game before any progress.
                Err(error) if error.kind() == io::ErrorKind::NotFound => write_file(&file, blank).ok().map(|()| blank.to_vec()),
                Err(_) => None,
            };
            let Some(bytes) = bytes else {
                self.fatal(EVENT_BAD_SAVE, "The save file for this game could not be opened.");
                return None;
            };
            saves.written.insert("sav".into(), bytes.clone());
            saves.latest.insert("sav".into(), bytes);
        }

        self.rom_hash = hash(&rom);
        let config = self.config.clone();
        match catch_unwind(AssertUnwindSafe(|| GenesisEmulator::create(GenesisHardware::Standalone, Some(rom), None, None, config, saves))) {
            Ok(Ok(emulator)) => Some(emulator),
            _ => {
                self.fatal(EVENT_BAD_ROM, "JGenesis could not load this game.");
                None
            }
        }
    }

    /// Mega-CD needs the console's BIOS, which GagaEmu never ships. A player's own copy is read from the
    /// system folder, picked by the disc's region.
    fn load_disc(&mut self, path: &Path, format: CdRomFileFormat, saves: &mut Saves) -> Option<GenesisEmulator> {
        let Ok(mut disc) = CdRom::open(path, format) else {
            self.fatal(EVENT_BAD_ROM, "The disc image could not be opened.");
            return None;
        };
        let region = segacd_core::parse_disc_region(&mut disc).unwrap_or(GenesisRegion::Americas);
        let preferred = match region {
            GenesisRegion::Americas => "bios_CD_U.bin",
            GenesisRegion::Europe => "bios_CD_E.bin",
            GenesisRegion::Japan => "bios_CD_J.bin",
        };
        let bios = [preferred, "bios_CD_U.bin", "bios_CD_E.bin", "bios_CD_J.bin"]
            .iter()
            .find_map(|name| fs::read(self.system_dir.join(name)).ok());
        let Some(bios) = bios else {
            self.fatal(
                EVENT_NO_BIOS,
                "This Mega-CD game needs a Mega-CD BIOS file (bios_CD_U.bin, bios_CD_E.bin or bios_CD_J.bin). GagaEmu does not include one.",
            );
            return None;
        };
        // shortcut: identifies a disc's states by its path and BIOS, because hashing a disc on every load is slow. Hash a sample of the image if renamed discs matter.
        self.rom_hash = hash(path.as_os_str().as_encoded_bytes()) ^ hash(&bios);
        let config = self.config.clone();
        match catch_unwind(AssertUnwindSafe(|| GenesisEmulator::create(GenesisHardware::SegaCd, None, Some(bios), Some(disc), config, saves))) {
            Ok(Ok(emulator)) => Some(emulator),
            Ok(Err(error)) => {
                self.fatal(EVENT_BAD_ROM, &format!("JGenesis could not load this disc: {error}"));
                None
            }
            Err(_) => {
                self.fatal(EVENT_BAD_ROM, "JGenesis could not load this disc.");
                None
            }
        }
    }

    fn step(&mut self, inputs: &[GagaInputState]) {
        if self.stopped {
            return;
        }
        let Some(emulator) = &mut self.emulator else { return };
        for (player, input) in [Player::One, Player::Two].into_iter().zip(inputs) {
            for &(mask, button) in &BUTTONS {
                self.inputs.set_field(button, player, input.buttons & mask != 0);
            }
        }
        let saves = self.saves.as_mut().expect("loaded with the emulator");
        let (video, audio, inputs) = (&mut self.video, &mut self.audio, &self.inputs);
        let ran = catch_unwind(AssertUnwindSafe(|| {
            // One frame is about 30,000 instructions; the bound only stops a broken frame from hanging the host.
            for _ in 0..2_000_000 {
                if emulator.tick(video, audio, &mut ConstantInputPoller(inputs), saves)? == TickEffect::FrameRendered {
                    break;
                }
            }
            Ok::<(), genesis_core::GenesisError<Infallible, Infallible, io::Error>>(())
        }));
        match ran {
            Ok(Ok(())) => {}
            Ok(Err(error)) => return self.stop(&format!("JGenesis stopped: {error}")),
            Err(_) => return self.stop("JGenesis stopped this game."),
        }

        if self.video.fresh {
            self.video.fresh = false;
            if let Some(cb) = self.video_cb {
                let frame = GagaFrameDescriptor {
                    pixel_data: self.video.pixels.as_ptr().cast(),
                    width: self.video.width,
                    height: self.video.height,
                    pitch: self.video.width as usize * 4,
                    pixel_format: PIXEL_FORMAT_RGBA8888,
                };
                // SAFETY: the host's callback; the pixels live through the call.
                unsafe { cb(&frame, self.video_userdata) };
            }
        }
        if !self.audio.0.is_empty() {
            if let Some(cb) = self.audio_cb {
                let packet = GagaAudioDescriptor {
                    pcm_samples: self.audio.0.as_ptr(),
                    frames: self.audio.0.len() / 2,
                    sample_rate: SAMPLE_RATE,
                    channels: 2,
                };
                // SAFETY: as above.
                unsafe { cb(&packet, self.audio_userdata) };
            }
            self.audio.0.clear(); // Always drained, so a host without an audio callback cannot back it up.
        }

        self.frames_since_flush += 1;
        if self.frames_since_flush >= FLUSH_FRAMES {
            self.frames_since_flush = 0;
            self.flush();
        }
    }

    /// After a panic upstream's state is suspect, so the game ends rather than running on.
    fn stop(&mut self, message: &str) {
        self.stopped = true;
        self.fatal(EVENT_STOPPED, message);
    }

    fn encode_state(&self) -> Option<Vec<u8>> {
        let emulator = self.emulator.as_ref()?;
        let mut bytes = Vec::with_capacity(STATE_HEADER);
        bytes.extend_from_slice(STATE_MAGIC);
        bytes.extend_from_slice(&STATE_VERSION.to_le_bytes());
        bytes.extend_from_slice(&self.rom_hash.to_le_bytes());
        let payload = catch_unwind(AssertUnwindSafe(|| bincode::encode_to_vec(emulator.to_save_state(), bincode_config()))).ok()?.ok()?;
        bytes.extend_from_slice(&payload);
        Some(bytes)
    }

    fn load_state(&mut self, bytes: &[u8]) -> Result<(), &'static str> {
        const WRONG_SIZE: &str = "This save state is the wrong size for JGenesis.";
        const OTHER_GAME: &str = "This save state belongs to another game or another version of this game.";
        const BROKEN: &str = "JGenesis could not load this save state.";
        if self.emulator.is_none() || bytes.len() <= STATE_HEADER {
            return Err(WRONG_SIZE);
        }
        if &bytes[..4] != STATE_MAGIC || bytes[4..8] != STATE_VERSION.to_le_bytes() || bytes[8..16] != self.rom_hash.to_le_bytes() {
            return Err(OTHER_GAME);
        }
        // Decoded into a new machine first, so a refusal leaves the running one untouched.
        let decoded = catch_unwind(|| bincode::decode_from_slice::<GenesisEmulator, _>(&bytes[STATE_HEADER..], bincode_config()));
        let state = match decoded {
            Ok(Ok((state, used))) if used == bytes.len() - STATE_HEADER => state,
            Ok(Ok(_)) | Ok(Err(DecodeError::UnexpectedEnd { .. })) => return Err(WRONG_SIZE),
            _ => return Err(BROKEN),
        };
        let emulator = self.emulator.as_mut().expect("checked above");
        emulator.load_state(state);
        // The state carries the settings it was saved with, cheats included; this session's win.
        emulator.reload_config(&self.config);
        Ok(())
    }
}

/// Cartridge headers start "SEGA" at $100, sometimes after a space, or byte-swapped in a few dumps.
/// Interleaved `.smd` images only read right once upstream deinterleaves them, so those are trusted.
fn looks_like_a_cartridge(rom: &[u8], is_smd: bool) -> bool {
    if rom.len() < 0x200 {
        return false; // Upstream reads the header up to $1FF without a length check.
    }
    is_smd || rom[0x100..0x110].windows(4).any(|w| w == b"SEGA" || w == b"ESAG")
}

fn fill_error(error: *mut c_char, capacity: usize, message: &str) {
    if error.is_null() || capacity == 0 {
        return;
    }
    let count = message.len().min(capacity - 1);
    // SAFETY: the host gives `capacity` writable bytes.
    unsafe {
        std::ptr::copy_nonoverlapping(message.as_ptr(), error.cast(), count);
        *error.add(count) = 0;
    }
}

/// # Safety
/// `inst` is NULL or a pointer from `jg_create` that `jg_destroy` has not freed.
unsafe fn instance<'a>(inst: *mut c_void) -> Option<&'a mut Instance> {
    unsafe { inst.cast::<Instance>().as_mut() }
}

fn path_from(path: *const c_char) -> Option<PathBuf> {
    // SAFETY: the host passes NUL-terminated strings.
    (!path.is_null()).then(|| PathBuf::from(unsafe { CStr::from_ptr(path) }.to_string_lossy().into_owned()))
}

// MARK: - C entry points, named in JgenesisCore.c

#[unsafe(no_mangle)]
pub extern "C" fn jg_create(system_dir: *const c_char, save_dir: *const c_char) -> *mut c_void {
    let six = || GenesisController::new(GenesisControllerType::SixButton);
    let instance = Instance {
        system_dir: path_from(system_dir).unwrap_or_default(),
        save_dir: path_from(save_dir).unwrap_or_default(),
        emulator: None,
        stopped: false,
        config: GenesisEmulatorConfig::default(),
        inputs: GenesisInputs { p1: six(), p2: six() },
        saves: None,
        save_failed: false,
        rom_hash: 0,
        frames_since_flush: 0,
        cheats: Vec::new(),
        video: Video::default(),
        audio: Audio::default(),
        video_cb: None,
        video_userdata: std::ptr::null_mut(),
        audio_cb: None,
        audio_userdata: std::ptr::null_mut(),
        event_cb: None,
        event_userdata: std::ptr::null_mut(),
    };
    Box::into_raw(Box::new(instance)).cast()
}

/// # Safety
/// See `instance`. No callback fires after this returns.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_destroy(inst: *mut c_void) {
    let Some(m) = (unsafe { instance(inst) }) else { return };
    m.video_cb = None;
    m.audio_cb = None;
    m.event_cb = None;
    m.flush();
    // SAFETY: from Box::into_raw in jg_create.
    drop(unsafe { Box::from_raw(inst.cast::<Instance>()) });
}

/// # Safety
/// See `instance`. `rom_path` is a NUL-terminated path.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_load_rom(inst: *mut c_void, rom_path: *const c_char, _data: *const c_void, _size: usize) -> bool {
    let Some(m) = (unsafe { instance(inst) }) else { return false };
    let Some(path) = path_from(rom_path) else { return false };
    m.emulator.is_none() && m.load(&path)
}

/// # Safety
/// See `instance`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_reset(inst: *mut c_void) {
    let Some(m) = (unsafe { instance(inst) }) else { return };
    if let Some(emulator) = &mut m.emulator {
        if catch_unwind(AssertUnwindSafe(|| emulator.soft_reset())).is_err() {
            m.stop("JGenesis stopped this game.");
        }
    }
}

/// # Safety
/// See `instance`. `inputs` holds 4 entries or is NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_step_frame(inst: *mut c_void, inputs: *const GagaInputState, player_count: u32) {
    let Some(m) = (unsafe { instance(inst) }) else { return };
    let count = if inputs.is_null() { 0 } else { player_count.min(4) as usize };
    // SAFETY: the host passes an array of 4.
    let inputs = if count == 0 { &[][..] } else { unsafe { std::slice::from_raw_parts(inputs, count) } };
    m.step(inputs);
}

/// # Safety
/// See `instance`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_set_video_callback(inst: *mut c_void, cb: VideoCallback, userdata: *mut c_void) {
    if let Some(m) = unsafe { instance(inst) } {
        (m.video_cb, m.video_userdata) = (cb, userdata);
    }
}

/// # Safety
/// See `instance`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_set_audio_callback(inst: *mut c_void, cb: AudioCallback, userdata: *mut c_void) {
    if let Some(m) = unsafe { instance(inst) } {
        (m.audio_cb, m.audio_userdata) = (cb, userdata);
    }
}

/// # Safety
/// See `instance`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_set_event_callback(inst: *mut c_void, cb: EventCallback, userdata: *mut c_void) {
    if let Some(m) = unsafe { instance(inst) } {
        (m.event_cb, m.event_userdata) = (cb, userdata);
    }
}

/// # Safety
/// See `instance`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_state_size(inst: *mut c_void) -> usize {
    unsafe { instance(inst) }.and_then(|m| m.encode_state()).map_or(0, |bytes| bytes.len())
}

/// # Safety
/// See `instance`. `buffer` holds `size` writable bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_save_state(inst: *mut c_void, buffer: *mut c_void, size: usize) -> bool {
    let Some(bytes) = unsafe { instance(inst) }.and_then(|m| m.encode_state()) else { return false };
    if buffer.is_null() || bytes.len() != size {
        return false;
    }
    // SAFETY: checked above.
    unsafe { std::ptr::copy_nonoverlapping(bytes.as_ptr(), buffer.cast(), size) };
    true
}

/// # Safety
/// See `instance`. `buffer` holds `size` bytes; `error` holds `capacity` bytes or is NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_load_state(inst: *mut c_void, buffer: *const c_void, size: usize, error: *mut c_char, capacity: usize) -> bool {
    let Some(m) = (unsafe { instance(inst) }) else { return false };
    // SAFETY: as documented.
    let bytes = if buffer.is_null() { &[][..] } else { unsafe { std::slice::from_raw_parts(buffer.cast::<u8>(), size) } };
    match m.load_state(bytes) {
        Ok(()) => true,
        Err(message) => {
            fill_error(error, capacity, message);
            false
        }
    }
}

/// # Safety
/// See `instance`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_flush_battery_save(inst: *mut c_void) {
    if let Some(m) = unsafe { instance(inst) } {
        m.flush();
    }
}

/// Game Genie (ABCD-EFGH), Pro Action Replay (98765-43210) or address:value (FF0000:0001), one per line,
/// read by upstream's own decoders. Adding an ID that exists replaces that cheat.
///
/// # Safety
/// See `instance`. `code` is NUL-terminated; `error` holds `capacity` bytes or is NULL.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_cheat_add(inst: *mut c_void, id: u32, code: *const c_char, enabled: bool, error: *mut c_char, capacity: usize) -> bool {
    let Some(m) = (unsafe { instance(inst) }) else { return false };
    if code.is_null() {
        return false;
    }
    // SAFETY: NUL-terminated.
    let text = unsafe { CStr::from_ptr(code) }.to_string_lossy();
    let mut codes = Vec::new();
    for line in text.lines().map(str::trim).filter(|line| !line.is_empty()) {
        match GenesisCheatCodeType::guess_from(line).and_then(|kind| kind.decode(line)) {
            Some(decoded) => codes.push(decoded),
            None => {
                let shown: String = line.chars().take(32).collect();
                fill_error(error, capacity, &format!("JGenesis does not recognise this code: {shown}"));
                return false;
            }
        }
    }
    if codes.is_empty() {
        fill_error(error, capacity, "Enter a cheat code.");
        return false;
    }
    m.cheats.retain(|cheat| cheat.id != id);
    m.cheats.push(Cheat { id, enabled, codes });
    m.apply_cheats();
    true
}

/// # Safety
/// See `instance`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_cheat_remove(inst: *mut c_void, id: u32) {
    if let Some(m) = unsafe { instance(inst) } {
        m.cheats.retain(|cheat| cheat.id != id);
        m.apply_cheats();
    }
}

/// # Safety
/// See `instance`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn jg_cheat_set_enabled(inst: *mut c_void, id: u32, enabled: bool) {
    if let Some(m) = unsafe { instance(inst) } {
        m.cheats.iter_mut().filter(|cheat| cheat.id == id).for_each(|cheat| cheat.enabled = enabled);
        m.apply_cheats();
    }
}

/// Brings up a whole machine on a blank cartridge, which proves the library linked and runs, and checks
/// that the pinned upstream still writes the state format `STATE_VERSION` names.
#[unsafe(no_mangle)]
pub extern "C" fn jg_self_test(error: *mut c_char, capacity: usize) -> bool {
    if GenesisEmulator::save_state_version() != UPSTREAM_STATE_VERSION {
        fill_error(error, capacity, "JGenesis was built with an unexpected save state format.");
        return false;
    }
    let mut saves = Saves { dir: PathBuf::new(), stem: String::new(), latest: HashMap::new(), written: HashMap::new() };
    let ran = catch_unwind(AssertUnwindSafe(|| {
        let mut emulator =
            GenesisEmulator::create(GenesisHardware::Standalone, Some(vec![0; 0x400]), None, None, GenesisEmulatorConfig::default(), &mut saves)
                .ok()?;
        emulator.tick(&mut Video::default(), &mut Audio::default(), &mut ConstantInputPoller(&GenesisInputs::default()), &mut saves).ok()
    }));
    if !matches!(ran, Ok(Some(_))) {
        fill_error(error, capacity, "JGenesis could not start.");
        return false;
    }
    true
}
