# Makefile for compiling required oct files

MKOCTFILE ?= mkoctfile

# Open CASCADE is optional.  Where its headers are not found, or are older
# than 7.8, nothing is built and the solid namespace reports that the package
# was built without it; every other namespace works as before.  Set OCCT_INC
# to use another location.  The viewer behind model.Viewer is a program of its
# own, built where the X11 headers are found as well.
OCCT_INC ?= /usr/include/opencascade
X11_INC ?= /usr/include
OCCT_LIBS = -lTKernel -lTKMath -lTKG2d -lTKG3d -lTKGeomBase -lTKBRep \
            -lTKTopAlgo -lTKPrim -lTKBO -lTKFillet -lTKOffset -lTKMesh \
            -lTKDESTEP -lTKXSBase -lTKDE
VIEW_LIBS = -lTKernel -lTKMath -lTKG3d -lTKBRep -lTKTopAlgo -lTKMesh \
            -lTKService -lTKV3d -lTKOpenGl -lX11
FONT_LIBS = -lTKernel -lTKMath -lTKG2d -lTKG3d -lTKGeomBase -lTKBRep \
            -lTKTopAlgo -lTKService -lTKV3d

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

# The triangle meshes behind the polymesh namespace need nothing but Octave
OCTFILES = __mesh__.oct

ifeq ($(OCCT_RECENT),yes)
OCTFILES += __occt__.oct
# The outlines of text come from Open CASCADE's visualization libraries
ifneq ($(wildcard $(OCCT_INC)/StdPrs_BRepFont.hxx),)
OCTFILES += __occtfont__.oct
endif
ifneq ($(wildcard $(X11_INC)/X11/Xlib.h),)
PROGRAMS = __occtview__
endif
endif

.PHONY: all FILES
all: $(OCTFILES) $(PROGRAMS) FILES
ifeq ($(OCCT_HDR),)
	@echo "drafting: Open CASCADE not found in $(OCCT_INC);" \
	      "building without the solid namespace."
else ifneq ($(OCCT_RECENT),yes)
	@echo "drafting: Open CASCADE $(OCCT_VERSION) found in $(OCCT_INC)," \
	      "7.8 or later is needed; building without the solid namespace."
endif

ifeq ($(OCCT_RECENT),yes)
ifeq ($(PROGRAMS),)
	@echo "drafting: X11 not found in $(X11_INC);" \
	      "building without the viewer behind model.Viewer."
endif
endif

__mesh__.oct: __mesh__.cc
	$(MKOCTFILE) -O2 __mesh__.cc

__occtfont__.oct: __occtfont__.cc
	$(MKOCTFILE) -I$(OCCT_INC) __occtfont__.cc $(FONT_LIBS)

__occt__.oct: __occt__.cc
	$(MKOCTFILE) -I$(OCCT_INC) __occt__.cc $(OCCT_LIBS)

__occtview__: __occtview__.cc
	$(shell $(MKOCTFILE) -p CXX) -O2 -I$(OCCT_INC) -I$(X11_INC) \
	  -o __occtview__ __occtview__.cc $(VIEW_LIBS)

# What pkg install copies: exactly what was built
FILES:
	@printf '%s\n' $(OCTFILES) $(PROGRAMS) > FILES

.PHONY: clean
clean:
	rm -f *.o *.oct __occtview__ FILES
