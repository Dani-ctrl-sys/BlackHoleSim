#version 430

// --- 1. CONFIGURACIÓN DEL GRUPO DE TRABAJO ---
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// --- 2. SALIDA (La "Hoja de Papel") ---
layout(rgba32f, binding = 0) uniform image2D imgOutput;

// --- 3. UNIFORMS (Variables Globales) ---
uniform float u_time;
uniform vec3 u_camPos;

// --- CONSTANTES FÍSICAS ---
const float RS = 0.5;
const float ISCO = 3.0 * RS;
const int MAX_STEPS = 200;
const float STEP_SIZE = 0.05;

// ==========================================
//      FUNCIONES AUXILIARES (CÁMARA/FONDO)
// ==========================================

// Genera un fondo espacial
vec3 getBackground(vec3 dir) {
    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * 3.14159);
    float v = 0.5 - asin(dir.y) / 3.14159;
    float density = 10.0;
    float gridX = step(0.98, fract(u * density));
    float gridY = step(0.98, fract(v * density));
    float gridColor = max(gridX, gridY);
    return vec3(0.05, 0.05, 0.1) + vec3(0.0, 1.0, 1.0) * gridColor;
}

// Matriz de cámara
mat3 setCamera(in vec3 ro, in vec3 ta, float cr){
    vec3 cw = normalize(ta - ro);
    vec3 cp = vec3(sin(cr), cos(cr), 0.0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = normalize(cross(cu, cw));
    return mat3(cu, cv, cw);
}

// Aceleración Relativista (Schwarzschild)
vec3 calculateAccel(vec3 pos){
    float r2 = dot(pos,pos);
    float r = sqrt(r2);
    return -1.5 * RS * pos / (r2 * r2 * r);
}

// Integrador RK4 (Física)
void stepRK4(inout vec3 pos, inout vec3 vel, float dt) {
    vec3 k1_v = vel;
    vec3 k1_a = calculateAccel(pos);
    
    vec3 pos2 = pos + k1_v * (dt * 0.5);
    vec3 k2_v = vel + k1_a * (dt * 0.5);
    vec3 k2_a = calculateAccel(pos2);
    
    vec3 pos3 = pos + k2_v * (dt * 0.5);
    vec3 k3_v = vel + k2_a * (dt * 0.5);
    vec3 k3_a = calculateAccel(pos3);
    
    vec3 pos4 = pos + k3_v * dt;
    vec3 k4_v = vel + k3_a * dt;
    vec3 k4_a = calculateAccel(pos4);
    
    pos += (k1_v + 2.0*k2_v + 2.0*k3_v + k4_v) / 6.0 * dt;
    vel += (k1_a + 2.0*k2_a + 2.0*k3_a + k4_a) / 6.0 * dt;
}

// ==========================================
//      NUEVAS FUNCIONES DE RUIDO (Etapa 6)
// ==========================================

// 1. HASH: La Trituradora Matemática (Aleatoriedad Pseudo-random)
float hash(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 2. VALUE NOISE: Ruido Suave Interpolado
// Convierte los puntos aleatorios en "nubes"
float valueNoise(vec2 uv) {
    vec2 i = floor(uv); // Coordenada del azulejo (ej: 4.0)
    vec2 f = fract(uv); // Posición dentro del azulejo (ej: 0.2)

    // A. Obtener valores aleatorios en las 4 esquinas
    float a = hash(i);                      // Abajo-Izquierda
    float b = hash(i + vec2(1.0, 0.0));     // Abajo-Derecha
    float c = hash(i + vec2(0.0, 1.0));     // Arriba-Izquierda
    float d = hash(i + vec2(1.0, 1.0));     // Arriba-Derecha

    // B. Suavizado (Curva Hermite / Smoothstep manual)
    // Esto evita que se vean picos y líneas rectas
    vec2 u = f * f * (3.0 - 2.0 * f);

    // C. Mezcla Bilineal (Lerp en X, luego Lerp en Y)
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// ==========================================
//              MAIN (KERNEL)
// ==========================================
void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dims = imageSize(imgOutput);
    if(pixel_coords.x >= dims.x || pixel_coords.y >= dims.y) return;

    // --- COORDENADAS NORMALIZADAS ---
    vec2 uv = vec2(pixel_coords) / vec2(dims);
    
    // Guardamos una copia de UV para el ruido antes de modificarla para la cámara
    vec2 uv_noise = uv; 

    // Ajustes para Raytracing (centrar y aspect ratio)
    uv = uv * 2.0 - 1.0;
    float aspect = float(dims.x) / float(dims.y);
    uv.x *= aspect;

    // --- LÓGICA DE AGUJERO NEGRO (Se ejecuta pero la taparemos al final) ---
    vec3 ro = u_camPos;
    vec3 ta = vec3(0.0);
    mat3 cam = setCamera(ro, ta, 0.0);
    vec3 rd = cam * normalize(vec3(uv, 2.0));
    
    vec3 pos = ro;
    vec3 vel = rd;
    vec3 col = vec3(0.0);
    bool hit = false;
    
    for(int i = 0; i < MAX_STEPS; i++){
        float r = length(pos);
        if(r < RS){ col = vec3(0.0); hit = true; break; }
        // Disco simple (Tablero ajedrez antiguo)
        if(abs(pos.y) < 0.1 && r > ISCO && r < 4.0 * RS){
             float check = mod(floor(r*10.0) + floor(atan(pos.z, pos.x)*10.0), 2.0);
             col = vec3(1.0, 0.6, 0.1) * (0.5 + 0.5 * check);
             hit = true; break;
        }
        stepRK4(pos, vel, STEP_SIZE);
    }
    if(!hit) col = getBackground(vel);

    // =========================================================
    //    PRUEBA DE VISUALIZACIÓN DE RUIDO (SOBRESCRIBE TODO)
    // =========================================================
    // Multiplicamos por 10.0 para ver una cuadrícula de 10x10 "manchas"
    float n = valueNoise(uv_noise * 10.0);
    
    // Lo mostramos en escala de grises
    col = vec3(n); 
    // =========================================================

    imageStore(imgOutput, pixel_coords, vec4(col, 1.0));
}