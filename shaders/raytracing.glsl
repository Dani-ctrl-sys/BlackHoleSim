#version 430
// 1. DEFINICIÓN DEL GRUPO DE TRABAJO
// La GPU agrupa los hilos en bloques. Aquí decimos que cada bloque
// será de 8x8 hilos (64 hilos por grupo).

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// 2. LA TEXTURA DE SALIDA (Nuestra "Hoja de Papel")
// rgba32f: Coincide con el GL_RGBA32F de C++
// binding = 0: Coincide con el '0' del glBindImageTexture en C++
layout(rgba32f, binding = 0) uniform image2D imgOutput;

// 3. UNIFORMS
uniform float u_time;
uniform vec3 u_camPos; // Posición de la cámara (desde C++)

const float RS = 0.5;
const float ISCO = 3.0 * RS;
const int MAX_STEPS = 200;
const float STEP_SIZE = 0.05;;

// Genera un fondo con rejilla espacial basado en la dirección del rayo
vec3 getBackground(vec3 dir) {
    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * 3.14159);
    float v = 0.5 - asin(dir.y) / 3.14159;
    
    // Rejilla de fondo
    float density = 10.0;
    float gridX = step(0.98, fract(u * density));
    float gridY = step(0.98, fract(v * density));
    float gridColor = max(gridX, gridY);
    
    // Azul oscuro con l├¡neas cian
    return vec3(0.05, 0.05, 0.1) + vec3(0.0, 1.0, 1.0) * gridColor;
}

// Construye matriz de cámara: ro=origen, ta=target, cr=roll
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

    vec3 acc = -1.5 * RS * pos / (r2 * r2 * r);
    return acc;
}

// --- INTEGRADOR RUNGE-KUTTA 4 (Alta Precisión) ---
void stepRK4(inout vec3 pos, inout vec3 vel, float dt) {
    // 1. Primer paso (donde estamos ahora)
    vec3 k1_v = vel;
    vec3 k1_a = calculateAccel(pos);

    // 2. Segundo paso (probamos a mitad del camino usando k1)
    vec3 pos2 = pos + k1_v * (dt * 0.5);
    vec3 k2_v = vel + k1_a * (dt * 0.5);
    vec3 k2_a = calculateAccel(pos2);

    // 3. Tercer paso (corregimos la mitad del camino usando k2)
    vec3 pos3 = pos + k2_v * (dt * 0.5);
    vec3 k3_v = vel + k2_a * (dt * 0.5);
    vec3 k3_a = calculateAccel(pos3);

    // 4. Cuarto paso (probamos el final del camino usando k3)
    vec3 pos4 = pos + k3_v * dt;
    vec3 k4_v = vel + k3_a * dt;
    vec3 k4_a = calculateAccel(pos4);

    // --- PROMEDIO PONDERADO ---
    // La velocidad final es una mezcla de las 4 velocidades de prueba
    // Pesos: 1/6, 2/6, 2/6, 1/6
    vec3 final_vel = (k1_v + 2.0*k2_v + 2.0*k3_v + k4_v) / 6.0;
    vec3 final_acc = (k1_a + 2.0*k2_a + 2.0*k3_a + k4_a) / 6.0;

    // Actualizamos las variables reales
    pos += final_vel * dt;
    vel += final_acc * dt;
}

// --- FUNCIÓN DE HASH (Pseudo-random) ---
// Entra: Coordenada 2D (p)
// Sale: Un único número aleatorio entre 0.0 y 1.0
float hash(vec2 p) {
    // El "dot product" mezcla x e y.
    // El "sin" crea ondas.
    // El número grande (43758.5453) rompe la onda en pedacitos (fract).
    vec3 p3  = fract(vec3(p.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
// Nota: He usado una versión ligeramente mejorada del hash clásico de una línea
// para evitar problemas en algunas GPUs de Intel/AMD, pero el concepto es el mismo.

void main() {
    // A. OBTENER COORDENADAS
    // Convertimos el ID global en coordenadas de imagen (enteros)
    ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

    // B. OBTENER TAMAÑO DE IMAGEN
    // Ya no necesitamos pasar u_resolution manualmente,
    // podemos preguntarle a la textura cuánto mide.
    ivec2 dims = imageSize(imgOutput);

    // C. SEGURIDAD
    // Si el hilo está fuera de la imagen (puede pasar si el tamaño
    // no es múltiplo de 8), no hacemos nada para no romper la memoria.
    if(pixel_coords.x >= dims.x || pixel_coords.y >= dims.y) return;

    // Normalizar coordenadas a [0,1] y luego a [-1,1]
    vec2 uv = vec2(pixel_coords) / vec2(dims);
    uv = uv * 2.0 -1.0;

    // Corregir aspect ratio
    float aspect = float(dims.x) / float(dims.y);
    uv.x *= aspect;

    // Configurar cámara
    vec3 ro = u_camPos;  // Ray Origin
    vec3 ta = vec3(0.0, 0.0, 0.0);  // Target (mirando al origen)
    mat3 cam = setCamera(ro, ta, 0.0);

    // Generar rayo desde la cámara
    vec3 rd = cam * normalize(vec3(uv, 2.0));  // Ray Direction

    vec3 pos = ro;
    vec3 vel = rd;
    vec3 col = vec3(0.0);
    bool hit = false;

    for(int i = 0; i < MAX_STEPS; i++){
        float r = length(pos);

        if(r < RS){
            col = vec3 (0.0);
            hit = true;
            break;
        }

        if(abs(pos.y) < 0.1 && r > ISCO && r < 4.0 * RS){
            float angle = atan(pos.z, pos.x);
            float r_pattern = floor(r * 10.0);
            float a_pattern = floor(angle * 10.0);

            float check = mod(r_pattern + a_pattern, 2.0);
            col = vec3(1.0, 0.6, 0.1) * (0.5 + 0.5 * check);
            hit = true;
            break;
        }

        stepRK4(pos, vel, STEP_SIZE);
    }

    // Renderizar fondo si no golpeó nada
    if(!hit){
        col = getBackground(vel);
    }

    imageStore(imgOutput, pixel_coords, vec4(col, 1.0));
}