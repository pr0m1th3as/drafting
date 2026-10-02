# Makefile for compiling required oct files

MKOCTFILE ?= mkoctfile

# Open CASCADE is optional.  Where its headers are not found, or are older
# than 7.8, nothing is built and the solid namespace reports that the package
# was built without it; every other namespace works as before.  Set OCCT_INC
# to use another location.
OCCT_INC ?= /usr/include/opencascade
OCCT_LIBS = -lTKernel -lTKMath -lTKG3d -lTKBRep -lTKTopAlgo -lTKPrim -lTKBO \
            -lTKMesh -lTKDESTEP -lTKXSBase -lTKDE -lTKDESTL

# 7.8 is the first release with the data exchange libraries linked above
OCCT_HDR = $(wildcard $(OCCT_INC)/Standard_Version.hxx)
ifneq ($(OCCT_HDR),)
OCCT_VERSION := $(shell awk '/define OCC_VERSION_COMPLETE/ \
                  {gsub (/"/, "", $$3); print $$3}' $(OCCT_HDR))
OCCT_RECENT := $(shell awk '/define OCC_VERSION_MAJOR/ {M = $$3} \
                 /define OCC_VERSION_MINOR/ {m = $$3} \
                 END {if (M > 7 || (M == 7 && m >= 8)) print "yes"}' \
                 $(OCCT_HDR))
endif

ifeq ($(OCCT_RECENT),yes)
OCTFILES = __occt__.oct
endif

.PHONY: all
all: $(OCTFILES)
ifeq ($(OCCT_HDR),)
	@echo "drafting: Open CASCADE not found in $(OCCT_INC);" \
	      "building without the solid namespace."
else ifneq ($(OCCT_RECENT),yes)
	@echo "drafting: Open CASCADE $(OCCT_VERSION) found in $(OCCT_INC)," \
	      "7.8 or later is needed; building without the solid namespace."
endif

__occt__.oct: __occt__.cc
	$(MKOCTFILE) -I$(OCCT_INC) __occt__.cc $(OCCT_LIBS)

.PHONY: clean
clean:
	rm -f *.o *.oct
