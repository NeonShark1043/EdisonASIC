<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

(High-Level)
-Lux: Measure and output light intensity from the surrounding environment 
-Morse: Read in-time light communication to decode Morse Code messages
-LED Bar: Brightens to show how much the light signal is brighter than the surrounding environment (blank)

(Low-Level) There are 9 digital modules in total-
1) Edge Detector: Monitors asynchronous input signals, such as a physical button press, and generates a single clock-cycle pulse on either the rising or falling edge. Use this to ensure that a single button press does not accidentally trigger a logic state multiple times.
-Key Inputs: signal_in (from physical switches)
-Key Outputs: rising_edge (pulse on press), falling_edge (pulse on release)
2) Button Control: A user interface manager that interprets specific hardware gestures, such as "hold to start/shutdown" or "tap to calibrate," to toggle the system's operational states. It also handles the logic for switching the display mode between Lux measurements and Morse decoding.
-Key Inputs: push_button, blank_button
-Key Outputs: start (activates FSM), calibrate (sets light baseline), seg_mode (switch display units)
3) ADC FSM: Implements the Successive Approximation Register (SAR) algorithm to convert analog light levels into a 12-bit digital value. It iteratively "guesses" the voltage and checks the external comparator to home in on the correct digital reading over multiple cycles.
-Key Inputs: start, comp_in (external comparator)
-Key Outputs: sah_en (signal for Sample-and-Hold), dac_out (current guess for the R-2R ladder), adc_out (final 12-bit value), data_ready (pulse when a sample is completed)
4) Light Processor: Acts as a digital filter and pulse detector by smoothing out noise using a block average and maintains a "hysteresis" buffer to ensure the light_on signal does not flicker when the light level is hovering right at the threshold.
-Key Inputs: adc_out, calibrate
-Key Outputs: light_diff (light magnitude above baseline), light_on (bit representing a Morse pulse)
5) Lux Converter: Translates raw ADC voltages into human-readable Lux units through integer-based scaling. It utilizes a sequential Double Dabble algorithm to convert binary results into BCD format, making it easy to drive individual digits on a decimal display.
-Key Inputs: adc_out, data_ready
-Key Outputs: seg_thousands, seg_hundreds, seg_tens, seg_ones (4-bit BCD digits)
6) Morse Decoder: A tree-based decoder that interprets the timing of the light_on signal to identify dots, dashes, and spaces. It traverses a pre-defined binary tree memory to map pulse sequences to their corresponding ASCII characters or numbers.
-Key Inputs: start, light_on
-Key Outputs: ascii_char (8-bit ASCII result), char_ready (pulse when a character is decoded)
7) LED Bar Driver: Provides a real-time "volume bar" visualization of the light intensity. It maps the light_diff value to a 10-LED array, allowing the user to visually confirm the strength of the incoming light signal before it is processed as Morse code.
-Key Inputs: light_diff
-Key Outputs: led_out (10-bit vector mapped on physical LEDs)
8) Seven Segment Display: The primary output interface that manages eight different displays. Depending on the selected mode, it will either show the current Lux intensity (prefixed with "L") or a scrolling line of decoded Morse characters (prefixed with "M").
-Key Inputs: seg_mode, ascii_char, seg_ones, seg_tens, seg_hundreds, seg_thousands
-Key Outputs: ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0 (8-bit patterns for each display anode)
9) Serial Peripheral Interface: Facilitates high-speed, full-duplex communication between the FPGA and external digital peripherals. It manages the serialization of data bits and ensures synchronous timing between the Master and Slave devices using a shared clock.
-Key Inputs: flat_data (flatten 72-pin outputs including led_out and ss7-ss0)
-Key Outputs: mosi (Master Out Slave In), shift_clock (serial clock), seri_ready (pulse when general outputs are ready)

## How to test

SoC Button Controls
1) Kickstart SoC: Hold Push Button
2) Zero Processing Thresholds: Press Blank Button - Blanking sets the surrounding light environment as the baseline Lux level, then measures the brightness, or decodes the light signal from thereon.
3) Toggle Output Mode: Hold Blank and Press Push - Switches between "Lux" (default) and "Morse" mode
=> Lux: Modifying the light environment and letting the digital outputs measure
=> Morse: Ideally, use a flashlight to send a Morse Code combination (dot/dash) for each letter. To send a dot, shine the light on the photodiode, wait until the LED bar lights up, and immediately turn off the flashlight. To send a dash, shine the light, when the LED bar lights up, wait for a longer period (~8 seconds) before turning off the flashlight. To send the next dot or dash, wait for the LED bar to dim down and immediately re-illuminate the flashlight. Otherwise, turn off the flashlight and wait until the letter is decoded on the display board.
4) Shutdown SoC: Hold Push Button again

## External hardware

Photodiode, Transimpedance Amplifier (TIA - Op-Amp), Sample-and-Hold Circuit, Comparator, R-2R Ladder
