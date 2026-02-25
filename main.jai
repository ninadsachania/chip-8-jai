#import "Basic";
#import "File";
#import "Math"; // For S32_MAX.

rl :: #import "raylib";

TARGET_FPS :: 60;
INSTRUCTION_PER_SECOND :: 600;
INSTRUCTIONS_PER_FRAME :: INSTRUCTION_PER_SECOND / TARGET_FPS;

// Stack.
stack: [16]u16;
stack_pointer := -1;

// Memory.
mem: [4096]u8;

// Program counter.
pc: u16 = 0x200;

// Index register.
ir: u16 = 0x0;

// General purpose registers.
registers: [16]u8;

vf_register_index := registers.count - 1;

// Display.
W :: 64;
H :: 32;
BACKGROUND_COLOR :: rl.BLACK;
FOREGROUND_COLOR :: rl.GREEN;
display: [H][W]u8;

should_break := false; // Display quirk nonsense.

// Font.
font_base_address: u16 = 0x0;

// Timers.
sound_timer: u8 = 0x0;
delay_timer: u8 = 0x0;

// Keypad.
keypad: [16]bool;
any_key_pressed := false;
key: u8 = 0xFF;

// Sound stuff.
SAMPLE_RATE :: 44100;
SAMPLE_SIZE :: 32;
NUM_CHANNELS :: 1;
FREQUENCY :: 440.0;
AMPLITUDE :: 0.2;

// @Refactor! I am not sure this is correct way to do it.
read_rom :: (filename: string) -> []u8, bool {
    rom: [..]u8;

    contents, success := read_entire_file(filename);

    if !success {
        return rom, false;
    }

    for 0..contents.count-1 {
        array_add(*rom, contents.data[it]);
    }

    return rom, true;
}

clear_screen :: () {
    // @Refactor. There is a better way to do this in Jai. MUST BE!
    for i: 0..display.count-1 {
        for j: 0..display[i].count-1 {
            display[i][j] = 0x0;
        } 
    }
}

init_font :: () {
    font_data := []u8.[
        u8.[0xF0, 0x90, 0x90, 0x90, 0xF0], // 0
        u8.[0x20, 0x60, 0x20, 0x20, 0x70], // 1
        u8.[0xF0, 0x10, 0xF0, 0x80, 0xF0], // 2
        u8.[0xF0, 0x10, 0xF0, 0x10, 0xF0], // 3
        u8.[0x90, 0x90, 0xF0, 0x10, 0x10], // 4
        u8.[0xF0, 0x80, 0xF0, 0x10, 0xF0], // 5
        u8.[0xF0, 0x80, 0xF0, 0x90, 0xF0], // 6
        u8.[0xF0, 0x10, 0x20, 0x40, 0x40], // 7
        u8.[0xF0, 0x90, 0xF0, 0x90, 0xF0], // 8
        u8.[0xF0, 0x90, 0xF0, 0x10, 0xF0], // 9
        u8.[0xF0, 0x90, 0xF0, 0x90, 0x90], // A
        u8.[0xE0, 0x90, 0xE0, 0x90, 0xE0], // B
        u8.[0xF0, 0x80, 0x80, 0x80, 0xF0], // C
        u8.[0xE0, 0x90, 0x90, 0x90, 0xE0], // D
        u8.[0xF0, 0x80, 0xF0, 0x80, 0xF0], // E
        u8.[0xF0, 0x80, 0xF0, 0x80, 0x80], // F
    ];

    // @Refactor.
    for i: 0..font_data.count-1 {
        addr := font_base_address + (cast(u16) (i) * 5);

        for j: 0..font_data[i].count-1 {
            mem[addr + cast(u16) j] = font_data[i][j];
        }
    }
}

handle_input :: () {
    if rl.IsKeyPressed(.KEY_ONE)   then keypad[0x1] = true;
    if rl.IsKeyPressed(.KEY_TWO)   then keypad[0x2] = true;
    if rl.IsKeyPressed(.KEY_THREE) then keypad[0x3] = true;
    if rl.IsKeyPressed(.KEY_FOUR)  then keypad[0xC] = true;
    if rl.IsKeyPressed(.KEY_Q)     then keypad[0x4] = true;
    if rl.IsKeyPressed(.KEY_W)     then keypad[0x5] = true;
    if rl.IsKeyPressed(.KEY_E)     then keypad[0x6] = true;
    if rl.IsKeyPressed(.KEY_R)     then keypad[0xD] = true;
    if rl.IsKeyPressed(.KEY_A)     then keypad[0x7] = true;
    if rl.IsKeyPressed(.KEY_S)     then keypad[0x8] = true;
    if rl.IsKeyPressed(.KEY_D)     then keypad[0x9] = true;
    if rl.IsKeyPressed(.KEY_F)     then keypad[0xE] = true;
    if rl.IsKeyPressed(.KEY_Z)     then keypad[0xA] = true;
    if rl.IsKeyPressed(.KEY_X)     then keypad[0x0] = true;
    if rl.IsKeyPressed(.KEY_C)     then keypad[0xB] = true;
    if rl.IsKeyPressed(.KEY_V)     then keypad[0xF] = true;


    if rl.IsKeyReleased(.KEY_ONE)   then keypad[0x1] = false;
    if rl.IsKeyReleased(.KEY_TWO)   then keypad[0x2] = false;
    if rl.IsKeyReleased(.KEY_THREE) then keypad[0x3] = false;
    if rl.IsKeyReleased(.KEY_FOUR)  then keypad[0xC] = false;
    if rl.IsKeyReleased(.KEY_Q)     then keypad[0x4] = false;
    if rl.IsKeyReleased(.KEY_W)     then keypad[0x5] = false;
    if rl.IsKeyReleased(.KEY_E)     then keypad[0x6] = false;
    if rl.IsKeyReleased(.KEY_R)     then keypad[0xD] = false;
    if rl.IsKeyReleased(.KEY_A)     then keypad[0x7] = false;
    if rl.IsKeyReleased(.KEY_S)     then keypad[0x8] = false;
    if rl.IsKeyReleased(.KEY_D)     then keypad[0x9] = false;
    if rl.IsKeyReleased(.KEY_F)     then keypad[0xE] = false;
    if rl.IsKeyReleased(.KEY_Z)     then keypad[0xA] = false;
    if rl.IsKeyReleased(.KEY_X)     then keypad[0x0] = false;
    if rl.IsKeyReleased(.KEY_C)     then keypad[0xB] = false;
    if rl.IsKeyReleased(.KEY_V)     then keypad[0xF] = false;
}

step :: () {
    //
    // Fetch.
    //
    ins: u16 = (cast(u16) (mem[pc])) << 8 | (cast(u16) (mem[pc + 1]));
    if (ins >> 12) == 0xD then should_break = true;
    pc += 2;

    opcode := (ins & 0xF000) >> 12;

    
    x_index := (cast(u16) (ins & 0x0F00)) >> 8;
    y_index := (cast(u16) (ins & 0x00F0)) >> 4;
    
    NNN := cast(u16) (ins & 0x0FFF);
    NN  := cast(u8)  (ins & 0x00FF);

    //
    // Decode & execute.
    //
    if ins == 0x00E0 {
        clear_screen();
    } else if ins == 0x00EE {
            pc = stack[stack_pointer];
            stack_pointer -= 1;
    } else if opcode == 0x1 {
        pc = NNN;
    } else if opcode == 0x2 {
        stack_pointer += 1;
        stack[stack_pointer] = pc;

        pc = NNN;
    } else if opcode == 0x3 {
        if registers[x_index] == NN {
            pc += 2;
        }
    } else if opcode == 0x4 {
        if registers[x_index] != NN {
            pc += 2;
        }
    } else if opcode == 0x5 {
        if registers[x_index] == registers[y_index] {
            pc += 2;
        }
    } else if opcode == 0x6 {
        registers[x_index] = NN;
    } else if opcode == 0x7 {
            registers[x_index] += NN;
    } else if opcode == 0x8 {
        op := ins & 0x000F;

        if op == 0x0 {
            registers[x_index] = registers[y_index];
        } else if op == 0x1 {
            registers[x_index] |= registers[y_index];
            registers[vf_register_index] = 0x0;
        } else if op == 0x2 {
            registers[x_index] &= registers[y_index];
            registers[vf_register_index] = 0x0;
        } else if op == 0x3 {
            registers[x_index] ^= registers[y_index];
            registers[vf_register_index] = 0x0;
        } else if op == 0x4 {
            x: u16 = registers[x_index];
            y: u16 = registers[y_index];

            registers[x_index] = (registers[x_index] + registers[y_index]);

            // Check for overflow.
            if (x + y) > 255 {
                registers[vf_register_index] = 0x1;
            } else {
                registers[vf_register_index] = 0x0;
            }
        } else if op == 0x5 {
            x: u8 = registers[x_index];
            y: u8 = registers[y_index];

            registers[x_index] -= registers[y_index];

            // Check for underflow.
            if x >= y {
                registers[vf_register_index] = 0x1;
            } else {
                registers[vf_register_index] = 0x0;
            }
        } else if op == 0x6 {
            y: u8 = registers[y_index];

            registers[x_index] = y >> 1;

            registers[vf_register_index] = y & 0x1;
        } else if op == 0x7 {
            x: u8 = registers[x_index];
            y: u8 = registers[y_index];

            registers[x_index] = registers[y_index] - registers[x_index];

            // Check for underflow.
            if y >= x {
                registers[vf_register_index] = 0x1;
            } else {
                registers[vf_register_index] = 0x0;
            }
        } else if op == 0xE {
            y: u8 = registers[y_index];

            registers[x_index] = y << 1;

            if (y & (1 << 7)) > 0 {
                registers[vf_register_index] = 0x1;
            } else {
                registers[vf_register_index] = 0x0;
            }
        }
    } else if opcode == 0x9 {
        if registers[x_index] != registers[y_index] {
            pc += 2;
        }
    } else if opcode == 0xA {
        ir = NNN;
    } else if opcode == 0xB {
        pc = NNN + (cast(u16) registers[0]); // @Refactor: should have an enum for register indexes?
    } else if opcode == 0xC {
        registers[x_index] = cast(u8) (NN & rl.GetRandomValue(0, S32_MAX));
    } else if opcode == 0xD {
        // @Bug?
        x := (cast(int) (registers[x_index])) % W;
        y := (cast(int) (registers[y_index])) % H;
        N := ins & 0x000F;

        registers[vf_register_index] = 0x0;

        for i: 0..N-1 {
            row := mem[(cast(s64) ir) + i];

            row_pixels: [8]u8;
            for < idx: 0..7 {
                if (row & (1 << idx)) > 0 {
                    row_pixels[7 - idx] = 1;
                } else {
                    row_pixels[7 - idx] = 0;
                }
            }

            if y + i >= H {
                break;
            }

            for j: 0..7 {
                if x + j >= W {
                    break;
                }
                row_pixel := row_pixels[j];

                assert(row_pixel == 0 || row_pixel == 1, "row_pixel value is something other 1 or 0.");

                if row_pixel == 0x1 && display[y + i][x + j] == 0x1 {
                    display[y + i][x + j] = 0x0;
                    registers[vf_register_index] = 0x1;
                } else if row_pixel == 0x1 && display[y + i][x + j] == 0x0 {
                    display[y + i][x + j] = 0x1;
                }
            }
        }
    } else if opcode == 0xE {
        vx := x_index;

        if NN == 0x9E {
            if keypad[registers[vx]] then pc += 2; 
        } else if NN == 0xA1 {
            if !keypad[registers[vx]] pc += 2; 
        } else {
            assert(false, "This should not happen");
        }
    } else if opcode == 0xF {
        op := NN;

        if op == 0x07 {
            registers[x_index] = delay_timer;
        } else if op == 0x0A {
            vx := x_index;

            i: u8 = 0;
            while key == 0xFF && i < keypad.count {
                if keypad[i] {
                    key = i;
                    any_key_pressed = true;
                    break;
                }

                i += 1;
            }

            if !any_key_pressed {
                pc -= 2;
            } else {
                if keypad[key] {
                    pc -= 2;
                } else {
                    registers[vx] = key;
                    key = 0xFF;
                    any_key_pressed = false;
                }
            }

        } else if op == 0x15 {
            delay_timer = registers[x_index];
        } else if op == 0x18 {
            sound_timer = registers[x_index];
        } else if op == 0x1E {
            ir += cast(u16) registers[x_index];
        } else if op == 0x29 {
            char := registers[x_index];
            assert(char >= 0x0 && char <= 0xF, "Character is not between 0x0 and 0xF");

            ir = (cast(u16) char) * 5;
        } else if op == 0x33 {
            number := registers[x_index];

            // @Bug?
            mem[ir + 0] = cast(u8) ((number % 1000) / 100);
            mem[ir + 1] = cast(u8) ((number % 100)  / 10);
            mem[ir + 2] = cast(u8) (number % 10);

        } else if op == 0x55 {
            n := x_index;
            for i: 0..n {
                mem[ir] = registers[i];
                ir += 1;
            }
        } else if op == 0x65 {
            n := x_index;
            for i: 0..n {
                registers[i] = mem[ir];
                ir += 1;
            }
        } else {
            assert(false, "This should not happen");
        }
    } else {
        assert(false, "ins = %, pc = %", formatInt(ins, base = 16), formatInt(pc - 2, base = 16));
    }

}


main :: () {
    init_font();

    args := get_command_line_arguments();
    if args.count != 2 {
        print("Usage: % <rom>\n", args[0]);
        exit(1);
    }

    rom := args[1];

    // TODO(njs): Add more checks.

    program, success := read_rom(rom);
    if !success {
        exit(1);
    }

    // Load the program.
    for program {
        mem[it_index + 0x200] = it;
    }

    rl.InitWindow(W * 10, H * 10, "CHIP-8");
    rl.SetTargetFPS(TARGET_FPS);

    rl.InitAudioDevice();

    audio_stream := rl.LoadAudioStream(SAMPLE_RATE, SAMPLE_RATE, NUM_CHANNELS);
    rl.SetAudioStreamCallback(audio_stream, (buffer_data: *void, frames: u32) #c_call {
            samples: []float;
            samples.data = cast(*float) buffer_data;
            samples.count = frames;

            push_context {
                for i: 0..samples.count-1 {
                    samples[i] = AMPLITUDE * sin(FREQUENCY * 2.0 * (cast(float) i / cast(float) SAMPLE_RATE) * PI);
                }
            }
        }
    );
    rl.PlayAudioStream(audio_stream);

    while !rl.WindowShouldClose() {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        handle_input();

        for i: 0..display.count-1 {
            for j: 0..display[i].count-1 {
                if display[i][j] == 1 {
                    rl.DrawRectangle(cast(s32) (j * 10), cast(s32) (i * 10), 10, 10, FOREGROUND_COLOR);
                } else {
                    rl.DrawRectangle(cast(s32) (j * 10), cast(s32) (i * 10), 10, 10, BACKGROUND_COLOR);
                }
            }
        }

        for 0..INSTRUCTIONS_PER_FRAME-1 {
            step();

            if should_break {
                should_break = false;
                break;
            }
        }

        if delay_timer > 0 then delay_timer -= 1;
        if sound_timer > 0 then sound_timer -= 1;

        if sound_timer > 0 {
            rl.ResumeAudioStream(audio_stream);
        } else {
            rl.PauseAudioStream(audio_stream);
        }

        rl.EndDrawing();
    }

    rl.StopAudioStream(audio_stream);
    rl.UnloadAudioStream(audio_stream);
    rl.CloseAudioDevice();
    rl.CloseWindow();
}
