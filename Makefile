# Makefile para StadiumGL - OpenGL/GLUT classic
# Uso:
#   make            compila o projeto
#   make run        compila e roda
#   make clean      remove o binário

CXX      = g++
CXXFLAGS = -std=c++17 -O2 -Wall -Wno-deprecated-declarations
TARGET   = stadium
SRC      = src/main.cpp

# Detecta plataforma e ajusta libs
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    # macOS: GLUT e OpenGL são frameworks. -Wno-deprecated silencia avisos
    # sobre GLUT estar deprecated no macOS (ainda funciona perfeitamente).
    LIBS = -framework OpenGL -framework GLUT
else
    # Linux: glut, GL e GLU como libs normais.
    # Em Ubuntu/Debian, instale antes: sudo apt install freeglut3-dev
    LIBS = -lGL -lGLU -lglut
endif

all: $(TARGET)

$(TARGET): $(SRC) include/stb_image.h
	$(CXX) $(CXXFLAGS) $(SRC) -o $(TARGET) $(LIBS)

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET)

.PHONY: all run clean
