# Makefile for compiling required oct files

MKOCTFILE ?= mkoctfile

# Open CASCADE 7.8 or later, its visualization libraries and X11 are
# required.  Set OCCT_INC or X11_INC to use other locations.
OCCT_INC ?= /usr/include/opencascade
X11_INC ?= /usr/include
OCCT_LIBS = -lTKernel -lTKMath -lTKG2d -lTKG3d -lTKGeomBase -lTKBRep \
            -lTKTopAlgo -lTKPrim -lTKBO -lTKFillet -lTKOffset -lTKMesh \
            -lTKDESTEP -lTKXSBase -lTKDE -lTKXCAF -lTKLCAF -lTKCAF -lTKCDF \
            -lTKHLR -lTKShHealing
VIEW_LIBS = -lTKernel -lTKMath -lTKG3d -lTKBRep -lTKTopAlgo -lTKMesh \
            -lTKService -lTKV3d -lTKOpenGl -lX11
FONT_LIBS = -lTKernel -lTKMath -lTKG2d -lTKG3d -lTKGeomBase -lTKBRep \
            -lTKTopAlgo -lTKService -lTKV3d

APT = libocct-foundation-dev libocct-modeling-data-dev \
      libocct-modeling-algorithms-dev libocct-data-exchange-dev \
      libocct-visualization-dev libx11-dev

# 7.8 is the first release with the data exchange libraries linked above
OCCT_HDR = $(wildcard $(OCCT_INC)/Standard_Version.hxx)
ifeq ($(OCCT_HDR),)
$(error drafting needs Open CASCADE, not found in $(OCCT_INC); on Debian or \
  Ubuntu install $(APT), or set OCCT_INC)
endif
OCCT_VERSION := $(shell awk '/define OCC_VERSION_COMPLETE/ \
                  {gsub (/"/, "", $$3); print $$3}' $(OCCT_HDR))
OCCT_RECENT := $(shell awk '/define OCC_VERSION_MAJOR/ {M = $$3} \
                 /define OCC_VERSION_MINOR/ {m = $$3} \
                 END {if (M > 7 || (M == 7 && m >= 8)) print "yes"}' \
                 $(OCCT_HDR))
ifneq ($(OCCT_RECENT),yes)
$(error drafting needs Open CASCADE 7.8 or later, found $(OCCT_VERSION) in \
  $(OCCT_INC))
endif
ifeq ($(wildcard $(OCCT_INC)/StdPrs_BRepFont.hxx),)
$(error drafting needs the visualization libraries of Open CASCADE, not \
  found in $(OCCT_INC); on Debian or Ubuntu install libocct-visualization-dev)
endif
ifeq ($(wildcard $(X11_INC)/X11/Xlib.h),)
$(error drafting needs X11, not found in $(X11_INC); on Debian or Ubuntu \
  install libx11-dev, or set X11_INC)
endif

OCTFILES = __mesh__.oct __dxf__.oct __occt__.oct __occtfont__.oct
PROGRAMS = __occtview__

.PHONY: all FILES
all: $(OCTFILES) $(PROGRAMS) FILES

__mesh__.oct: __mesh__.cc
	$(MKOCTFILE) -O2 __mesh__.cc -lz

__dxf__.oct: __dxf__.cc
	$(MKOCTFILE) -O2 __dxf__.cc

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
