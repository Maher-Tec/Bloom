import math
import struct
import random
import wave
import os

SAMPLE_RATE = 44100

def write_wav(filename, samples, sample_rate=SAMPLE_RATE, channels=2):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    with wave.open(filename, 'w') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        # convert float samples [-1.0, 1.0] to 16-bit PCM
        raw = bytearray()
        for frame in samples:
            if channels == 1:
                val = int(max(-1.0, min(1.0, frame)) * 32767)
                raw.extend(struct.pack('<h', val))
            else:
                left, right = frame
                val_l = int(max(-1.0, min(1.0, left)) * 32767)
                val_r = int(max(-1.0, min(1.0, right)) * 32767)
                raw.extend(struct.pack('<hh', val_l, val_r))
        wf.writeframes(raw)

def gen_bloom():
    duration = 3.5
    total_frames = int(SAMPLE_RATE * duration)
    out = [[0.0, 0.0] for _ in range(total_frames)]
    
    # Celestial harp chord arpeggio: C5 (523.25), E5 (659.25), G5 (783.99), B5 (987.77), D6 (1174.66), G6 (1567.98)
    notes = [
        (0.00, 523.25, 0.50, -0.4),
        (0.12, 659.25, 0.45, -0.2),
        (0.24, 783.99, 0.45, 0.0),
        (0.36, 987.77, 0.40, 0.2),
        (0.48, 1174.66, 0.40, 0.4),
        (0.60, 1567.98, 0.35, 0.1),
        (0.72, 2093.00, 0.25, -0.1),
    ]
    
    for start_t, freq, amp, pan in notes:
        start_idx = int(start_t * SAMPLE_RATE)
        note_len = total_frames - start_idx
        left_gain = amp * (0.5 - 0.5 * pan)
        right_gain = amp * (0.5 + 0.5 * pan)
        for i in range(note_len):
            t = i / SAMPLE_RATE
            # harp envelope: fast attack, exponential decay with bell shimmer
            env = math.exp(-t * 2.2) * (1.0 - math.exp(-t * 80.0))
            # fundamental + soft harmonics + subtle chorus shimmer
            shimmer = 1.0 + 0.003 * math.sin(t * 18.0)
            s = (math.sin(2.0 * math.pi * freq * shimmer * t) * 0.7 +
                 math.sin(2.0 * math.pi * freq * 2.0 * t) * 0.25 * math.exp(-t * 4.0) +
                 math.sin(2.0 * math.pi * freq * 3.0 * t) * 0.12 * math.exp(-t * 6.0) +
                 math.sin(2.0 * math.pi * freq * 4.0 * t) * 0.06 * math.exp(-t * 8.0))
            val = s * env
            out[start_idx + i][0] += val * left_gain
            out[start_idx + i][1] += val * right_gain

    # Normalize gently
    max_val = max(max(abs(l), abs(r)) for l, r in out)
    if max_val > 0.01:
        scale = 0.85 / max_val
        for f in out:
            f[0] *= scale
            f[1] *= scale
    return out

def gen_tap():
    duration = 0.65
    total_frames = int(SAMPLE_RATE * duration)
    out = [[0.0, 0.0] for _ in range(total_frames)]
    freq = 880.0 # A5 warm bell
    freq2 = 1320.0 # E6 harmonic
    for i in range(total_frames):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 7.5) * (1.0 - math.exp(-t * 200.0))
        val = (math.sin(2.0 * math.pi * freq * t) * 0.75 +
               math.sin(2.0 * math.pi * freq2 * t) * 0.35 * math.exp(-t * 12.0)) * env * 0.65
        out[i][0] = val
        out[i][1] = val
    return out

def gen_ripple():
    duration = 0.55
    total_frames = int(SAMPLE_RATE * duration)
    out = [[0.0, 0.0] for _ in range(total_frames)]
    for i in range(total_frames):
        t = i / SAMPLE_RATE
        # water droplet frequency sweep: 600 -> 1800 Hz
        freq = 600.0 + 1200.0 * (1.0 - math.exp(-t * 35.0))
        env = math.sin(min(1.0, t / 0.02) * math.pi * 0.5) * math.exp(-t * 14.0)
        val = math.sin(2.0 * math.pi * freq * t) * env * 0.7
        out[i][0] = val * 0.9
        out[i][1] = val * 0.95
    return out

def gen_ambient_day():
    duration = 10.0 # 10-second seamless soothing nature loop
    total_frames = int(SAMPLE_RATE * duration)
    out = [[0.0, 0.0] for _ in range(total_frames)]
    
    # 1. Gentle running water stream (layered filtered noise with natural bubbles)
    # Generate pink-like noise filtered around water frequencies (200 - 1500 Hz)
    rng = random.Random(42)
    b0, b1, b2 = 0.0, 0.0, 0.0
    for i in range(total_frames):
        t = i / SAMPLE_RATE
        # Brown/pink water turbulence
        white = rng.uniform(-1.0, 1.0)
        b0 = 0.992 * b0 + white * 0.05
        b1 = 0.985 * b1 + white * 0.08
        
        # slow natural water surging modulation
        surge = 0.8 + 0.2 * math.sin(2.0 * math.pi * 0.3 * t) + 0.1 * math.sin(2.0 * math.pi * 0.7 * t)
        
        # gentle water trickle bubble pings
        bubble = 0.0
        if rng.random() < 0.0004:
            bfreq = rng.uniform(800, 1600)
            bubble = math.sin(2.0 * math.pi * bfreq * t) * 0.15
            
        stream_l = (b0 * 0.4 + bubble) * surge * 0.25
        stream_r = (b1 * 0.4 + bubble * 0.8) * surge * 0.25
        
        # Soft gentle breeze modulation (deep low-passed air)
        breeze = (math.sin(2.0 * math.pi * 0.15 * t) * 0.5 + 0.5) * 0.04
        
        out[i][0] = stream_l + breeze
        out[i][1] = stream_r + breeze

    # 2. Delicate distant songbird chirps at serene intervals
    bird_times = [
        (1.5, [2400, 2900, 3400], 0.12),
        (1.9, [3100, 2600], 0.10),
        (5.2, [2800, 3300, 3800, 3100], 0.11),
        (7.8, [3200, 3600], 0.09),
    ]
    for b_start, freqs, b_amp in bird_times:
        cur_t = b_start
        for f in freqs:
            dur = 0.08
            n_samples = int(dur * SAMPLE_RATE)
            idx0 = int(cur_t * SAMPLE_RATE)
            for j in range(n_samples):
                if idx0 + j >= total_frames:
                    continue
                tj = j / SAMPLE_RATE
                env = math.sin(tj / dur * math.pi)
                val = math.sin(2.0 * math.pi * f * tj) * env * b_amp
                out[idx0 + j][0] += val * 0.3
                out[idx0 + j][1] += val * 0.7
            cur_t += dur + 0.04

    # Apply crossfade loop smoothing at start and end for seamless repetition
    fade_len = int(SAMPLE_RATE * 0.8)
    for i in range(fade_len):
        w = i / fade_len
        # blend out[i] with out[total_frames - fade_len + i]
        l1, r1 = out[i]
        l2, r2 = out[total_frames - fade_len + i]
        out[i] = [l1 * w + l2 * (1.0 - w), r1 * w + r2 * (1.0 - w)]
        out[total_frames - fade_len + i] = out[i]

    # Normalize
    max_val = max(max(abs(l), abs(r)) for l, r in out)
    if max_val > 0.01:
        scale = 0.55 / max_val
        for f in out:
            f[0] *= scale
            f[1] *= scale
    return out

def gen_ambient_night():
    duration = 10.0 # 10-second seamless night nature loop
    total_frames = int(SAMPLE_RATE * duration)
    out = [[0.0, 0.0] for _ in range(total_frames)]
    
    # 1. Softer stream & night breeze
    rng = random.Random(108)
    b0, b1 = 0.0, 0.0
    for i in range(total_frames):
        t = i / SAMPLE_RATE
        white = rng.uniform(-1.0, 1.0)
        b0 = 0.994 * b0 + white * 0.035
        b1 = 0.990 * b1 + white * 0.045
        
        surge = 0.7 + 0.15 * math.sin(2.0 * math.pi * 0.2 * t)
        stream_l = b0 * surge * 0.18
        stream_r = b1 * surge * 0.18
        
        # 2. Night crickets: rhythmic high frequency pulsing (4500 - 5200 Hz)
        # Cricket chirps come in natural cadences
        cricket_pulse1 = (math.sin(2.0 * math.pi * 3.5 * t) * 0.5 + 0.5) ** 4
        cricket_pulse2 = (math.sin(2.0 * math.pi * 4.2 * (t + 0.3)) * 0.5 + 0.5) ** 4
        c_tone1 = math.sin(2.0 * math.pi * 4700.0 * t) * cricket_pulse1 * 0.045
        c_tone2 = math.sin(2.0 * math.pi * 5150.0 * t) * cricket_pulse2 * 0.035
        
        out[i][0] = stream_l + c_tone1 * 0.7 + c_tone2 * 0.3
        out[i][1] = stream_r + c_tone1 * 0.3 + c_tone2 * 0.7

    fade_len = int(SAMPLE_RATE * 0.8)
    for i in range(fade_len):
        w = i / fade_len
        l1, r1 = out[i]
        l2, r2 = out[total_frames - fade_len + i]
        out[i] = [l1 * w + l2 * (1.0 - w), r1 * w + r2 * (1.0 - w)]
        out[total_frames - fade_len + i] = out[i]

    max_val = max(max(abs(l), abs(r)) for l, r in out)
    if max_val > 0.01:
        scale = 0.50 / max_val
        for f in out:
            f[0] *= scale
            f[1] *= scale
    return out

def main():
    print("Generating soundscapes...")
    write_wav("assets/audio/bloom.wav", gen_bloom())
    write_wav("assets/audio/tap.wav", gen_tap())
    write_wav("assets/audio/ripple.wav", gen_ripple())
    write_wav("assets/audio/ambient_day.wav", gen_ambient_day())
    write_wav("assets/audio/ambient_night.wav", gen_ambient_night())
    print("All audio files generated successfully!")

if __name__ == "__main__":
    main()
