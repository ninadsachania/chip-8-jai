#import "Basic";
#import "File";
#import "Math"; // For S32_MAX.

rl :: #import "raylib";

Chip8 :: struct {
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

    // Display quirk nonsense.
    should_break := false;

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
}

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

clear_screen :: (ctx: *Chip8) {
    // @Refactor. There is a better way to do this in Jai. MUST BE!
    for i: 0..ctx.display.count-1 {
        for j: 0..ctx.display[i].count-1 {
            ctx.display[i][j] = 0x0;
        } 
    }
}

init_font :: (ctx: *Chip8) {
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
        addr := ctx.font_base_address + (cast(u16) (i) * 5);

        for j: 0..font_data[i].count-1 {
            ctx.mem[addr + cast(u16) j] = font_data[i][j];
        }
    }
}

handle_input :: (ctx: *Chip8) {
    if rl.IsKeyPressed(.KEY_ONE)   then ctx.keypad[0x1] = true;
    if rl.IsKeyPressed(.KEY_TWO)   then ctx.keypad[0x2] = true;
    if rl.IsKeyPressed(.KEY_THREE) then ctx.keypad[0x3] = true;
    if rl.IsKeyPressed(.KEY_FOUR)  then ctx.keypad[0xC] = true;
    if rl.IsKeyPressed(.KEY_Q)     then ctx.keypad[0x4] = true;
    if rl.IsKeyPressed(.KEY_W)     then ctx.keypad[0x5] = true;
    if rl.IsKeyPressed(.KEY_E)     then ctx.keypad[0x6] = true;
    if rl.IsKeyPressed(.KEY_R)     then ctx.keypad[0xD] = true;
    if rl.IsKeyPressed(.KEY_A)     then ctx.keypad[0x7] = true;
    if rl.IsKeyPressed(.KEY_S)     then ctx.keypad[0x8] = true;
    if rl.IsKeyPressed(.KEY_D)     then ctx.keypad[0x9] = true;
    if rl.IsKeyPressed(.KEY_F)     then ctx.keypad[0xE] = true;
    if rl.IsKeyPressed(.KEY_Z)     then ctx.keypad[0xA] = true;
    if rl.IsKeyPressed(.KEY_X)     then ctx.keypad[0x0] = true;
    if rl.IsKeyPressed(.KEY_C)     then ctx.keypad[0xB] = true;
    if rl.IsKeyPressed(.KEY_V)     then ctx.keypad[0xF] = true;


    if rl.IsKeyReleased(.KEY_ONE)   then ctx.keypad[0x1] = false;
    if rl.IsKeyReleased(.KEY_TWO)   then ctx.keypad[0x2] = false;
    if rl.IsKeyReleased(.KEY_THREE) then ctx.keypad[0x3] = false;
    if rl.IsKeyReleased(.KEY_FOUR)  then ctx.keypad[0xC] = false;
    if rl.IsKeyReleased(.KEY_Q)     then ctx.keypad[0x4] = false;
    if rl.IsKeyReleased(.KEY_W)     then ctx.keypad[0x5] = false;
    if rl.IsKeyReleased(.KEY_E)     then ctx.keypad[0x6] = false;
    if rl.IsKeyReleased(.KEY_R)     then ctx.keypad[0xD] = false;
    if rl.IsKeyReleased(.KEY_A)     then ctx.keypad[0x7] = false;
    if rl.IsKeyReleased(.KEY_S)     then ctx.keypad[0x8] = false;
    if rl.IsKeyReleased(.KEY_D)     then ctx.keypad[0x9] = false;
    if rl.IsKeyReleased(.KEY_F)     then ctx.keypad[0xE] = false;
    if rl.IsKeyReleased(.KEY_Z)     then ctx.keypad[0xA] = false;
    if rl.IsKeyReleased(.KEY_X)     then ctx.keypad[0x0] = false;
    if rl.IsKeyReleased(.KEY_C)     then ctx.keypad[0xB] = false;
    if rl.IsKeyReleased(.KEY_V)     then ctx.keypad[0xF] = false;
}

step :: (ctx: *Chip8) {
    //
    // Fetch.
    //
    ins: u16 = (cast(u16) (ctx.mem[ctx.pc])) << 8 | (cast(u16) (ctx.mem[ctx.pc + 1]));
    if (ins >> 12) == 0xD then ctx.should_break = true;
    ctx.pc += 2;

    opcode := (ins & 0xF000) >> 12;

    
    x_index := (cast(u16) (ins & 0x0F00)) >> 8;
    y_index := (cast(u16) (ins & 0x00F0)) >> 4;
    
    NNN := cast(u16) (ins & 0x0FFF);
    NN  := cast(u8)  (ins & 0x00FF);

    //
    // Decode & execute.
    //
    if ins == 0x00E0 {
        clear_screen(ctx);
    } else if ins == 0x00EE {
            ctx.pc = ctx.stack[ctx.stack_pointer];
            ctx.stack_pointer -= 1;
    } else if opcode == 0x1 {
        ctx.pc = NNN;
    } else if opcode == 0x2 {
        ctx.stack_pointer += 1;
        ctx.stack[ctx.stack_pointer] = ctx.pc;

        ctx.pc = NNN;
    } else if opcode == 0x3 {
        if ctx.registers[x_index] == NN {
            ctx.pc += 2;
        }
    } else if opcode == 0x4 {
        if ctx.registers[x_index] != NN {
            ctx.pc += 2;
        }
    } else if opcode == 0x5 {
        if ctx.registers[x_index] == ctx.registers[y_index] {
            ctx.pc += 2;
        }
    } else if opcode == 0x6 {
        ctx.registers[x_index] = NN;
    } else if opcode == 0x7 {
            ctx.registers[x_index] += NN;
    } else if opcode == 0x8 {
        op := ins & 0x000F;

        if op == 0x0 {
            ctx.registers[x_index] = ctx.registers[y_index];
        } else if op == 0x1 {
            ctx.registers[x_index] |= ctx.registers[y_index];
            ctx.registers[ctx.vf_register_index] = 0x0;
        } else if op == 0x2 {
            ctx.registers[x_index] &= ctx.registers[y_index];
            ctx.registers[ctx.vf_register_index] = 0x0;
        } else if op == 0x3 {
            ctx.registers[x_index] ^= ctx.registers[y_index];
            ctx.registers[ctx.vf_register_index] = 0x0;
        } else if op == 0x4 {
            x: u16 = ctx.registers[x_index];
            y: u16 = ctx.registers[y_index];

            ctx.registers[x_index] = (ctx.registers[x_index] + ctx.registers[y_index]);

            // Check for overflow.
            if (x + y) > 255 {
                ctx.registers[ctx.vf_register_index] = 0x1;
            } else {
                ctx.registers[ctx.vf_register_index] = 0x0;
            }
        } else if op == 0x5 {
            x: u8 = ctx.registers[x_index];
            y: u8 = ctx.registers[y_index];

            ctx.registers[x_index] -= ctx.registers[y_index];

            // Check for underflow.
            if x >= y {
                ctx.registers[ctx.vf_register_index] = 0x1;
            } else {
                ctx.registers[ctx.vf_register_index] = 0x0;
            }
        } else if op == 0x6 {
            y: u8 = ctx.registers[y_index];

            ctx.registers[x_index] = y >> 1;

            ctx.registers[ctx.vf_register_index] = y & 0x1;
        } else if op == 0x7 {
            x: u8 = ctx.registers[x_index];
            y: u8 = ctx.registers[y_index];

            ctx.registers[x_index] = ctx.registers[y_index] - ctx.registers[x_index];

            // Check for underflow.
            if y >= x {
                ctx.registers[ctx.vf_register_index] = 0x1;
            } else {
                ctx.registers[ctx.vf_register_index] = 0x0;
            }
        } else if op == 0xE {
            y: u8 = ctx.registers[y_index];

            ctx.registers[x_index] = y << 1;

            if (y & (1 << 7)) > 0 {
                ctx.registers[ctx.vf_register_index] = 0x1;
            } else {
                ctx.registers[ctx.vf_register_index] = 0x0;
            }
        }
    } else if opcode == 0x9 {
        if ctx.registers[x_index] != ctx.registers[y_index] {
            ctx.pc += 2;
        }
    } else if opcode == 0xA {
        ctx.ir = NNN;
    } else if opcode == 0xB {
        ctx.pc = NNN + (cast(u16) ctx.registers[0]); // @Refactor: should have an enum for register indexes?
    } else if opcode == 0xC {
        ctx.registers[x_index] = cast(u8) (NN & rl.GetRandomValue(0, S32_MAX));
    } else if opcode == 0xD {
        // @Bug?
        x := (cast(int) (ctx.registers[x_index])) % ctx.W;
        y := (cast(int) (ctx.registers[y_index])) % ctx.H;
        N := ins & 0x000F;

        ctx.registers[ctx.vf_register_index] = 0x0;

        for i: 0..N-1 {
            row := ctx.mem[(cast(s64) ctx.ir) + i];

            row_pixels: [8]u8;
            for < idx: 0..7 {
                if (row & (1 << idx)) > 0 {
                    row_pixels[7 - idx] = 1;
                } else {
                    row_pixels[7 - idx] = 0;
                }
            }

            if y + i >= ctx.H {
                break;
            }

            for j: 0..7 {
                if x + j >= ctx.W {
                    break;
                }
                row_pixel := row_pixels[j];

                assert(row_pixel == 0 || row_pixel == 1, "row_pixel value is something other 1 or 0.");

                if row_pixel == 0x1 && ctx.display[y + i][x + j] == 0x1 {
                    ctx.display[y + i][x + j] = 0x0;
                    ctx.registers[ctx.vf_register_index] = 0x1;
                } else if row_pixel == 0x1 && ctx.display[y + i][x + j] == 0x0 {
                    ctx.display[y + i][x + j] = 0x1;
                }
            }
        }
    } else if opcode == 0xE {
        vx := x_index;

        if NN == 0x9E {
            if ctx.keypad[ctx.registers[vx]] then ctx.pc += 2; 
        } else if NN == 0xA1 {
            if !ctx.keypad[ctx.registers[vx]] ctx.pc += 2; 
        } else {
            assert(false, "This should not happen");
        }
    } else if opcode == 0xF {
        op := NN;

        if op == 0x07 {
            ctx.registers[x_index] = ctx.delay_timer;
        } else if op == 0x0A {
            vx := x_index;

            i: u8 = 0;
            while ctx.key == 0xFF && i < ctx.keypad.count {
                if ctx.keypad[i] {
                    ctx.key = i;
                    ctx.any_key_pressed = true;
                    break;
                }

                i += 1;
            }

            if !ctx.any_key_pressed {
                ctx.pc -= 2;
            } else {
                if ctx.keypad[ctx.key] {
                    ctx.pc -= 2;
                } else {
                    ctx.registers[vx] = ctx.key;
                    ctx.key = 0xFF;
                    ctx.any_key_pressed = false;
                }
            }

        } else if op == 0x15 {
            ctx.delay_timer = ctx.registers[x_index];
        } else if op == 0x18 {
            ctx.sound_timer = ctx.registers[x_index];
        } else if op == 0x1E {
            ctx.ir += cast(u16) ctx.registers[x_index];
        } else if op == 0x29 {
            char := ctx.registers[x_index];
            assert(char >= 0x0 && char <= 0xF, "Character is not between 0x0 and 0xF");

            ctx.ir = (cast(u16) char) * 5;
        } else if op == 0x33 {
            number := ctx.registers[x_index];

            // @Bug?
            ctx.mem[ctx.ir + 0] = cast(u8) ((number % 1000) / 100);
            ctx.mem[ctx.ir + 1] = cast(u8) ((number % 100)  / 10);
            ctx.mem[ctx.ir + 2] = cast(u8) (number % 10);

        } else if op == 0x55 {
            n := x_index;
            for i: 0..n {
                ctx.mem[ctx.ir] = ctx.registers[i];
                ctx.ir += 1;
            }
        } else if op == 0x65 {
            n := x_index;
            for i: 0..n {
                ctx.registers[i] = ctx.mem[ctx.ir];
                ctx.ir += 1;
            }
        } else {
            assert(false, "This should not happen");
        }
    } else {
        assert(false, "ins = %, pc = %", formatInt(ins, base = 16), formatInt(ctx.pc - 2, base = 16));
    }

}

load_program :: (program: []u8, ctx: *Chip8) {
    for program {
        ctx.mem[it_index + 0x200] = it;
    }
}

main :: () {
    ctx: Chip8;

    init_font(*ctx);

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

    load_program(program, *ctx);

    rl.InitWindow(ctx.W * 10, ctx.H * 10, "CHIP-8");
    rl.SetTargetFPS(ctx.TARGET_FPS);

    rl.InitAudioDevice();

    audio_stream := rl.LoadAudioStream(ctx.SAMPLE_RATE, ctx.SAMPLE_RATE, ctx.NUM_CHANNELS);
    rl.SetAudioStreamCallback(audio_stream, (buffer_data: *void, frames: u32) #c_call {
            samples: []float;
            samples.data = cast(*float) buffer_data;
            samples.count = frames;

            push_context {
                for i: 0..samples.count-1 {
                    samples[i] = ctx.AMPLITUDE * sin(ctx.FREQUENCY * 2.0 * (cast(float) i / cast(float) ctx.SAMPLE_RATE) * PI);
                }
            }
        }
    );
    rl.PlayAudioStream(audio_stream);

    while !rl.WindowShouldClose() {
        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        handle_input(*ctx);

        for i: 0..ctx.display.count-1 {
            for j: 0..ctx.display[i].count-1 {
                if ctx.display[i][j] == 1 {
                    rl.DrawRectangle(cast(s32) (j * 10), cast(s32) (i * 10), 10, 10, ctx.FOREGROUND_COLOR);
                } else {
                    rl.DrawRectangle(cast(s32) (j * 10), cast(s32) (i * 10), 10, 10, ctx.BACKGROUND_COLOR);
                }
            }
        }

        for 0..ctx.INSTRUCTIONS_PER_FRAME-1 {
            step(*ctx);

            if ctx.should_break {
                ctx.should_break = false;
                break;
            }
        }

        if ctx.delay_timer > 0 then ctx.delay_timer -= 1;
        if ctx.sound_timer > 0 then ctx.sound_timer -= 1;

        if ctx.sound_timer > 0 {
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
