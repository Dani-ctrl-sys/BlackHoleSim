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

// --- VARIABLES GLOBALES DE LA CÁMARA ---
// Empezamos alejados en Z (frente al agujero)
float camX = 0.0f;
float camY = 0.0f;
float camZ = 5.0f; // 5 unidades de distancia

// --- VARIABLES DE TIEMPO ---
float deltaTime = 0.0f; // Tiempo entre frames
float lastFrame = 0.0f; // Tiempo del frame anterior

// Callback para redimensionar la ventana
void framebuffer_size_callback(GLFWwindow* window, int width, int height) {
    glViewport(0, 0, width, height);
}

// Procesar entrada del usuario
void processInput(GLFWwindow *window, float dt) {
    if(glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
        glfwSetWindowShouldClose(window, true);

        // VELOCIDAD REAL: 2.5 unidades por segundo
        // Si el PC es lento (dt grande), se mueve más distancia por paso.
        // Si el PC es rápido (dt pequeño), se mueve menos distancia por paso.
        // Resultado: SIEMPRE recorres 2.5 metros en 1 segundo real.
        float speed = 2.5f * dt;

        // Movimiento básico (sin delta time por ahora)
        if(glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS) camZ -= speed; // Acercarse
        if(glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS) camZ += speed; // Alejarse
        if(glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS) camX -= speed; // Izquierda
        if(glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS) camX += speed; // Derecha
        if(glfwGetKey(window, GLFW_KEY_Q) == GLFW_PRESS) camY += speed; // Subir
        if(glfwGetKey(window, GLFW_KEY_E) == GLFW_PRESS) camY -= speed; // Bajar
            
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

// Crea una textura de alta precisión (32-bit Float) para escritura arbitraria
unsigned int createComputeTexture(int width, int height){
    unsigned int texID;
    glGenTextures(1, &texID);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texID);

    // GL_RGBA32F: Aquí está la clave. 32 bits flotantes por canal (R,G,B,A).
    // Pasamos NULL al final porque no estamos copiando una imagen desde la CPU,
    // solo reservamos la memoria en la GPU.
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, width, height, 0, GL_RGBA, GL_FLOAT, NULL);

    // Filtros básicos
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    // --- MAGIA DE COMPUTE SHADER ---
    // glBindImageTexture conecta la textura a una "Image Unit" (unidad de imagen).
    // Esto permite que el shader escriba en ella usando imageStore().
    // 0 = Binding Unit (debe coincidir con el shader: layout(rgba32f, binding = 0))
    // GL_WRITE_ONLY = El shader solo escribirá en ella (optimización).
    glBindImageTexture(0, texID, 0, GL_FALSE, 0, GL_WRITE_ONLY, GL_RGBA32F);

    return texID;
}

unsigned int createComputeShaderProgram(const char* computePath){
    // 1. Leer el archivo
    std::string computeCode;
    std::ifstream cShaderFile;
    cShaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);
    try{
        cShaderFile.open(computePath);
        std::stringstream cShaderStream;
        cShaderStream << cShaderFile.rdbuf();
        cShaderFile.close();
        computeCode = cShaderStream.str();
    }
    catch(std::ifstream::failure& e){
        std::cout << "ERROR::SHADER::FILE_NOT_SUCCESFULLY_READ" << std::endl;
        return 0;
    }
    const char* cShaderCode = computeCode.c_str();

    // 2. Compilar (GL_COMPUTE_SHADER)
    unsigned int computeShader = glCreateShader(GL_COMPUTE_SHADER);
    glShaderSource(computeShader, 1, &cShaderCode, NULL);
    glCompileShader(computeShader);

    // Comprobar errores
    int success;
    char infoLog[512];
    glGetShaderiv(computeShader, GL_COMPILE_STATUS, &success);
    if(!success){
        glGetShaderInfoLog(computeShader, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::COMPUTE::COMPILATION_FAILED\n" << infoLog << std::endl;
    }

    // 3. Crear programa
    unsigned int shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, computeShader);
    glLinkProgram(shaderProgram);

    // Comprobar errores de linkado
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if(!success){
        glGetProgramInfoLog(shaderProgram, 512, NULL, infoLog);
        std::cout << "ERROR::SHADER::COMPUTE::LINKING_FAILED\n" << infoLog << std::endl;
    }

    glDeleteShader(computeShader);

    return shaderProgram;
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

    // Shader de pantalla "simple" que solo muestra la textura del compute shader
    unsigned int screenProgram = createShaderProgram("../shaders/vertex_core.glsl", "../shaders/fragment_screen.glsl");
    if (screenProgram == 0) {
        std::cerr << "ERROR: No se pudo cargar screenProgram" << std::endl;
        return -1;
    }
    std::cout << "✓ Screen shaders cargados correctamente" << std::endl;

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

    const float RENDER_SCALE = 0.25f;

    // 1. Cargar el Compute Shader (El "Cerebro" matemático)
    unsigned int computeProgram = createComputeShaderProgram("../shaders/raytracing.glsl");
    if (computeProgram == 0) {
        std::cerr << "ERROR: No se pudo cargar computeProgram" << std::endl;
        return -1;
    }
    std::cout << "✓ Compute shader cargado correctamente" << std::endl;

    // 2. Crear la Textura de Cómputo (El "Papel" donde escribirá)
    unsigned int computeTexture = createComputeTexture(WINDOW_WIDTH, WINDOW_HEIGHT);

    // 3. Activar el shader una vez para configurar uniformes estáticos (si los hubiera)
    glUseProgram(computeProgram);

    //Loop de renderizado
    while (!glfwWindowShouldClose(window)) {

        // --- 1. CÁLCULO DEL TIEMPO ---
        float currentFrame = glfwGetTime();
        deltaTime = currentFrame - lastFrame;
        lastFrame = currentFrame;

        // --- FASE DE CÓMPUTO ---
        glUseProgram(computeProgram);

        // Enviamos el tiempo para animaciones futuras
        glUniform1f(glGetUniformLocation(computeProgram, "u_time"), (float)glfwGetTime());
        
        // Enviar posición de la cámara al shader
        glUniform3f(glGetUniformLocation(computeProgram, "u_camPos"), camX, camY, camZ);

        // ¡LANZAMIENTO!
        // X = 100, Y = 75, Z = 1
        glDispatchCompute(100, 75, 1);

        // --- BARRERA DE MEMORIA (CRÍTICO) ---
        // Esto le dice a la GPU: "No empieces a dibujar píxeles (Fragment Shader)
        // hasta que el Compute Shader haya terminado de escribir en la textura".
        // Sin esto, verías parpadeos o basura porque leerías la textura mientras se escribe.
        glMemoryBarrier(GL_SHADER_IMAGE_ACCESS_BARRIER_BIT);
        
        // --- 2. PROCESAR LA ENTRADA (Le pasamos el tiempo calculado) ---
        processInput(window, deltaTime);

        // 1. Obtener tamaño real
        int width, height;
        glfwGetFramebufferSize(window, &width, &height);

        // Evitar división por cero al minimizar
        if (width == 0 || height == 0){
            glfwWaitEvents();
            continue;
        }

        // --- 3. DIBUJAR EN PANTALLA (Render Pass) ---
        // Limpiamos la pantalla normal
        glClear(GL_COLOR_BUFFER_BIT);

        // Activamos el shader "tonto"
        glUseProgram(screenProgram);

        // Conectamos la textura que rellenó el Compute Shader
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, computeTexture);
        
        // Le decimos al sampler (texOutput) que lea de la ranura 0
        glUniform1i(glGetUniformLocation(screenProgram, "texOutput"), 0);

        // Dibujamos el cuadrado de siempre
        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLES, 0, 6);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    // Limpieza
    glfwTerminate();
    return 0;
}
