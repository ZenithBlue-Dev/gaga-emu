#include "emu.h"

#include "drivenum.h"

GAME_EXTERN(___empty);
GAME_EXTERN(alienar);
GAME_EXTERN(carpolo);
GAME_EXTERN(circus);
GAME_EXTERN(crash);
GAME_EXTERN(falcnwld);
GAME_EXTERN(fax);
GAME_EXTERN(fireone);
GAME_EXTERN(gridlee);
GAME_EXTERN(hardhat);
GAME_EXTERN(looping);
GAME_EXTERN(ripcord);
GAME_EXTERN(robby);
GAME_EXTERN(robotbwl);
GAME_EXTERN(sidetrac);
GAME_EXTERN(spectar);
GAME_EXTERN(starfire);
GAME_EXTERN(supertnk);
GAME_EXTERN(targ);
GAME_EXTERN(teetert);
GAME_EXTERN(topgunnr);
GAME_EXTERN(victory);
GAME_EXTERN(witchcrd);
GAME_EXTERN(witchgme);
GAME_EXTERN(witchjol);
GAME_EXTERN(wldwitch);
GAME_EXTERN(wstrike);
GAME_EXTERN(wtchjack);
GAME_EXTERN(wupndown);

game_driver const *const driver_list::s_drivers_sorted[29] =
{
	&GAME_NAME(___empty),
	&GAME_NAME(alienar),
	&GAME_NAME(carpolo),
	&GAME_NAME(circus),
	&GAME_NAME(crash),
	&GAME_NAME(falcnwld),
	&GAME_NAME(fax),
	&GAME_NAME(fireone),
	&GAME_NAME(gridlee),
	&GAME_NAME(hardhat),
	&GAME_NAME(looping),
	&GAME_NAME(ripcord),
	&GAME_NAME(robby),
	&GAME_NAME(robotbwl),
	&GAME_NAME(sidetrac),
	&GAME_NAME(spectar),
	&GAME_NAME(starfire),
	&GAME_NAME(supertnk),
	&GAME_NAME(targ),
	&GAME_NAME(teetert),
	&GAME_NAME(topgunnr),
	&GAME_NAME(victory),
	&GAME_NAME(witchcrd),
	&GAME_NAME(witchgme),
	&GAME_NAME(witchjol),
	&GAME_NAME(wldwitch),
	&GAME_NAME(wstrike),
	&GAME_NAME(wtchjack),
	&GAME_NAME(wupndown),
};

std::size_t const driver_list::s_driver_count = 29;
