// Builds upstream's PIC event queue (sources.txt lists this file instead of upstream/src/hardware/pic.cpp) and
// adds one function that needs its static queue: running a handler's pending events now. GagaDosboxPure.cpp
// uses it to write the C: drive save file at a battery flush instead of up to 60 emulated seconds later.
#include "upstream/src/hardware/pic.cpp"

void GAGA_PIC_RunEventsNow(PIC_EventHandler handler)
{
	// Collect first: a handler may queue itself again (WriteSaveFile retries on failure), which must not loop.
	Bitu values[PIC_QUEUESIZE];
	Bitu count = 0;
	for (PICEntry* entry = pic_queue.next_entry; entry; entry = entry->next)
		if (entry->pic_event == handler) values[count++] = entry->value;
	for (Bitu i = 0; i != count; i++)
	{
		PIC_RemoveSpecificEvents(handler, values[i]);
		handler(values[i]);
	}
}
