# Entorno local: clúster kind (Terraform) e IA (Docker Compose). Toda la lógica está en scripts/local.sh.

ifeq ($(OS),Windows_NT)
# Se usa el Bash de Git: `bash` a secas puede ser el de WSL.
GIT_EXEC := $(shell git --exec-path)
BASH_BIN ?= $(subst /mingw64/libexec/git-core,,$(GIT_EXEC))/bin/bash.exe
else
BASH_BIN ?= bash
endif

# Solo los parámetros escritos en la línea de comandos, nunca variables de entorno con el mismo nombre.
PARAMS = $(foreach name,AI GPU ARGOCD CONFIRM,$(if $(findstring command line,$(origin $(name))),"$(name)=$($(name))"))
COMMANDS := help up status down clean credentials smoke validate

.DEFAULT_GOAL := help
.PHONY: $(COMMANDS)

$(COMMANDS):
	@"$(BASH_BIN)" scripts/local.sh $@ $(PARAMS)
