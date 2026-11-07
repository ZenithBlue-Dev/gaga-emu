// Stands in for upstream's third-party/blip_buf (LGPL-2.1), so the core has no LGPL code in its binary.
// Written from the function contracts in mgba/core/blip_buf.h, not from that library's source.
//
// A step in the input is stored as the band-limited impulse that is its derivative. Reading integrates
// the stored impulses back into samples, with a slow leak that removes DC.
#include <mgba/core/blip_buf.h>

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

enum {
    PHASES = 32,     // Sub-sample positions per output sample.
    TAPS = 16,       // Impulse length in output samples. Also the delay, at half of this.
    KERNEL_BITS = 12,
    TIME_BITS = 32,
    LEAK_BITS = 9,   // About 10 Hz at 32768 Hz, which is well below hearing.
};

struct blip_t {
    uint64_t samples_per_clock; // TIME_BITS of fraction.
    uint64_t offset;            // Where clock 0 of the current frame falls, in samples, TIME_BITS of fraction.
    int capacity;
    int64_t sum;
    int16_t kernel[PHASES][TAPS];
    int32_t deltas[]; // capacity + TAPS entries.
};

// A Hann-windowed sinc, summing to exactly one in fixed point at every phase, so a step always settles.
static void build_kernel(blip_t* blip) {
    for (int phase = 0; phase < PHASES; ++phase) {
        double raw[TAPS];
        double total = 0;
        for (int tap = 0; tap < TAPS; ++tap) {
            double x = tap - (TAPS / 2 - 1) - (double)phase / PHASES;
            double sinc = x == 0 ? 1 : sin(M_PI * x) / (M_PI * x);
            raw[tap] = sinc * (0.5 + 0.5 * cos(M_PI * x / (TAPS / 2)));
            total += raw[tap];
        }
        int sum = 0;
        for (int tap = 0; tap < TAPS; ++tap) {
            blip->kernel[phase][tap] = (int16_t)lround(raw[tap] / total * (1 << KERNEL_BITS));
            sum += blip->kernel[phase][tap];
        }
        blip->kernel[phase][TAPS / 2 - 1] += (int16_t)((1 << KERNEL_BITS) - sum);
    }
}

blip_t* blip_new(int sample_count) {
    blip_t* blip = malloc(sizeof(blip_t) + sizeof(int32_t) * (size_t)(sample_count + TAPS));
    if (!blip) return NULL;
    blip->capacity = sample_count;
    blip_set_rates(blip, blip_max_ratio, 1);
    build_kernel(blip);
    blip_clear(blip);
    return blip;
}

void blip_delete(blip_t* blip) { free(blip); }

void blip_set_rates(blip_t* blip, double clock_rate, double sample_rate) {
    blip->samples_per_clock = (uint64_t)ceil(sample_rate / clock_rate * (double)(1ULL << TIME_BITS));
}

void blip_clear(blip_t* blip) {
    blip->offset = 0;
    blip->sum = 0;
    memset(blip->deltas, 0, sizeof(int32_t) * (size_t)(blip->capacity + TAPS));
}

int blip_samples_avail(const blip_t* blip) { return (int)(blip->offset >> TIME_BITS); }

int blip_clocks_needed(const blip_t* blip, int sample_count) {
    uint64_t needed = (uint64_t)sample_count << TIME_BITS;
    if (needed <= blip->offset) return 0;
    return (int)((needed - blip->offset + blip->samples_per_clock - 1) / blip->samples_per_clock);
}

void blip_add_delta(blip_t* blip, unsigned int clock_time, int delta) {
    uint64_t time = blip->offset + clock_time * blip->samples_per_clock;
    uint64_t index = time >> TIME_BITS;
    if (index >= (uint64_t)blip->capacity) return; // No room: lose this step rather than write out of bounds.
    const int16_t* kernel = blip->kernel[(time >> (TIME_BITS - 5)) & (PHASES - 1)];
    for (int tap = 0; tap < TAPS; ++tap) blip->deltas[index + (uint64_t)tap] += delta * kernel[tap];
}

void blip_add_delta_fast(blip_t* blip, unsigned int clock_time, int delta) {
    blip_add_delta(blip, clock_time, delta);
}

void blip_end_frame(blip_t* blip, unsigned int clock_duration) {
    blip->offset += clock_duration * blip->samples_per_clock;
    uint64_t limit = (uint64_t)blip->capacity << TIME_BITS;
    if (blip->offset > limit) blip->offset = limit;
}

int blip_read_samples(blip_t* blip, short out[], int count, int stereo) {
    int available = blip_samples_avail(blip);
    if (count > available) count = available;
    if (count <= 0) return 0;
    int64_t sum = blip->sum;
    for (int i = 0; i < count; ++i) {
        int64_t sample = sum >> KERNEL_BITS;
        out[stereo ? i * 2 : i] = sample > INT16_MAX ? INT16_MAX : sample < INT16_MIN ? INT16_MIN : (short)sample;
        sum += blip->deltas[i];
        sum -= sum >> LEAK_BITS;
    }
    blip->sum = sum;
    // Steps of the unfinished frame sit past the available samples, so the whole tail moves.
    size_t remaining = (size_t)(blip->capacity + TAPS - count);
    memmove(blip->deltas, blip->deltas + count, sizeof(int32_t) * remaining);
    memset(blip->deltas + remaining, 0, sizeof(int32_t) * (size_t)count);
    blip->offset -= (uint64_t)count << TIME_BITS;
    return count;
}
