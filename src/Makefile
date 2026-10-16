# Makefile for compiling required oct files

MKOCTFILE ?= mkoctfile

# Open CASCADE 7.8 or later, its visualization libraries and X11 are
# required.  They are looked for where distributions and source builds put
# them; set OCCT_INC, OCCT_LIB, X11_INC or X11_LIB to use other locations.
# On Windows Open CASCADE is looked for first in occt, where pre_install.m
# unpacks the build it fetches, then in Octave's own mingw64 folder, where
# its headers, import libraries and DLLs belong, and X11 is not used.  On
# macOS it is looked for first where Homebrew puts it, and X11 is not used
# either.
OCCT_DIRS = /usr/local/include/opencascade /usr/local/include/OpenCASCADE \
            /usr/include/opencascade
X11_DIRS = /usr/include /usr/local/include
X11 := yes
ifeq ($(OS),Windows_NT)
WINDOWS := yes
X11 :=
OCCT_DIRS := occt/include/opencascade /mingw64/include/opencascade \
             $(OCCT_DIRS)
else ifeq ($(shell uname -s),Darwin)
MACOS := yes
X11 :=
OCCT_DIRS := /opt/homebrew/include/opencascade $(OCCT_DIRS)
endif
ifndef OCCT_INC
OCCT_INC := $(patsubst %/Standard_Version.hxx,%,$(firstword \
              $(wildcard $(addsuffix /Standard_Version.hxx,$(OCCT_DIRS)))))
endif
ifdef X11
ifndef X11_INC
X11_INC := $(patsubst %/X11/Xlib.h,%,$(firstword \
             $(wildcard $(addsuffix /X11/Xlib.h,$(X11_DIRS)))))
endif
endif

# Libraries next to the headers, when not in a directory the linker searches
OCCT_PREFIX := $(firstword $(subst /include/, ,$(OCCT_INC)))
X11_PREFIX := $(patsubst %/include,%,$(X11_INC))
ifndef OCCT_LIB
OCCT_LIB := $(patsubst %/,%,$(dir $(firstword $(wildcard \
              $(OCCT_PREFIX)/lib/libTKernel.so* \
              $(OCCT_PREFIX)/lib64/libTKernel.so* \
              $(OCCT_PREFIX)/lib/*/libTKernel.so* \
              $(OCCT_PREFIX)/lib/libTKernel.dll.a \
              $(OCCT_PREFIX)/lib/libTKernel.dylib))))
endif
ifdef X11
ifndef X11_LIB
X11_LIB := $(patsubst %/,%,$(dir $(firstword $(wildcard \
             $(X11_PREFIX)/lib/libX11.so* \
             $(X11_PREFIX)/lib64/libX11.so*))))
endif
endif
LIB_DIRS = $(addprefix -L,$(sort $(OCCT_LIB) $(X11_LIB)))

# Libraries outside the loader's own directories are found at run time by the
# path the built files record, as at link time by the -L above.  It is
# recorded as RPATH, not RUNPATH: a RUNPATH serves only the file's own
# libraries, and Open CASCADE's record no path for the libraries they load.
comma := ,
RPATH_DIRS = $(filter-out /lib /lib64 /usr/lib /usr/lib64 /usr/lib/%, \
               $(sort $(OCCT_LIB) $(X11_LIB)))
RPATH = $(if $(RPATH_DIRS),-Wl$(comma)--disable-new-dtags \
          $(addprefix -Wl$(comma)-rpath$(comma),$(RPATH_DIRS)))

# Windows records no paths in its DLLs, finding them on PATH, and the
# viewer draws in a Win32 window, not an X11 one.  macOS's linker takes a
# plain -rpath and has no nodelete, so __occt__.oct pins itself there, and
# the viewer draws in a Cocoa window, its source compiled as Objective-C++.
ifdef WINDOWS
RPATH =
NODELETE =
WINDOW_LIBS = -luser32 -lgdi32
VIEWER = __occtview__.exe
else ifdef MACOS
RPATH = $(addprefix -Wl$(comma)-rpath$(comma),$(RPATH_DIRS))
NODELETE =
WINDOW_LIBS = -framework Cocoa
VIEW_FLAGS = -ObjC++
VIEWER = __occtview__
else
NODELETE = -Wl,-z,nodelete
WINDOW_LIBS = -lX11
VIEWER = __occtview__
endif
OCCT_LIBS = -lTKernel -lTKMath -lTKG2d -lTKG3d -lTKGeomBase -lTKGeomAlgo \
            -lTKBRep -lTKTopAlgo -lTKPrim -lTKBO -lTKFillet -lTKOffset \
            -lTKMesh -lTKDESTEP -lTKXSBase -lTKDE -lTKXCAF -lTKLCAF -lTKCAF \
            -lTKCDF -lTKHLR -lTKShHealing
VIEW_LIBS = -lTKernel -lTKMath -lTKG3d -lTKBRep -lTKTopAlgo -lTKMesh \
            -lTKService -lTKV3d -lTKOpenGl $(WINDOW_LIBS)
FONT_LIBS = -lTKernel -lTKMath -lTKG2d -lTKG3d -lTKGeomBase -lTKGeomAlgo -lTKBRep \
            -lTKTopAlgo -lTKService -lTKV3d

APT = libocct-foundation-dev libocct-modeling-data-dev \
      libocct-modeling-algorithms-dev libocct-data-exchange-dev \
      libocct-visualization-dev libx11-dev

# 7.8 is the first release with the data exchange libraries linked above
OCCT_HDR = $(wildcard $(OCCT_INC)/Standard_Version.hxx)
ifeq ($(OCCT_HDR),)
ifdef WINDOWS
$(error drafting needs Open CASCADE, not found in \
  $(or $(OCCT_INC),$(OCCT_DIRS)); unpack it into Octave's mingw64 folder, or \
  set OCCT_INC)
else ifdef MACOS
$(error drafting needs Open CASCADE, not found in \
  $(or $(OCCT_INC),$(OCCT_DIRS)); install opencascade with Homebrew, or set \
  OCCT_INC)
else
$(error drafting needs Open CASCADE, not found in \
  $(or $(OCCT_INC),$(OCCT_DIRS)); on Debian or Ubuntu install $(APT), or set \
  OCCT_INC)
endif
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
ifdef X11
ifeq ($(wildcard $(X11_INC)/X11/Xlib.h),)
$(error drafting needs X11, not found in $(or $(X11_INC),$(X11_DIRS)); \
  on Debian or Ubuntu install libx11-dev, or set X11_INC)
endif
endif

# Headers outside the system's own with no libraries beside them would be
# linked against the system's Open CASCADE, which may be another version
ifeq ($(OCCT_LIB),)
ifneq ($(OCCT_PREFIX),/usr)
$(error drafting found the Open CASCADE headers in $(OCCT_INC) but not \
  their libraries in $(OCCT_PREFIX)/lib or lib64; set OCCT_LIB)
endif
endif

OCTFILES = __mesh__.oct __dxf__.oct __occt__.oct __occtfont__.oct
PROGRAMS = $(VIEWER)

# The DLLs of the build pre_install.m fetched install beside the oct files,
# where Octave looks for what an oct file needs, and the viewer finds them
# on the PATH it is started with
ifeq ($(OCCT_INC),occt/include/opencascade)
DLLS = $(wildcard occt/bin/*.dll)
endif

.PHONY: all FILES
all: $(OCTFILES) $(PROGRAMS) FILES

__mesh__.oct: __mesh__.cc
	$(MKOCTFILE) -O2 __mesh__.cc -lz

__dxf__.oct: __dxf__.cc
	$(MKOCTFILE) -O2 __dxf__.cc

__occtfont__.oct: __occtfont__.cc shapebytes.h
	$(MKOCTFILE) -I$(OCCT_INC) __occtfont__.cc $(LIB_DIRS) $(RPATH) \
	  $(FONT_LIBS)

# Never unloaded: Open CASCADE's worker threads outlive the calls that start
# them, and would crash Octave at exit if their libraries went first; on
# Windows and macOS the file pins itself
__occt__.oct: __occt__.cc shapebytes.h
	$(MKOCTFILE) -I$(OCCT_INC) __occt__.cc $(LIB_DIRS) $(RPATH) \
	  $(OCCT_LIBS) $(NODELETE)

$(VIEWER): __occtview__.cc shapebytes.h
	$(shell $(MKOCTFILE) -p CXX) -O2 $(VIEW_FLAGS) -I$(OCCT_INC) \
	  $(addprefix -I,$(X11_INC)) -o $(VIEWER) __occtview__.cc $(LIB_DIRS) \
	  $(RPATH) $(VIEW_LIBS)

# What pkg install copies: exactly what was built, and the fetched DLLs
FILES:
	@printf '%s\n' $(OCTFILES) $(PROGRAMS) $(DLLS) > FILES

.PHONY: clean
clean:
	rm -f *.o *.oct __occtview__ __occtview__.exe FILES
