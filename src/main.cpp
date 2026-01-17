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

    //Necesario para la física: Producto Cruz
    vec3 cross(const vec3& v) const {
        return{y * v.z - z * v.y, z * v.x - x * v.z, x * v.y - y * v.x};
    }
};

//Funciones auxiliares para vectores
float dot(const vec3& a, const vec3& b){return a.x*b.x + a.y*b.y + a.z*b.z;}
float length_sq(const vec3& v){return dot(v,v);}
float length(const vec3& v){return std::sqrt(length_sq(v));}

vec3 normalize(const vec3& v){
    float len = length(v);
    return (len > 0) ? vec3{v.x/len, v.y/len, v.z/len} : vec3{0,0,0};
}

// --- MOTOR DE FÍSICA RELATIVISTA (CPU) ---

//Constantes físicas del sistema (Unidades Naturales: G=1, c=1)
const float RS = 0.5f; // Radio de Schwarzschild (Horizonte de eventos)
const float ISCO = 3.0f * RS; // Órbita Circular Estable Más Interna (para el disco)

//Integra el rayo paso a paso a través del espacio curvo
// Devuelve el color final del píxel
vec3 integrate_geodesic(vec3 ro, vec3 rd){
    vec3 pos = ro;
    vec3 vel = rd; //La velocidad de la luz c=1, dirección inicial

    float dt = 0.05f; //Tamaño del paso del tiempo (delta time)
    //ADVERTENCIA: dt muy grande = simulación rápida pero imprecisa
    // dt muy pequeño = simulación precisa pero lenta

    // Límite de pasos para evitar bucles infinitos si la luz orbita
    for (int i = 0; i < 200; i++){
        float r2 = length_sq(pos); //Distancia al cuadrado al centro (0,0,0)
        float r = std::sqrt(r2); //Distancia actual

        //1. CONDICIONES DE TERMINACIÓN

        //A) ¿Cayó en el agujero negro?
        if(r <= RS){
            return vec3{0.0f, 0.0f, 0.0f}; //Negro absoluto
        }

        //B) ¿Escapó al infinito? (Lejos del centro)
        if (r > 15.f){
            //Dibujamos un fondo de estrellas simple basado en la dirección actual
            // Esto nos permitirá ver la distorsión de la luz (lente gravitacional)
            vec3 dir = normalize(vel);
            float horizont_band =  1.0f - std::abs(dir.y);
            float star = std::pow(horizont_band,50.0f); //Estrellas más visibles
            return {0.05f + star, 0.05f + star, 0.1f};
        }

        // 2. FÍSICA: Calcular la aceleración (Curvatura)
        // Ecuación de movimiento para un fotón en Schwarzschild.
        // Fórmula aproximada de aceleración: a = -1.5 * Rs * h^2 / r^5 * pos
        // Donde h es el momento angular por unidad de masa.

        vec3 h_vec = pos.cross(vel); //Momento angular (r x v)
        float h2 = length_sq(h_vec); //Magnitud al cuadrado

        // Fuerza de la gravedad efectiva para la luz
        //Nota: En Newton la fuerza es 1/r^2. En RG para la luz hay un término extra 1/r^4
        vec3 acc = pos * (-1.5f * RS * h2 / (r2 * r2 * r));

        //3. INTEGRACIÓN (Método de Euler Semi-implícito)
        vel = vel + acc * dt; //Actualizar velocidad (dirección se curva)
        pos = pos + vel * dt; //Actualizar posición
    }

    return {0.05f, 0.05f, 0.01f}; //Si se acaban los pasos, devolver fondo
}

void RayTraceCPU(std::vector<float>& buffer, int w, int h, float aspect){
    vec3 cameraPos = {0.0f, 1.5f, 6.0f}; //Alejamos un poco la cámara

    //#pragma omp parallel for // Descomenta si tienes OpenMP habilitado para acelerar
    for(int y=0; y < h; y++){
        for(int x=0; x < w; x++){
            //Coordenadas UV
            float u = (float)x / (float)w * 2.0f - 1.0f;
            float v = (float)y / (float)h * 2.0f - 1.0f;
            u *= aspect;

            vec3 ro = cameraPos;
            vec3 pixelPos = {u, v - 0.5f, 4.0f}; //Pantalla virtual frente a la cámara
            vec3 rd = normalize(pixelPos - ro);

            vec3 color = integrate_geodesic(ro, rd);
            
            // DEBUG: Print first pixel to see what we're calculating
            if(x == w/2 && y == h/2) {
                std::cout << "Center pixel color: " << color.x << ", " << color.y << ", " << color.z << std::endl;
            }
            
            int index = (y * w + x) * 3;
            buffer[index] = color.x;
            buffer[index + 1] = color.y;
            buffer[index + 2] = color.z;
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
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); //Linear para suavizar en baja resolución
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //Buffer de la CPU donde pintaremos (Ancho * Alto * 3 canales RGB)
    std::vector<float> pixelBuffer(WINDOW_WIDTH * WINDOW_HEIGHT * 3);

    glUseProgram(shaderProgram);
    glUniform1i(glGetUniformLocation(shaderProgram, "screenTexture"), 0);

    const float RENDER_SCALE = 0.25f;

    //Loop de renderizado
    while (!glfwWindowShouldClose(window)) {
        processInput(window);

        //CÁLCULO DINÁMICO DE ASPECTO ---
        int windowW, windowH;
        glfwGetFramebufferSize(window, &windowW, &windowH); // Preguntamos tamaño real

        //Protección contra minimizado (evitar división por 0)
        if (windowH == 0) windowH = 1;
        if (windowW == 0) windowW = 1;

        int renderW = (int)(windowW * RENDER_SCALE);
        int renderH = (int)(windowH * RENDER_SCALE);

        if(renderW < 1) renderW = 1;
        if(renderH < 1) renderH = 1;

        float renderAspect = (float)renderW / (float)renderH;
        
        //Redimensionar el buffer si el tamaño cambió
        size_t requiredSize = renderW * renderH * 3;
        if (pixelBuffer.size() != requiredSize) {
            pixelBuffer.resize(requiredSize);
        }

        //1. CALCULAR FÍSICA (CPU) con dimensiones actuales
        RayTraceCPU(pixelBuffer, renderW, renderH, renderAspect);

        //2. SUBIR DATOS A LA GPU con dimensiones actuales
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, renderW, renderH, 0, GL_RGB, GL_FLOAT, pixelBuffer.data());

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
