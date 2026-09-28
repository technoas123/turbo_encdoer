# Turbo Encoder

A hardware/software implementation of the duo-binary Turbo Forward Error Correction (FEC) Encoder compliant with the **DVB-RCS2** (Digital Video Broadcasting - Second Generation Return Channel over Satellite) standard as defined in **ETSI EN 301 545-2**. 

This repository provides the core logic for the 16-state double-binary parallel concatenated recursive systematic convolutional (RSC) architecture used to ensure robust data transmission over high-latency, noisy satellite return links.

## Features
* **Standard Compliant:** Adheres fully to the ETSI EN 301 545-2 Section 7.3.5.1 specifications.
* **Dual-Path Architecture:** Implements both the linear ordered path and the complex algebraically-defined interleaved permutation block (supporting parameters $P, Q_0, Q_1, Q_2, Q_3$).
* **Duo-Binary Input:** Feeds data in blocks of $K$ bits ($N = K/2$ couples) taking two bits of input ($A$ and $B$) and generating standard systematic/parity bit combinations ($AB \ Y_1W_1 \ Y_2W_2$).
* **Flexible Configurations:** Designed to support standard code rates (e.g., 1/3, 1/2, 2/3, 3/4, 4/5, 5/6, 6/7, 7/8) and various block payload sizes.

## Architecture Overview
The transmitter architecture employs a parallel concatenation of two double-binary Recursive Systematic Convolutional (RSC) encoders. The first copy of the data stream is coded in linear order, while the second path undergoes non-uniform permutation (interleaving) prior to encoding to maximize minimum Hamming distance and eliminate error floors.
