#version 430

// --- CONFIGURACIÓN TÉCNICA ---
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba32f, binding = 0) uniform image2D imgOutput;

// --- VARIABLES GLOBALES ---
uniform float u_time;
uniform vec3 u_camPos;
uniform sampler2D skybox;

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
    // Normalizamos por seguridad
    vec3 d = normalize(dir);

    // Mapeo de Esfera a Rectángulo (Coordenadas UV)
    // atan(z, x) nos da el ángulo horizontal (longitud) -> U
    // asin(y) nos da el ángulo vertical (latitud) -> V
    
    float u = 0.5 + atan(d.z, d.x) / (2.0 * 3.14159265);
    float v = 0.5 + asin(d.y) / 3.14159265;
    
    // texture() es la función de GLSL para leer píxeles interpolados
    vec3 texColor = texture(skybox, vec2(u, v)).rgb;
    
    return texColor;
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

    // Variable para guardar la posición del paso anterior
    vec3 prevPos = pos;
    
    // Bucle de Raymarching (Paso a paso por el espacio-tiempo)
    for(int i = 0; i < MAX_STEPS; i++){
       // Guardamos posición antes de avanzar
        prevPos = pos; 
        
        // Avanzamos la física
        stepRK4(pos, vel, STEP_SIZE);
        
        float r = length(pos);

        // 1. COLISIÓN CON HORIZONTE DE EVENTOS (Mejorada)
        if(r < RS * 1.01){ // Un poco más grande que RS para evitar ruido
            col = vec3(0.0);
            hit = true; 
            break; 
        }

        // 2. DETECCIÓN DE CRUCE DEL DISCO (SOLUCIÓN AL HALO)
        // Si Y cambió de signo (uno positivo, otro negativo), cruzamos el plano.
        if(prevPos.y * pos.y < 0.0) {
            
            // Interpolación: ¿En qué punto exacto Y fue 0?
            // Matemáticas: t es el porcentaje del paso donde ocurrió el cruce.
            float t = prevPos.y / (prevPos.y - pos.y);
            vec3 hitPoint = mix(prevPos, pos, t); // Punto exacto de choque
            
            float hitDist = length(hitPoint); // Distancia desde el centro

            // Verificamos si ese punto exacto está dentro de los radios del disco
            if(hitDist > ISCO && hitDist < DISK_MAX){
                
                // --- RENDERIZADO DEL DISCO (Usando hitPoint en lugar de pos) ---
                
                // A. Coordenadas Polares
                float angle = atan(hitPoint.z, hitPoint.x);
                
                // B. Rotación Diferencial
                float speed = 12.0 / sqrt(hitDist); // Aumenté velocidad para efecto visual
                float rot_angle = angle + speed * u_time;
                
                // C. Mapeo UV para el ruido
                vec2 noise_uv = vec2(rot_angle * 3.0, hitDist * 1.5 - u_time);
                float noise = fbm(noise_uv);
                
                // D. Temperatura y Doppler (Simplificado para debug visual)
                float temp = (DISK_MAX - hitDist) / (DISK_MAX - ISCO);
                float intensity = temp * noise * 2.0;
                
                // Doppler simple: lado izquierdo azulado/brillante, derecho rojizo/oscuro
                // Usamos el producto punto entre la dirección de vista y la tangente del disco
                vec3 diskTangent = normalize(vec3(-hitPoint.z, 0.0, hitPoint.x));
                float doppler = dot(normalize(vel), diskTangent); 
                // doppler > 0 se aleja (rojo), doppler < 0 se acerca (azul/brillante)
                float beaming = pow(1.0 - doppler * 0.5, 3.0); 
                
                intensity *= beaming;

                vec3 fireColor = vec3(1.0, 0.6, 0.2) * intensity * 3.0;
                // Gradiente térmico hacia blanco en el centro
                fireColor += vec3(0.5, 0.5, 1.0) * smoothstep(0.0, 1.0, intensity - 1.0);

                col = fireColor;
                hit = true;
                break;
            }
        }
    }

    if(!hit) col = getBackground(vel);

    // Tone Mapping simple (evitar quemar los blancos)
    col = col / (col + vec3(1.0));
    col = pow(col, vec3(1.0/2.2)); // Gamma correction

    imageStore(imgOutput, pixel_coords, vec4(col, 1.0));
}