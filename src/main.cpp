#include <glad/gl.h>
#include <GLFW/glfw3.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cmath>

// --- CONFIGURACIÓN DE LA SIMULACIÓN ---
const int WINDOW_WIDTH = 800;
const int WINDOW_HEIGHT = 600;

//--- ESTRUCTURA MATEMÁTICA VECTORIAL ---
struct vec3 {
    float x,y,z;

    //Sobrecarga de operadores para facilitar las matemáticas
    vec3 operator+(const vec3& v) const {return {x + v.x, y + v.y, z + v.z};}
    vec3 operator-(const vec3& v) const {return {x - v.x, y - v.y, z - v.z};}
    vec3 operator*(float s) const {return {x * s, y * s, z * s};}
};

//Funciones auxiliares para vectores
float dot(const vec3& a, const vec3& b){return a.x*b.x + a.y*b.y + a.z*b.z;}
vec3 normalize(const vec3& v){
    float len = std::sqrt(dot(v, v));
    return {v.x/len, v.y/len, v.z/len};
}

// --- MOTOR DE FÍSICA (CPU) ---

// Comprueba si un rayo interseca una esfera.
// ro: Origen del rayo (Posición de la cámara)
// rd: Dirección del rayo (Hacia dónde apunta el píxel)
// center: Posición de la esfera (Centro del agujero negro)
// radius: Radio del horizonte de eventos
// Devuelve: distancia a la intersección o -1.0 si no se detecta.
float hit_sphere(const vec3& ro, const vec3& rd, const vec3& center, float radius){
    vec3 oc = ro - center;
    // Resolviendo la ecuación cuadrática para la intersección rayo-esfera: t^2*dot(rd,rd) + 2*t*dot(oc,rd) + dot(oc,oc) - r^2 = 0
    // a = 1 (ya que la dirección del rayo está normalizada)
    float b = 2.0f * dot(oc, rd);
    float c = dot(oc, oc) - radius * radius;
    float discriminant = b*b - 4.0f*c;

    if (discriminant < 0){
        return -1.0f; //Sin impacto (La luz pasa)
    } else {
        //Devuelve la distancia de impacto más cercana
        return (-b - std::sqrt(discriminant)) / 2.0f;
    }
}

void RayTraceCPU(std::vector<float>& buffer, int w, int h, float aspect){
    //1. DEFINIR LA ESCENA FÍSICA
    // Configuración de la cámara
    vec3 cameraPos = {0.0f, 0.0f, 3.0f}; // La cámara está en Z=3, mirando a Z=0
    
    // Propiedades del agujero negro
    // Radio de Schwarzschild (Rs) = 2GM/c^2. Supongamos que las unidades son G=1, M=1, c=1 => Rs = 2.0
    // Actualmente, el radio se establece en 0.5 para que se ajuste correctamente a la pantalla.
    vec3 bhCenter = {0.0f, 0.0f, 0.0f};
    float bhRadius = 0.5f;

    for(int y=0; y < h; y++){
        for(int x=0; x < w; x++){

            //2. GENERAR RAYO (Cámara -> Píxel)
            // Coordenadas del dispositivo normalizadas [-1, 1]
            float u = (float)x / (float)w * 2.0f - 1.0f;
            float v = (float)y / (float)h * 2.0f - 1.0f;
            u*=aspect; //Corregir la distorsión de aspecto

            // Ray Origin es la cámara
            vec3 ro = cameraPos;
            // Dirección del rayo: Desde la cámara hacia el plano de la pantalla en Z=2.0 (pantalla virtual)
            // La posición del píxel en el espacio 3D es aproximadamente (u, v, 2.0)
            vec3 pixelPos = {u, v, 2.0f};
            vec3 rd = normalize(pixelPos - ro);

            //3. TRACE RAY (Física Newtoniana por ahora)
            float t = hit_sphere(ro, rd, bhCenter, bhRadius);

            vec3 color = {0.0f, 0.0f, 0.0f}; //Color base: Negro (Espacio)

            if(t > 0.0f){
                // ¡GOLPE! lógica de física
                color = {0.0f, 0.0f, 0.0f}; // Event Horizon es negro puro
            } else{
                // MISS - Dibujar fondo
                // Gradiente de campo de estrellas simple puramente para referencia visual
                color = {0.05f, 0.05f, 0.1f};
                // Agreguemos una aproximación de "Disco de acreción" (solo visual por ahora)
                // Distancia desde la línea central
                vec3 closestPoint = ro + rd * dot(bhCenter - ro, rd);
                float distToCenter = std::sqrt(dot(closestPoint, closestPoint));

                //Si el valor distinto está entre 0,6 y 1,2, píntalo de naranja (Disco)
                if(distToCenter > 0.6f && distToCenter < 1.4f){
                    color = {0.8f, 0.4f, 0.1f};
                }
            }

            // 4. ESCRIBIR EN EL BUFFER
            int index = (y*w+x)*3;
            buffer[index + 0]=color.x;
            buffer[index + 1]=color.y;
            buffer[index + 2]=color.z;
        }
    }
}

// Callback para redimensionar la ventana
void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    glViewport(0, 0, width, height);
}

// Procesar entrada del usuario
void processInput(GLFWwindow *window) {
    if(glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);
}

// Función auxiliar para leer y compilar shaders
unsigned int createShaderProgram(const char* vertexPath, const char* fragmentPath) {
    // 1. Recuperar el código fuente de los archivos
    std::string vertexCode;
    std::string fragmentCode;
    std::ifstream vShaderFile;
    std::ifstream fShaderFile;

    // Asegurar que los objetos ifstream pueden lanzar excepciones
    vShaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);
    fShaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);

    try {
        // Abrir archivos
        vShaderFile.open(vertexPath);
        fShaderFile.open(fragmentPath);
        std::stringstream vShaderStream, fShaderStream;
        // Leer buffer del archivo al stream
        vShaderStream << vShaderFile.rdbuf();
        fShaderStream << fShaderFile.rdbuf();
        // Cerrar manejadores de archivo
        vShaderFile.close();
        fShaderFile.close();
        // Convertir stream a string
        vertexCode = vShaderStream.str();
        fragmentCode = fShaderStream.str();
    }
    catch (std::ifstream::failure& e) {
        std::cout << "ERROR::SHADER::FILE_NOT_SUCCESFULLY_READ" << std::endl;
        return 0;
    }

    const char* vShaderCode = vertexCode.c_str();
    const char* fShaderCode = fragmentCode.c_str();

    // 2. Compilar shaders
    unsigned int vertex, fragment;
    int success;
    char infoLog[512];

    // Vertex Shader
    vertex = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertex, 1, &vShaderCode, NULL);
    glCompileShader(vertex);
    // Imprimir errores de compilación si los hay
    glGetShaderiv(vertex, GL_COMPILE_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(vertex, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::VERTEX::COMPILATION_FAILED\n" << infoLog << std::endl;
    }

    // Fragment Shader
    fragment = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragment, 1, &fShaderCode, NULL);
    glCompileShader(fragment);
    glGetShaderiv(fragment, GL_COMPILE_STATUS, &success);
    if (!success) {
        glGetShaderInfoLog(fragment, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n" << infoLog << std::endl;
    }

    // Shader Program
    unsigned int ID = glCreateProgram();
    glAttachShader(ID, vertex);
    glAttachShader(ID, fragment);
    glLinkProgram(ID);
    // Imprimir errores de linkado
    glGetProgramiv(ID, GL_LINK_STATUS, &success);
    if (!success) {
        glGetProgramInfoLog(ID, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::PROGRAM::LINKING_FAILED\n" << infoLog << std::endl;
    }

    // Borrar los shaders ya que están linkados en el programa y ya no son necesarios
    glDeleteShader(vertex);
    glDeleteShader(fragment);

    return ID;
}

int main() {
    // Inicializar GLFW
    if (!glfwInit()) {
        std::cerr << "ERROR: No se pudo inicializar GLFW" << std::endl;
        return -1;
    }

    // Configurar GLFW
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

    // Crear ventana
    GLFWwindow* window = glfwCreateWindow(800, 600, "BlackHoleSim - Simulador de Agujero Negro", NULL, NULL);
    if (window == NULL) {
        std::cerr << "ERROR: No se pudo crear la ventana GLFW" << std::endl;
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window);
    glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

    // Cargar GLAD (glad2 API)
    if (!gladLoadGL(glfwGetProcAddress)) {
        std::cerr << "ERROR: No se pudo inicializar GLAD" << std::endl;
        return -1;
    }

    std::cout << "OpenGL Version: " << glGetString(GL_VERSION) << std::endl;

    unsigned int shaderProgram = createShaderProgram("shaders/vertex_core.glsl", "shaders/fragment_core.glsl");

    //DEFINE EL LIENZO (Pantalla completa cuádruple)
    //Dos triángulos que cubren toda la pantalla de -1 a 1
    float vertices[] = {
        //posiciones (x, y)
        -1.0f, 1.0f,  //Arriba a la izquierda
        -1.0f, -1.0f,  //Abajo a la izquierda
        1.0f, -1.0f,   //Abajo a la derecha
        
        -1.0f, 1.0f,  //Arriba a la izquierda
        1.0f, -1.0f,  //Abajo a la derecha
        1.0f, 1.0f,   //Arriba a la derecha
    };

    //CONFIGURAR BUFFERS
    unsigned int VBO, VAO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);

    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    //Indica a OpenGL cómo leer los atributos (solo posición: 2 flotantes)
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    //---CREACIÓN DE TEXTURA---
    unsigned int texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);

    //Configuración de la textura (repetir, filtro)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); //Nearest para ver los píxeles claros
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    
    //Buffer de la CPU donde pintaremos (Ancho * Alto * 3 canales RGB)
    std::vector<float> pixelBuffer(WINDOW_WIDTH * WINDOW_HEIGHT * 3);

    glUseProgram(shaderProgram);
    glUniform1i(glGetUniformLocation(shaderProgram, "screenTexture"), 0);

    //Loop de renderizado
    while (!glfwWindowShouldClose(window)) {
        processInput(window);

        //CÁLCULO DINÁMICO DE ASPECTO ---
        int currentW, currentH;
        glfwGetFramebufferSize(window, &currentW, &currentH); // Preguntamos tamaño real

        //Protección contra minimizado (evitar división por 0)
        if (currentH == 0) currentH = 1;
        if (currentW == 0) currentW = 1;

        //Calculamos la proporción actual de la ventana
        float currentAspect = (float)currentW / (float)currentH;
        
        //Redimensionar el buffer si el tamaño cambió
        size_t requiredSize = currentW * currentH * 3;
        if (pixelBuffer.size() != requiredSize) {
            pixelBuffer.resize(requiredSize);
        }

        //1. CALCULAR FÍSICA (CPU) con dimensiones actuales
        RayTraceCPU(pixelBuffer, currentW, currentH, currentAspect);

        //2. SUBIR DATOS A LA GPU con dimensiones actuales
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, currentW, currentH, 0, GL_RGB, GL_FLOAT, pixelBuffer.data());

        //3. DIBUJAR
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(shaderProgram);
        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    // Limpieza
    glfwTerminate();
    return 0;
}
