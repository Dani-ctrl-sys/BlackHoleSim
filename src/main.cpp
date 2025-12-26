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
const float ASPECT_RATIO = (float)WINDOW_WIDTH / (float)WINDOW_HEIGHT;
//Estructura simple para un vector de 3 componentes (Color RGB)
struct vec3 { float r,g,b;};

// --- MOTOR DE FÍSICA (CPU) ---
// Aquí es donde ocurrirá la magia de los Agujeros Negros más adelante.
// Por ahora, hacemos un "Ray Caster" simple: si el rayo golpea un círculo, pintamos blanco.
void RayTraceCPU(std::vector<float>& buffer, int w, int h, float aspect){
    for(int y=0; y < h; y++){
        for(int x=0; x < w; x++){
            //1. Normalizar coordenadas de píxel a espacio [-1, 1]
            // (Similar a lo que hacía tu shader, pero ahora en C++)
            float u = (float)x / (float)w * 2.0f - 1.0f;
            float v = (float)y / (float)h * 2.0f - 1.0f;

            //Corregir relación de aspecto (para que el círculo no se vea ovalado)
            u *= aspect;

            //2. Lógica de Trazado (Geometría básica)
            // Ecuación del círculo: x^2 + y^2 = r^2
            float dist = std::sqrt(u*u + v*v);
            
            vec3 color = {0.0f, 0.0f, 0.0f}; //Color base: Negro (Espacio)

            if(dist < 0.5f){
                // Si estamos dentro del radio 0.5, pintamos el "Agujero" (o planeta)
                color = {1.0f, 0.5f, 0.2f}; //Naranja
            } else{
                //Fondo con gradiente suave
                color = {0.1f, 0.1f, 0.2f};
            }

            //3. Escribir en el buffer (R, G, B)
            // OpenGL espera los datos en una fila larga plana
            int index = (y*w+x)*3;
            buffer[index + 0]=color.r;
            buffer[index + 1]=color.g;
            buffer[index + 2]=color.b;
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

        //1. CALCULAR FÍSICA (CPU)
        RayTraceCPU(pixelBuffer, WINDOW_WIDTH, WINDOW_HEIGHT, ASPECT_RATIO);

        //2. SUBIR DATOS A LA GPU
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, WINDOW_WIDTH, WINDOW_HEIGHT, 0, GL_RGB, GL_FLOAT, pixelBuffer.data());

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
