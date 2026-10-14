# CIC Decimation Filter with FIR Droop Compensation

A Verilog implementation of a third-order Cascaded Integrator-Comb (CIC) decimation filter for sigma-delta ADC signals, with an optional six-tap FIR filter to compensate for passband droop.

## 1. Overview

A sigma-delta ADC produces a high-rate stream of 1-bit samples containing quantization noise. The CIC filter reduces the sampling rate while preserving the useful signal band. However, its response attenuates higher frequencies, particularly near 1 kHz.

This project contains two implementations:

- **Task 1 — CIC only:** Decimation and output scaling.
- **Task 2 — CIC + FIR:** Adds a six-tap FIR compensator to improve the CIC passband response.

### Design specifications

| Parameter | Value |
|---|---:|
| Input sampling rate | 4.096 MHz |
| Decimation factor | 2048 |
| Output sampling rate | 2 kHz |
| CIC order | 3 |
| Differential delay | 1 |
| Output width | Signed 20-bit |

### Signal path

**Task 1:** Input → 3 integrators → downsample by 2048 → 3 combs → scale, round and saturate → output.

**Task 2:** Input → CIC decimator → 6-tap FIR compensator → round and saturate → output.

## 2. CIC Design Choices

| Parameter | Value | Justification |
|---|---:|---|
| Order (`N`) | 3 | Selected after comparing orders 2, 3 and 4. |
| Decimation (`R`) | 2048 | Reduces 4.096 MHz to 2 kHz. |
| Differential delay (`M`) | 1 | A delay of 2 would place a response null at 1 kHz, close to the 990 Hz test tone. |
| Internal width | 35 bits | Based on the register growth bound: `3 × log2(2048) + 2 = 35` bits. |

The CIC uses integrators at the input rate and comb stages after decimation. These stages do not require multipliers.

In Task 1, the final CIC value is scaled using:

`output = round(7 × value / 2^15)`

The result is saturated to the signed 20-bit range. The project notes report no clipping and approximately 11.5 dB of CIC attenuation at 990 Hz.

## 3. FIR Droop Compensation

The FIR operates at the 2 kHz output rate and receives the **full-precision CIC output**, before final rounding and saturation.

### Selected coefficients

| Tap | Coefficient |
|---:|---:|
| `h[0]` | 182004 |
| `h[1]` | -96584 |
| `h[2]` | 50848 |
| `h[3]` | -28297 |
| `h[4]` | 15908 |
| `h[5]` | -7553 |

### Why these coefficients?

The coefficients approximate the inverse of the CIC's passband droop. According to the design notes, the process was to construct a minimum-phase response from the inverse-droop target, truncate it to six taps, and refine the coefficients using least squares.

Six taps provide a compromise between compensation and startup settling time. Since the SNR analysis uses 2000 output samples, a longer filter can introduce more startup error into the measurement. The coefficients include the output gain, so no additional gain stage is needed after the FIR.

Rounding and saturation are performed once, at the end of the FIR path.

## 4. SNR Results

The following values are reported by the project's MATLAB analysis script, `fft_2.m`.

| Input tone | CIC only | CIC + FIR | Change |
|---:|---:|---:|---:|
| 10 Hz | 121.00 dB | 121.75 dB | +0.75 dB |
| 500 Hz | 159.22 dB | 138.82 dB | -20.40 dB |
| 990 Hz | 111.08 dB | 120.34 dB | **+9.26 dB** |

The main objective is to improve performance near the upper end of the passband. At 990 Hz, the reported SNR improves by **9.26 dB** after FIR compensation.

The 500 Hz result is an atypical case: the project notes state that its output repeats every four samples, affecting rounding-error cancellation. Its reported SNR should therefore be interpreted with care.

The accompanying report contains the supplied spectrum and PSD plots. These plots show the CIC output, not the output of the complete CIC + FIR implementation.
