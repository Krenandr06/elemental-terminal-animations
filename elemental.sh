#!/bin/bash

function air() {
    tput civis # Hide cursor
    trap "tput cnorm; exit" INT TERM # Restore cursor on Ctrl+C

    python3 -c '
import sys, os, time, random, math

# -- Configuration --
# Characters: dots for slow air, dashes/curves for fast air
air_chars = ["~", "’", ",", ".", "°", "*", "-", "_"]

# Colors: 255=White, 195=PaleCyan, 159=LightBlue, 117=SkyBlue, 81=SteelBlue
colors = [255, 195, 159, 117, 81]

class Particle:
    def __init__(self, cols, rows, spawn_type):
        self.cols = cols
        self.rows = rows
        self.type = spawn_type 
        self.age = 0
        
        # -- Velocity Tiers --
        # 1=Lazy (Slow, wavy), 2=Breeze (Normal), 3=Gale (Fast, straight)
        self.speed_tier = random.choices([1, 2, 3], weights=[0.4, 0.4, 0.2])[0]

        # Base multiplier based on tier
        if self.speed_tier == 1:
            speed_mult = random.uniform(0.3, 0.8)
            self.max_age = random.randint(60, 100)
            self.char = random.choice([".", ",", "°"])
            self.amp = random.uniform(1.0, 2.5) # High wobble
        elif self.speed_tier == 2:
            speed_mult = random.uniform(1.0, 1.8)
            self.max_age = random.randint(40, 80)
            self.char = random.choice(["~", "’", "*"])
            self.amp = random.uniform(0.5, 1.5) # Med wobble
        else: # Gale
            speed_mult = random.uniform(2.5, 4.0)
            self.max_age = random.randint(20, 40)
            self.char = random.choice(["-", "_"])
            self.amp = random.uniform(0.1, 0.5) # Low wobble (cuts through)

        self.color = random.choice(colors)
        self.freq = random.uniform(0.1, 0.3)
        self.phase = random.uniform(0, math.pi*2)

        # -- Initialization based on Type --
        if self.type == "LEFT":
            self.x = 0
            self.y = random.randint(0, rows // 2)
            self.vx = 1.0 * speed_mult
            self.vy = random.uniform(-0.1, 0.1)

        elif self.type == "RIGHT":
            self.x = cols - 1
            self.y = random.randint(0, rows // 2)
            self.vx = -1.0 * speed_mult
            self.vy = random.uniform(-0.1, 0.1)

        elif self.type == "BL_CORNER": # Bottom Left Updraft
            self.x = random.randint(0, cols // 4)
            self.y = rows - 1
            self.vx = 0.8 * speed_mult
            self.vy = random.uniform(-0.8, -0.4) # Upward

        elif self.type == "BR_CORNER": # Bottom Right Updraft
            self.x = random.randint(cols - (cols // 4), cols - 1)
            self.y = rows - 1
            self.vx = -0.8 * speed_mult
            self.vy = random.uniform(-0.8, -0.4) # Upward

        elif self.type == "SPIRAL":
            self.center_x = random.randint(cols//3, 2*(cols//3))
            self.center_y = random.randint(rows//3, 2*(rows//3))
            self.radius = 0.5
            self.angle = random.uniform(0, math.pi * 2)
            self.angular_vel = 0.4
            self.radial_vel = 0.2
            self.char = "@" 
            self.max_age = 25
            # Reset visual properties for spirals to stand out
            self.vx, self.vy = 0, 0
            self.amp = 0

    def update(self):
        self.age += 1
        
        if self.type == "SPIRAL":
            self.angle += self.angular_vel
            self.radius += self.radial_vel
            self.x = self.center_x + math.cos(self.angle) * self.radius * 2.0 
            self.y = self.center_y + math.sin(self.angle) * self.radius
        else:
            self.x += self.vx
            self.y += self.vy
            # Add the sine wave wobble to the Y position for rendering
            self.draw_offset_y = math.sin(self.x * self.freq + self.phase) * self.amp

    def is_alive(self):
        margin = 5
        in_bounds = (-margin <= self.x < self.cols + margin) and (-margin <= self.y < self.rows + margin)
        return in_bounds and self.age < self.max_age

def run():
    try:
        try: cols, rows = os.get_terminal_size()
        except: cols, rows = 80, 24

        particles = []
        fps = 20
        frame_dur = 1.0 / fps

        while True:
            start_time = time.time()
            
            # -- Spawning Logic --
            
            # 1. Left/Right Gusts (Standard)
            if random.random() < 0.2: particles.append(Particle(cols, rows, "LEFT"))
            if random.random() < 0.2: particles.append(Particle(cols, rows, "RIGHT"))

            # 2. Updrafts (REDUCED FREQUENCY: 0.15 -> 0.04)
            if random.random() < 0.04: particles.append(Particle(cols, rows, "BL_CORNER"))
            if random.random() < 0.04: particles.append(Particle(cols, rows, "BR_CORNER"))

            # 3. ATLA Spiral (Rare)
            if random.random() < 0.03: 
                center_x = random.randint(20, cols-20)
                center_y = random.randint(5, rows-5)
                for i in range(3):
                    p = Particle(cols, rows, "SPIRAL")
                    p.center_x = center_x
                    p.center_y = center_y
                    p.angle = (math.pi * 2 / 3) * i 
                    particles.append(p)

            # -- Render --
            grid = [" "] * (cols * rows)
            active_particles = []
            
            for p in particles:
                p.update()
                
                # Calculate integer grid coordinates
                if p.type == "SPIRAL":
                    d_x, d_y = int(p.x), int(p.y)
                else:
                    d_x = int(p.x)
                    d_y = int(p.y + p.draw_offset_y)

                if 0 <= d_x < cols and 0 <= d_y < rows:
                    idx = d_y * cols + d_x
                    grid[idx] = f"\033[38;5;{p.color}m{p.char}"
                
                if p.is_alive():
                    active_particles.append(p)
            
            particles = active_particles

            output = ["\033[H"] 
            for y in range(rows - 1):
                output.append("".join(grid[y*cols : (y+1)*cols]))
            
            sys.stdout.write("\n".join(output))
            sys.stdout.flush()

            elapsed = time.time() - start_time
            time.sleep(max(0, frame_dur - elapsed))

    except KeyboardInterrupt:
        pass

run()
'
    tput cnorm 
}

# Placeholder for earth
function earth() {
    echo "🪨 Earth is planned but not yet built."
}

function fire() {
    tput civis # Hide cursor
    python3 -c '
import sys, os, time, math

# -- 1. THE ART --
braille_raw = r"""
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣽⣻⣷⣤⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⢾⣟⡷⣿⢿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣟⣯⣿⣽⢯⣟⡿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⡿⣟⣻⢿⣿⣟⡿⣧⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⣤⠀⠀⠀⠀⠀⠀⠀⢀⠀⠀⢀⣼⣿⣟⡿⡜⣭⢻⣾⡿⣽⡾⣽⢿⣆⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⣰⣿⡄⠀⠀⠀⠀⠀⢠⣿⣿⢿⡿⣟⣷⣿⣱⣛⣬⠳⡽⣿⣯⣟⣯⣿⣿⡆⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢠⣾⣿⣿⠁⠀⠀⠀⠀⢠⣿⡿⣽⣯⢿⣻⣾⢧⢳⣜⡲⢏⡳⡽⣷⣿⡿⣷⣿⣿⡀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⡀⣿⣿⣽⠏⠀⠀⠀⠀⠀⣿⡿⣽⣷⣻⣟⣿⡱⣎⡗⢮⡵⣋⢷⣩⢿⣿⣿⣽⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀
⠀⠀⢿⣿⡿⠋⠀⠀⠀⠀⠀⣸⣿⣻⣽⡾⣷⡟⢶⣙⠶⣩⢗⡺⢭⡖⡳⣎⣿⡿⣿⣻⢾⡇⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠛⠉⢈⠀⠀⠀⠀⠀⠀⣿⡿⣽⣳⣿⡟⣼⢣⢏⡾⣱⢫⡵⢫⣜⡳⢵⣺⣿⢷⣻⣿⡇⠀⠀⠀⣀⠀⠀⠀
⠀⠀⠀⢀⣾⠀⠀⠀⠀⠀⢰⣿⢿⡽⣷⡿⣜⡖⣫⠮⡵⣣⠯⣜⡳⣎⢽⣚⢼⣿⣻⣽⣾⣇⠀⠀⠀⣸⡄⠀⠀
⠀⠀⣠⣿⣿⡇⠀⠀⠀⠀⢸⣿⢯⣿⣿⡱⢞⡼⣱⣋⢶⡭⢷⡹⣜⡎⣗⠮⣽⣿⢯⣷⢯⣿⢦⣀⣴⣿⣿⡄⠀
⠀⢰⣿⣟⣾⣷⡀⠀⠀⠀⣸⣿⣻⣾⢧⣛⡭⡖⣧⡿⠋⠀⢸⡱⢮⡹⡼⣹⢾⣿⢯⣷⢯⣿⣻⣟⣯⣷⢿⣷⠀
⠀⣿⣟⣾⢷⣻⢿⣶⣶⣾⡿⣯⣷⡿⣲⡍⣶⡽⠋⠀⠀⠀⢸⣱⢫⠵⣓⢧⣿⣿⣻⡽⣷⢯⣷⢿⣽⢾⣯⢿⡇
⢸⣿⣻⡾⣟⣯⣿⣞⣷⢯⣿⣳⣿⡗⢧⣞⡽⠁⠀⠀⠀⠀⢸⢧⢏⡻⣜⣣⢻⡿⣷⠿⣿⢻⣿⣻⡾⣿⣽⣻⣿
⣽⣿⣳⡿⣿⣛⣷⣿⡾⣿⣽⣿⢿⣞⡱⣾⠁⠀⠀⠀⠀⠀⢸⣏⠾⣱⢣⡝⡶⣹⢌⡳⢼⣣⣿⡿⣽⡷⣯⣷⣿
⠸⣿⣳⡿⣿⡳⣜⢎⣟⡻⢯⣤⠟⣡⣿⡇⠀⠀⠀⠀⠀⠀⠀⣯⣏⡳⢽⡸⣵⢫⡷⣭⢳⡼⣿⡿⣽⣻⢷⣻⣾
⠀⢿⡿⣽⣿⡷⣩⢞⣬⠳⣍⡳⢞⡽⣿⠁⠀⠀⠀⠀⡦⡀⠀⠻⣾⣽⠮⠛⢁⣾⡝⡖⣧⣿⣿⡽⣿⣽⣻⢿⠃
⠀⠊⣿⣟⣾⣷⡹⢎⡶⣛⡼⣩⣟⢲⣿⡀⠀⠀⠀⣸⠀⢧⠀⠀⠀⠀⠀⢀⣾⣧⢻⡜⣾⢿⡷⣿⣷⡿⣽⠏⠀
⠀⠀⠊⣿⣯⣿⣵⢫⣶⢹⡜⣷⠉⠛⠋⠁⠀⠀⢠⡇⠀⠈⡇⠀⠀⠀⠀⠘⠁⣿⠓⣾⢱⡞⣼⣿⣯⣿⠋⠀⠀
⠀⠀⠀⠈⠻⣿⣷⡭⣲⢫⢵⣻⡀⠀⠀⠀⠀⠀⡾⠀⠀⠀⠹⣄⠀⠀⡀⠀⢸⣏⠷⣎⡳⣾⣿⣿⠞⠁⠀⠀⠀
⠀⠀⠻⣤⣀⠈⣻⣷⣭⢳⡣⡟⣧⠀⠀⡎⠑⠚⠁⠀⠀⠀⠀⠈⠙⠉⢡⣶⡿⣜⢫⣖⣿⣿⠋⠁⣠⡀⠀⠀⠀
⠀⠀⠀⠘⠻⣿⣿⢿⣿⣧⣳⡝⡽⣆⠀⢳⡀⠀⠀⠀⠀⠀⠀⠀⠀⢠⣯⣿⠱⣎⣷⣿⡿⣿⢿⡿⠋⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠈⠛⢿⣾⣻⣿⣾⡳⣽⣧⡀⢳⡀⠀⠀⠀⠀⠀⠀⢠⣿⣟⣬⣿⣿⢿⣽⣻⠟⠉⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠿⠿⣷⣽⣻⣦⠙⢤⡀⠀⠀⠀⣠⣿⣿⣾⣿⠿⠟⠋⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠛⠉⠁⠀⠈⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
"""

# -- 2. CONVERSION MAP --
ascii_map = { 
    0: " ", 1: ".", 2: ":", 3: "+", 4: "*", 5: "%", 6: "#", 7: "%", 8: "@" 
}
def convert_to_ascii(text):
    converted_lines = []
    lines = text.split("\n")
    for line in lines:
        new_line = ""
        for char in line:
            if "⠀" <= char <= "⣿":
                val = ord(char) - 0x2800
                dots = bin(val).count("1")
                new_line += ascii_map.get(dots, "#")
            else:
                new_line += char
        if new_line.strip():
            converted_lines.append(new_line)
    return converted_lines

# FULL RESOLUTION GRIDS
full_lines = convert_to_ascii(braille_raw)
full_h = len(full_lines)
full_w = max(len(l) for l in full_lines)
full_grid = [l.ljust(full_w) for l in full_lines]

# COLORS
gradient_colors = [124, 160, 196, 202, 208, 214, 220, 226]
max_c_idx = len(gradient_colors) - 1

try:
    sys.stdout.write("\033[2J") # Clear
    t0 = time.time()
    
    while True:
        cols, rows = os.get_terminal_size()
        
        # SLOWDOWN FACTOR: Multiply time by 0.5 to run physics at half speed
        t = (time.time() - t0) * 0.15

        # -- 3. DYNAMIC SCALING --
        if rows < full_h:
            grid = [line[::2] for line in full_grid[::2]]
            h = len(grid)
            w = max(len(l) for l in grid)
            scale_factor = 2 
        else:
            grid = full_grid
            h = full_h
            w = full_w
            scale_factor = 1

        # -- 4. CENTERING --
        free_space = rows - h
        if free_space < 0: free_space = 0 
        
        # Center Vertical
        base_pad = free_space // 2
        
        # Gentle Bobbing (Uses slowed down "t")
        bob_amp = 1.0 if free_space > 4 else 0.2
        bob = math.sin(t * 1.5) * bob_amp
        
        pad_top = int(base_pad + bob)
        if pad_top < 0: pad_top = 0
        if (pad_top + h) > rows: pad_top = rows - h
        
        # Center Horizontal
        pad_left_len = max(0, (cols - w) // 2)
        pad_left_str = " " * pad_left_len
        blank_line = " " * cols

        # -- 5. RENDER --
        frame = []
        frame.append("\033[H")
        
        # Top Padding
        for _ in range(pad_top):
            frame.append(blank_line)
            
        # Draw Logo
        for y in range(h):
            if len(frame) >= rows: break
            
            line_parts = [pad_left_str]
            base_grad = (y * scale_factor / full_h)
            
            for x in range(w):
                char = grid[y][x]
                if char == " ": 
                    line_parts.append(" ")
                    continue
                
                # Noise Calculation (Uses slowed down "t")
                nx = (x * scale_factor) * 0.2
                ny = (y * scale_factor) * 0.3
                
                noise = math.sin(nx + t * 4) + math.cos(ny - t * 2)
                
                # Edge Crumbling
                if char in ".:+" and noise < -1.2:
                    line_parts.append(" ")
                    continue

                # Color
                color_val = base_grad + (noise * 0.1) + (math.sin(t) * 0.1)
                c_idx = int(color_val * len(gradient_colors))
                if c_idx > max_c_idx: c_idx = max_c_idx
                if c_idx < 0: c_idx = 0
                
                line_parts.append("\033[38;5;" + str(gradient_colors[c_idx]) + "m" + char)
            
            line_parts.append("\033[0m")
            frame.append("".join(line_parts))
            
        # Bottom Padding
        while len(frame) <= rows:
            frame.append(blank_line)
            
        # Print without scrolling
        output_str = "\n".join(frame[:rows])
        sys.stdout.write(output_str)
        sys.stdout.flush()
        
        time.sleep(0.05)

except KeyboardInterrupt:
    sys.stdout.write("\033[0m\033[2J\033[H")
    pass
'
    tput cnorm
}

function water() {
    tput civis # Hide cursor
    python3 -c '
import sys, os, time, random

# -- Configuration --
squiggle_chars = "~-~_."

# Palette: Bright Cyan (Top/Surface) -> Deep Navy (Bottom)
colors = [159, 123, 87, 51, 45, 39, 33, 27, 21, 19, 17]

class Wave:
    def __init__(self, cols, rows):
        # 1. Shape
        length = random.randint(5, 15)
        self.shape = "".join(random.choice(squiggle_chars) for _ in range(length))
        
        # 2. Position
        self.x = float(-length)
        self.y = random.randint(1, rows - 2)
        
        # 3. Depth & Color
        depth = self.y / rows
        c_idx = int(depth * len(colors))
        if c_idx >= len(colors): c_idx = len(colors) - 1
        self.color = colors[c_idx]

        # 4. Speed (Slower & Varied)
        base_speed = random.uniform(0.35, 1.65)
        
        # Depth modifier: Waves at the bottom are slightly slower/heavier
        self.speed = base_speed * (1.0 - (depth * 0.25))

def run():
    try:
        cols, rows = os.get_terminal_size()
        waves = []
        
        state = "WAITING"
        next_state_time = time.time()
        waves_to_spawn = 0
        
        while True:
            now = time.time()
            
            # -- Spawner Logic --
            if state == "WAITING":
                if now > next_state_time:
                    state = "SPAWNING"
                    waves_to_spawn = random.randint(5, 12) 
                    next_state_time = now
                    
            elif state == "SPAWNING":
                if now > next_state_time:
                    if waves_to_spawn > 0:
                        waves.append(Wave(cols, rows))
                        waves_to_spawn -= 1
                        # Slower spawn rate to match slower movement (0.1s to 0.4s gap)
                        next_state_time = now + random.uniform(0.1, 0.3)
                    else:
                        state = "WAITING"
                        # Longer pause between groups (1.0s to 3.0s)
                        next_state_time = now + random.uniform(1.0, 3.0)

            # -- Render --
            grid = [" "] * (cols * rows)
            
            def draw_pixel(x, y, char, color_code):
                if 0 <= x < cols and 0 <= y < rows:
                    idx = y * cols + x
                    grid[idx] = f"\033[38;5;{color_code}m{char}"

            active_waves = []
            for w in waves:
                w.x += w.speed
                
                # Draw
                for i, char in enumerate(w.shape):
                    draw_x = int(w.x) + i
                    draw_pixel(draw_x, w.y, char, w.color)
                
                if w.x - len(w.shape) < cols: 
                    active_waves.append(w)
            
            waves = active_waves
            
            output = ["\033[H"] 
            for y in range(rows - 1):
                row_pixels = grid[y*cols : (y+1)*cols]
                output.append("".join(row_pixels))
                
            sys.stdout.write("\n".join(output))
            sys.stdout.flush()
            
            # 50ms per frame = ~20 FPS (smooth but relaxed)
            time.sleep(0.0375)

except KeyboardInterrupt:
    sys.stdout.write("\033[0m\033[2J\033[H")

run()
'
    tput cnorm 
}