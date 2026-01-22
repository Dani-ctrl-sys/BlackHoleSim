#version 330 core
out vec4 FragColor;
in vec2 fragCoord;

uniform vec2 u_resolution;
uniform vec3 u_camPos;
uniform float u_rs; // Radio de Schwarzschild

// --- HERRAMIENTAS VISUALES (Fondo y Cámara) ---

vec3 getBackground(vec3 dir) {
    float u = 0.5 + atan(dir.z, dir.x) / (2.0 * 3.14159);
    float v = 0.5 - asin(dir.y) / 3.14159;
    
    // Rejilla de fondo
    float density = 10.0;
    float gridX = step(0.98, fract(u * density));
    float gridY = step(0.98, fract(v * density));
    float gridColor = max(gridX, gridY);
    
    // Azul oscuro con líneas cian
    return vec3(0.05, 0.05, 0.1) + vec3(0.0, 1.0, 1.0) * gridColor;
}

mat3 setCamera(in vec3 ro, in vec3 ta, float cr){
    vec3 cw = normalize(ta - ro);
    vec3 cp = vec3(sin(cr), cos(cr), 0.0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = normalize(cross(cu, cw));
    return mat3(cu, cv, cw);
}

// --- FÍSICA: CÁLCULO DE ACELERACIÓN (GRAVEDAD) ---
vec3 calculateAccel(vec3 p, vec3 v, float rs) {
    float r2 = dot(p, p);
    // Corrección relativista: fuerza proporcional a 1/r^4 aprox
    vec3 h = cross(p, v);
    float h2 = dot(h, h);
    return -1.5 * h2 * rs / pow(r2, 2.5) * p;
}

void main()
{
    // 1. Configuración de coordenadas
    vec2 uv = fragCoord;
    float aspect = u_resolution.x / u_resolution.y;
    uv.x *= aspect;

    // 2. Configuración de cámara y rayo
    vec3 ro = u_camPos; 
    vec3 ta = vec3(0.0, 0.0, 0.0);
    mat3 cam = setCamera(ro, ta, 0.0);
    vec3 rd = cam * normalize(vec3(uv, 2.0));

    // 3. Variables de estado del fotón
    vec3 p = ro;
    vec3 v = rd;
    
    // 4. Configuración de la simulación
    float stepSize = 0.15; // Paso grande gracias a RK4
    int maxSteps = 600;
    
    float isco = 3.0 * u_rs;      // Borde interno del disco
    float outerDisk = 6.0 * u_rs; // Borde externo del disco
    
    bool hitBlackHole = false;
    vec3 color = vec3(0.0);

    // --- BUCLE DE RAY MARCHING (RK4) ---
    for(int i = 0; i < maxSteps; i++) {
        
        vec3 p_prev = p; // IMPORTANTE: Guardar posición antes de mover
        float r2 = dot(p, p);

        // A. Colisión con Horizonte de Sucesos
        if(r2 < u_rs * u_rs) {
            hitBlackHole = true;
            color = vec3(0.0); // Negro absoluto
            break;
        }
        
        // B. Salida al infinito (optimización)
        if(r2 > 25.0 * 25.0) {
            break;
        }

        // C. Integrador RK4 (Precisión matemática)
        vec3 k1_v = calculateAccel(p, v, u_rs);
        vec3 k1_p = v;

        vec3 k2_v = calculateAccel(p + k1_p * stepSize * 0.5, v + k1_v * stepSize * 0.5, u_rs);
        vec3 k2_p = v + k1_v * stepSize * 0.5;

        vec3 k3_v = calculateAccel(p + k2_p * stepSize * 0.5, v + k2_v * stepSize * 0.5, u_rs);
        vec3 k3_p = v + k2_v * stepSize * 0.5;

        vec3 k4_v = calculateAccel(p + k3_p * stepSize, v + k3_v * stepSize, u_rs);
        vec3 k4_p = v + k3_v * stepSize;

        v += (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v) * stepSize / 6.0;
        p += (k1_p + 2.0 * k2_p + 2.0 * k3_p + k4_p) * stepSize / 6.0;

        // D. Detección del Disco (Corrección de Tunelización)
        // Si Y cambió de signo, cruzamos el plano del disco
        if(p_prev.y * p.y < 0.0) {
            
            // Interpolación: ¿En qué punto exacto cruzamos Y=0?
            float t = -p_prev.y / (p.y - p_prev.y);
            vec3 p_exacto = p_prev + t * (p - p_prev);
            float dist = length(p_exacto);

            // Verificar si el punto de cruce está dentro del anillo
            if(dist > isco && dist < outerDisk) {
                float intensity = smoothstep(isco, isco + 0.5, dist) * (outerDisk / dist);
                color = vec3(1.0, 0.6, 0.1) * intensity * 2.0; // Color Naranja Brillante
                hitBlackHole = true;
                break; // ¡Chocamos con el disco! Dejamos de trazar
            }
        }
    }

    // 5. Asignación de color final
    if(hitBlackHole) {
        FragColor = vec4(color, 1.0);
    } else {
        FragColor = vec4(getBackground(normalize(v)), 1.0);
    }
}