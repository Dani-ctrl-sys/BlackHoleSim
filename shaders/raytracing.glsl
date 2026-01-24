#version 430

// --- CONFIGURACIÓN TÉCNICA ---
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba32f, binding = 0) uniform image2D imgOutput;

// --- VARIABLES GLOBALES ---
uniform float u_time;
uniform vec3 u_camPos;

// --- CONSTANTES DE AGUJERO NEGRO ---
const float RS = 0.5;           // Radio de Schwarzschild
const float ISCO = 3.0 * RS;    // Borde interno estable
const float DISK_MAX = 6.0 * RS;// Borde externo del disco
const int MAX_STEPS = 200;      // Calidad de la integración
const float STEP_SIZE = 0.05;   // Paso de tiempo

// =========================================================
//            MOTOR DE RUIDO PROCEDURAL (FBM)
// =========================================================

// 1. Hash: La licuadora de números (Aleatoriedad base)
float hash(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// 2. Ruido de Valor: Suaviza los puntos aleatorios (Nubes borrosas)
float valueNoise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f); // Curva Hermite (Smoothstep)
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// 3. FBM: Movimiento Browniano Fractal (Detalle acumulativo)
// Suma 5 capas de ruido para crear textura de fuego/gas
float fbm(vec2 uv) {
    float v = 0.0;
    float a = 0.5;
    vec2 shift = vec2(100.0);
    // Rotamos cada capa para evitar patrones de cuadrícula (Artefactos)
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
    for (int i = 0; i < 5; ++i) {
        v += a * valueNoise(uv);
        uv = rot * uv * 2.0 + shift; // Doble frecuencia
        a *= 0.5;                    // Mitad amplitud
    }
    return v;
}

// =========================================================
//            FÍSICA Y RAYTRACING
// =========================================================

// Fondo de estrellas simple (con distorsión por lente gravitacional implícita)
vec3 getBackground(vec3 dir) {
    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * 3.14159);
    float v = 0.5 - asin(dir.y) / 3.14159;
    float stars = step(0.995, hash(vec2(u, v) * 500.0)); // Estrellas aleatorias
    return vec3(stars);
}

mat3 setCamera(in vec3 ro, in vec3 ta, float cr){
    vec3 cw = normalize(ta - ro);
    vec3 cp = vec3(sin(cr), cos(cr), 0.0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = normalize(cross(cu, cw));
    return mat3(cu, cv, cw);
}

vec3 calculateAccel(vec3 pos){
    float r2 = dot(pos,pos);
    float r = sqrt(r2);
    // Gravedad Newtoniana modificada (Pseudo-Schwarzschild simple)
    return -1.5 * RS * pos / (r2 * r2 * r);
}

// Integrador RK4 (Runge-Kutta 4)
void stepRK4(inout vec3 pos, inout vec3 vel, float dt) {
    vec3 k1_v = vel;              vec3 k1_a = calculateAccel(pos);
    vec3 pos2 = pos + k1_v*dt*0.5;vec3 k2_v = vel + k1_a*dt*0.5; vec3 k2_a = calculateAccel(pos2);
    vec3 pos3 = pos + k2_v*dt*0.5;vec3 k3_v = vel + k2_a*dt*0.5; vec3 k3_a = calculateAccel(pos3);
    vec3 pos4 = pos + k3_v*dt;    vec3 k4_v = vel + k3_a*dt;     vec3 k4_a = calculateAccel(pos4);
    
    pos += (k1_v + 2.0*k2_v + 2.0*k3_v + k4_v) / 6.0 * dt;
    vel += (k1_a + 2.0*k2_a + 2.0*k3_a + k4_a) / 6.0 * dt;
}

void main() {
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
    ivec2 dims = imageSize(imgOutput);
    if(pixel_coords.x >= dims.x || pixel_coords.y >= dims.y) return;

    // Coordenadas UV normalizadas [-1, 1]
    vec2 uv = vec2(pixel_coords) / vec2(dims);
    uv = uv * 2.0 - 1.0;
    uv.x *= float(dims.x) / float(dims.y);

    // Configurar Rayo
    vec3 ro = u_camPos;
    mat3 cam = setCamera(ro, vec3(0.0), 0.0);
    vec3 rd = cam * normalize(vec3(uv, 2.0));

    vec3 pos = ro;
    vec3 vel = rd;
    vec3 col = vec3(0.0);
    bool hit = false;
    
    // Bucle de Raymarching (Paso a paso por el espacio-tiempo)
    for(int i = 0; i < MAX_STEPS; i++){
        float r = length(pos);
        
        // 1. COLISIÓN CON HORIZONTE DE EVENTOS (Negro absoluto)
        if(r < RS * 0.9){ 
            col = vec3(0.0); 
            hit = true; 
            break; 
        }

        // 2. COLISIÓN CON DISCO DE ACRECIÓN (Plano Y=0)
        // Detectamos si cruzamos el plano Y (cambio de signo o muy cerca de 0)
        if(abs(pos.y) < 0.05 && r > ISCO && r < DISK_MAX){
            
            // --- AQUÍ EMPIEZA LA MAGIA DE LA FASE 6 ---
            
            // A. Coordenadas Polares (Radio y Ángulo)
            float angle = atan(pos.z, pos.x);
            
            // B. Animación: Rotación Diferencial
            // El gas cerca del agujero gira más rápido que el lejano.
            // (Factor 3.0 para ajustar velocidad visual)
            float speed = 3.0 / sqrt(r); 
            float rot_angle = angle + speed * u_time;

            // C. Mapeo al Ruido
            // Usamos (rot_angle, r) como coordenadas para el FBM.
            // Multiplicamos por constantes para ajustar la escala de la textura.
            vec2 noise_uv = vec2(rot_angle * 4.0, r * 2.0 - u_time);
            
            float noise = fbm(noise_uv);

            // D. Mapeo de Color (Gradiente de Fuego/Temperatura)
            // Más caliente (brillante) cerca del centro (ISCO), más frío (rojo) fuera.
            float temp = (DISK_MAX - r) / (DISK_MAX - ISCO); // 1.0 en el borde interno, 0.0 en el externo
            
            // Combinamos temperatura física con el caos del ruido
            float intensity = temp * noise * 2.0; 
            
            // Paleta "Blackbody": Rojo -> Naranja -> Blanco
            vec3 fireColor = vec3(1.0, intensity * 0.5, intensity * 0.1) * intensity * 2.0;
            
            col = fireColor;
            hit = true;
            break; 
        }

        stepRK4(pos, vel, STEP_SIZE);
    }

    if(!hit) col = getBackground(vel);

    // Tone Mapping simple (evitar quemar los blancos)
    col = col / (col + vec3(1.0));
    col = pow(col, vec3(1.0/2.2)); // Gamma correction

    imageStore(imgOutput, pixel_coords, vec4(col, 1.0));
}