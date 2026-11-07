// Included before every FBNeo source (core.env). upstream/src/burn/devices/thready.h hands some drivers' drawing
// to a second thread on Apple, after sem_open makes two named semaphores. Every GagaEmu core runs on one thread,
// so a state is the whole machine and replays exactly. These names point both calls at stubs in FbneoCore.c that
// fail, and thready.h then takes its own single-thread path ("falling back to single-thread mode").
#define sem_open gaga_fbneo_no_sem_open
#define pthread_create gaga_fbneo_no_pthread_create
