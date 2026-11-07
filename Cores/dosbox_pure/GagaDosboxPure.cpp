// Builds upstream's libretro core (sources.txt lists this file instead of upstream/dosbox_pure_libretro.cpp) and
// adds what DosboxPureCore.c needs from its static state. Upstream stays unmodified.
#define retro_serialize_size dbp_upstream_retro_serialize_size
#include "upstream/dosbox_pure_libretro.cpp"
#undef retro_serialize_size

// Upstream reports the exact size of the current state, which changes from frame to frame. The adapter needs
// one size per session, so this reports the largest state the machine can produce, the size upstream itself
// reports before a game runs. A smaller state is written zero padded, and loading reads only what was written.
extern "C" RETRO_API size_t retro_serialize_size(void)
{
	DBPArchiveCounter ar(true);
	return retro_serialize_all(ar, false) ? ar.count : 0;
}

// dbp_wasloaded outlives retro_unload_game, so a second session in the same process would keep the first
// one's content and save file. Called before every load.
extern "C" void gaga_dbp_forget_content(void)
{
	dbp_wasloaded = false;
	dbp_content_year = 0;
}

#include <pic.h>
void GAGA_PIC_RunEventsNow(PIC_EventHandler handler); // GagaPic.cpp
DBP_SERIALIZE_EXTERN_POINTER_LIST(PIC_EventHandler, unionDrive);

// Files the program writes to C: reach <save dir>/<content>.pure.zip about a second of emulated time later,
// and only on unload when they are large. A battery flush writes them now, with the DOS thread paused.
extern "C" bool gaga_dbp_save_drives(void)
{
	if (dbp_state != DBPSTATE_RUNNING && dbp_state != DBPSTATE_FIRST_FRAME) return true;
	DBP_ThreadControl(TCM_PAUSE_FRAME);
	GAGA_PIC_RunEventsNow(DBP_SERIALIZE_GET_POINTER_LIST(PIC_EventHandler, unionDrive)[0]);
	DBP_ThreadControl(TCM_RESUME_FRAME);
	return true;
}
