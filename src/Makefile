# Makefile for compiling required oct files

MKOCTFILE ?= mkoctfile

# Open CASCADE is optional.  Where its headers are not found, nothing is built
# and the solid namespace reports that the package was built without it; every
# other namespace works as before.  Set OCCT_INC to use another location.
OCCT_INC ?= /usr/include/opencascade
OCCT_LIBS = -lTKernel -lTKMath -lTKG3d -lTKBRep -lTKTopAlgo -lTKPrim -lTKBO \
            -lTKMesh -lTKDESTEP -lTKXSBase -lTKDE -lTKDESTL

ifneq ($(wildcard $(OCCT_INC)/Standard.hxx),)
OCTFILES = __occt__.oct
endif

.PHONY: all
all: $(OCTFILES)
ifeq ($(OCTFILES),)
	@echo "drafting: Open CASCADE not found in $(OCCT_INC);" \
	      "building without the solid namespace."
endif

__occt__.oct: __occt__.cc
	$(MKOCTFILE) -I$(OCCT_INC) __occt__.cc $(OCCT_LIBS)

.PHONY: clean
clean:
	rm -f *.o *.oct
