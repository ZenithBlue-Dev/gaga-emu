// Cheats for FinalBurn Neo. Upstream's retro_cheat_set does nothing; its libretro frontend loads the player's
// cheat files from System/fbneo/cheats/ (<set>.ini, <set>.dat, cheat.dat) when a game starts and offers each cheat
// as a core option. GagaEmu has no option screen, so a code names a cheat from those files instead: "Infinite
// Lives" picks its first setting, and "Infinite Lives = 9 Lives" picks a setting by name. Upstream's own
// CheatEnable then does the work, as its option code does. C++98, as the rest of this core is built.
#include "burner.h"

#include <ctype.h>
#include <string>
#include <strings.h>

static std::string fbneo_trimmed(const std::string& text) {
    std::string::size_type start = text.find_first_not_of(" \t\r\n");
    if (start == std::string::npos) return std::string();
    return text.substr(start, text.find_last_not_of(" \t\r\n") - start + 1);
}

static bool fbneo_same(const std::string& a, const TCHAR* b) {
    std::string other = fbneo_trimmed(b);
    return a.size() == other.size() && strncasecmp(a.c_str(), other.c_str(), a.size()) == 0;
}

// The cheat's index in upstream's list (headings count, as in CheatEnable) and the option to select, or false.
static bool fbneo_find_cheat(const char* line, INT32* cheat, INT32* option) {
    std::string text = fbneo_trimmed(line ? line : "");
    std::string::size_type equals = text.rfind('=');
    for (int pass = 0; pass < 2; ++pass) {
        // First the whole line as a name, then "name = option".
        std::string name = pass == 0 ? text : fbneo_trimmed(text.substr(0, equals));
        std::string wanted = pass == 0 ? std::string() : fbneo_trimmed(text.substr(equals + 1));
        if (pass == 1 && (equals == std::string::npos || wanted.empty())) return false;
        INT32 index = 0;
        for (CheatInfo* info = pCheatInfo; info; info = info->pNext, ++index) {
            if (info->pOption[0] == NULL || !fbneo_same(name, info->szCheatName)) continue; // A heading has no options.
            for (INT32 i = 1; i < CHEAT_MAX_OPTIONS && info->pOption[i]; ++i) { // CheatEnable reads 0 as "off".
                if (i == info->nDefault) continue;
                if (pass == 0 || fbneo_same(wanted, info->pOption[i]->szOptionName)) {
                    *cheat = index;
                    *option = i;
                    return true;
                }
            }
        }
    }
    return false;
}

extern "C" bool gaga_fbneo_is_cheat(const char* line) {
    INT32 cheat, option;
    return fbneo_find_cheat(line, &cheat, &option);
}

extern "C" void gaga_fbneo_cheat_reset(void) {
    bCheatsAllowed = true; // Upstream sets it when it applies its cheat options; the machine is running by now.
    INT32 index = 0;
    for (CheatInfo* info = pCheatInfo; info; info = info->pNext, ++index) {
        if (info->pOption[0] != NULL) CheatEnable(index, -1); // Back to the default (off) option.
    }
}

extern "C" void gaga_fbneo_cheat_set(unsigned, bool enabled, const char* code) {
    INT32 cheat, option;
    if (!enabled || !fbneo_find_cheat(code, &cheat, &option)) return;
    bCheatsAllowed = true;
    CheatEnable(cheat, option);
}
