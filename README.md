# RISC-V ECG SoC

An FPGA-based ECG signal processing System-on-Chip using the PicoRV32 RISC-V processor.

## Overview

This project implements a small RISC-V based SoC for ECG signal processing.

The SoC integrates:

- PicoRV32 RISC-V CPU
- ROM
- RAM
- UART interface
- FIR filter accelerator
- ECG peak detector
- RR interval calculation
- Heart-rate calculation

The RTL is written in Verilog and verified using ModelSim.

## System Architecture

```text
                ECG Samples
                     |
                     v
                  UART RX
                     |
                     v
               PicoRV32 CPU
                /        \
               /          \
              v            v
      FIR Accelerator      RAM
              |
              v
       Peak Detector
              |
              v
       RR Interval / BPM
              |
              v
             RAM
