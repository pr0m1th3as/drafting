## Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>
##
## This file is part of the drafting package for GNU Octave.
##
## This program is free software; you can redistribute it and/or modify it under
## the terms of the GNU General Public License as published by the Free Software
## Foundation; either version 3 of the License, or (at your option) any later
## version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License along with
## this program; if not, see <http://www.gnu.org/licenses/>.

classdef Shape
  ## -*- texinfo -*-
  ## @deftp {drafting} solid.Shape
  ##
  ## A solid in millimetres, modelled through Open CASCADE.
  ##
  ## @code{solid.Shape} holds the exact boundary of one or more solids: every
  ## face a plane, cylinder, cone, sphere, torus or spline surface, every edge
  ## a line, circle or curve, with nothing approximated by facets.  It is what
  ## the functions of the @code{solid} namespace create, what the boolean
  ## operators combine, and what its @code{write} method saves as STEP for
  ## exchange or STL for printing.
  ##
  ## Primitives are made by
  ##
  ## @itemize
  ## @item @code{solid.box}
  ## @item @code{solid.cylinder}
  ## @item @code{solid.cone}
  ## @item @code{solid.sphere}
  ## @item @code{solid.ellipsoid}
  ## @item @code{solid.torus}
  ## @item @code{solid.wedge}
  ## @end itemize
  ##
  ## and solids from @code{+geom} objects by
  ##
  ## @itemize
  ## @item @code{solid.extrude}
  ## @item @code{solid.revolve}
  ## @item @code{solid.loft}
  ## @item @code{solid.sweep}
  ## @item @code{solid.helix}
  ## @end itemize
  ##
  ## A solid is made from a closed triangle mesh by @code{solid.polyhedron},
  ## and from a grid of points by @code{solid.surface}, which fits a surface
  ## through the grid and thickens it.  @code{hull} wraps shapes and points in
  ## their convex hull, and @code{solid.read} loads solids from a STEP file.
  ##
  ## Finally, shapes can be combined by the three boolean CAD operations, each
  ## taking any number of shapes:
  ##
  ## @multitable @columnfractions 0.25 0.75
  ## @headitem Method @tab Result
  ## @item @code{union} @tab the material of any of them
  ## @item @code{subtract} @tab the material of the first that is in none of
  ## the others
  ## @item @code{intersect} @tab the material common to all of them
  ## @end multitable
  ##
  ## Features are worked on a shape by methods: @code{hole} drills plain,
  ## counterbored, countersunk and tapping holes, @code{pocket} cuts a region
  ## into it, @code{fillet} and @code{chamfer} round or bevel edges, and
  ## @code{shell} hollows the shape.  The edges and faces they act on are
  ## chosen by @code{edges} and @code{faces}, by the kind of curve or surface,
  ## by direction and by position.  @code{section} cuts a shape with a plane
  ## into regions, which the @code{solid} functions build from again, and
  ## @code{projection} gives the outline of a shape seen along a direction as
  ## regions in the same way.
  ##
  ## The class is a @emph{value} class.  Every operation returns a new shape
  ## and leaves its operands unchanged, and a copy is independent of the
  ## original.  The empty shape adds nothing to a union and empties an
  ## intersection, and a boolean whose result holds no material, such as the
  ## intersection of two solids that do not meet, returns it.
  ##
  ## Octave's @code{save} does not keep a classdef object, so a shape is not
  ## saved as a value.  Save its @code{Data}, and make it again with
  ## @code{solid.Shape (@var{DATA})}, its @code{Colour} and @code{Name} set
  ## again; or write it to a STEP file with @code{solid.Shape.write}, which
  ## keeps both, and read it back with @code{solid.read}.
  ##
  ## @seealso{solid.box, solid.read, solid.Shape.write, solid.Shape.show}
  ## @end deftp

  properties (SetAccess = private, Hidden)

    Data = uint8 ([]);

  endproperties

  properties

    ## -*- texinfo -*-
    ## @deftp {solid.Shape} {property} Colour
    ##
    ## Colour of each solid
    ##
    ## An @math{N}-by-3 matrix of red, green and blue from 0 to 1, a row for
    ## each of the shape's @math{N} solids in the order
    ## @code{solid.Shape.numsolids} counts them, a row of @code{NaN} for a
    ## solid without a colour, or empty when none has one.  Assigning a single
    ## row colours every solid.  The viewer shows it, and a STEP file carries
    ## it out and in.  A transform keeps it, and each solid a boolean or a
    ## feature makes takes the colour of the first coloured solid it came
    ## from, so parts apart keep their own; the tools of @code{subtract} give
    ## none.
    ##
    ## @end deftp
    Colour = [];

    ## -*- texinfo -*-
    ## @deftp {solid.Shape} {property} Name
    ##
    ## Name of each solid
    ##
    ## A cell column of character vectors, one for each of the shape's
    ## @math{N} solids in the order @code{solid.Shape.numsolids} counts them,
    ## @qcode{''} for a solid without a name, or empty when none has one.
    ## Assigning a single character vector, or a cell of one, names every
    ## solid; a cell of @math{N} names each in turn.  A name is free text,
    ## kept as it is given and never read for meaning.  A STEP file carries
    ## it out and in, and a 3MF file out, as @code{solid.Shape.write}
    ## describes.  A transform keeps it, and each solid a boolean or a
    ## feature makes takes the name of the first named solid it came from, as
    ## it takes its colour by @code{solid.Shape.Colour}; the tools of
    ## @code{subtract} give none.
    ##
    ## @end deftp
    Name = {};

  endproperties

  methods (Hidden)

    function disp (this)

      if (isempty (this.Data))
        printf ("  solid.Shape: empty\n");
      else
        c = '';
        if (! isempty (this.Colour))
          c = ", coloured";
        endif
        if (! isempty (this.Name))
          c = [c, ", named"];
        endif
        sn = numsolids (this);
        sw = 'solid';
        if (sn != 1)
          sw = 'solids';
        endif
        fn = numfaces (this);
        fw = 'face';
        if (fn != 1)
          fw = 'faces';
        endif
        en = numedges (this);
        ew = 'edge';
        if (en != 1)
          ew = 'edges';
        endif
        printf ("  solid.Shape: %d %s, %d %s, %d %s%s\n", sn, sw, fn, fw, ...
                en, ew, c);
      endif

    endfunction

  endmethods

################################################################################
##                        ** Creating and combining **                        ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'Shape'           'union'           'subtract'        'intersect'          ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} solid.Shape ()
    ## @deftypefnx {solid.Shape} {@var{S} =} solid.Shape (@var{DATA})
    ##
    ## Make a shape.
    ##
    ## @code{@var{S} = solid.Shape ()} returns the empty shape, which holds
    ## nothing.
    ##
    ## @code{@var{S} = solid.Shape (@var{DATA})} wraps @var{DATA}, the bytes of
    ## a shape in Open CASCADE's binary format followed by a check of 16 bytes.
    ## This is how the functions of the @code{solid} namespace return what Open
    ## CASCADE computed, and it is not for direct use: bytes that do not begin
    ## with that format's signature, or whose check does not match them, are
    ## refused here.
    ##
    ## A shape holds solids and nothing else: bytes that hold a surface, a
    ## curve or a point outside a solid are refused.  An open surface is a
    ## @code{polymesh.Mesh}.
    ##
    ## The empty shape is where a shape built up in a loop starts: it adds
    ## nothing to a union, so the first pass needs no case of its own.
    ##
    ## @example
    ## @group
    ## ## A stair of four steps, gathered from nothing
    ## S = solid.Shape ();
    ## for k = 1:4
    ##   step = solid.box (40, 10, 5 * k);
    ##   S = union (S, translate (step, [0, 10 * (k - 1), 0]));
    ## endfor
    ## numsolids (S)
    ## @result{} 1
    ## @end group
    ## @end example
    ##
    ## @end deftypefn
    function this = Shape (DATA)

      if (nargin == 0)
        return;
      endif

      ## Input validation
      if (! isa (DATA, 'uint8') || ! (isempty (DATA) || isrow (DATA)))
        error ("solid.Shape: DATA must be a uint8 row vector.");
      endif
      sig = sprintf ("\nOpen CASCADE Topology V");
      if (! isempty (DATA) && (numel (DATA) < numel (sig)
                               || ! strcmp (char (DATA(1:numel (sig))), sig)))
        error ("solid.Shape: DATA is not an Open CASCADE shape.");
      endif
      if (! isempty (DATA))
        left = occt ('solid.Shape', 'strays', DATA);
        if (! isempty (left))
          error (strcat ("solid.Shape: DATA holds %s outside a solid,", ...
                         " and a shape holds solids only."), left);
        endif
      endif

      this.Data = DATA;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{C} =} union (@var{A}, @var{B}, @dots{})
    ##
    ## The union of shapes, the material of any of them.
    ##
    ## @code{@var{C} = union (@var{A}, @var{B}, @dots{})} takes any number of
    ## @code{solid.Shape} objects and combines them in one operation, which is
    ## several times faster than combining them a pair at a time.  Faces that
    ## end up in one plane and edges that end up on one line are merged, so
    ## the union of two blocks that share a face reads as one block of six
    ## faces.  A solid that meets no other is kept as it is, without an
    ## operation, so shapes side by side are combined at once.  Empty shapes
    ## add nothing, and the union of a single shape is that shape.
    ##
    ## Each solid of the result takes the colour of the first coloured solid
    ## it came from, as @code{solid.Shape.Colour} describes.
    ##
    ## @example
    ## @group
    ## ## Two blocks side by side become one block
    ## A = solid.box (10, 10, 10);
    ## B = translate (solid.box (10, 10, 10), [10, 0, 0]);
    ## numfaces (union (A, B))
    ## @result{} 6
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.subtract, solid.Shape.intersect}
    ## @end deftypefn
    function C = union (varargin)

      ## Input validation
      errmsg = checkoperands (varargin);
      if (! isempty (errmsg))
        error ("solid.Shape.union: %s", errmsg);
      endif

      S = varargin(! cellfun (@isempty, varargin));
      if (isempty (S))
        C = solid.Shape ();
      elseif (numel (S) == 1)
        C = S{1};
      else
        data = cellfun (@(x) x.Data, S, 'UniformOutput', false);
        r = occt ('solid.Shape.union', 'fuse', data{:});
        C = solid.Shape (r{1});
        [C.Colour, C.Name] = inherit (r{2}, S{:});
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{C} =} subtract (@var{A}, @var{B}, @dots{})
    ##
    ## The difference of shapes, the material of the first in none of the
    ## others.
    ##
    ## @code{@var{C} = subtract (@var{A}, @var{B}, @dots{})} removes from
    ## @var{A} the material of every later shape, all in one operation.  This
    ## is how a hole, a pocket or a slot is cut: model the material to remove
    ## and subtract it.  Drilling a plate with a hundred holes in one call is
    ## an order of magnitude faster than a hundred calls of one hole each.
    ##
    ## Removing empty shapes, or nothing, leaves @var{A}, and removing
    ## anything from the empty shape leaves the empty shape.
    ##
    ## A shape may hold solids that overlap, as the shape of an assembly
    ## does where its parts meet.  As a tool it removes the region its solids
    ## cover together, and as @var{A} each of its solids is cut on its own
    ## and kept apart from the others.
    ##
    ## Open CASCADE 7.8 can return @var{A} uncut and report success, as it
    ## does for a dome cut by a circle that starts in the plane of the dome's
    ## seam.  A shape that comes back without the faces of a tool that
    ## reaches inside it is refused with an error, not returned uncut.
    ##
    ## The result takes its colours from @var{A}; the shapes taken away give
    ## none, as @code{solid.Shape.Colour} describes.
    ##
    ## @example
    ## @group
    ## ## A plate drilled with twelve holes in one call
    ## plate = solid.box (100, 60, 8);
    ## [x, y] = meshgrid (10:16:90, [15, 45]);
    ## P = [x(:), y(:), zeros(numel (x), 1)];
    ## S = subtract (plate, copy (solid.cylinder (3, 8), P));
    ## numfaces (S)
    ## @result{} 18
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.union, solid.Shape.intersect}
    ## @end deftypefn
    function C = subtract (varargin)

      ## Input validation
      errmsg = checkoperands (varargin);
      if (! isempty (errmsg))
        error ("solid.Shape.subtract: %s", errmsg);
      endif

      C = varargin{1};
      tools = varargin(2:end);
      tools = tools(! cellfun (@isempty, tools));
      if (! isempty (C) && ! isempty (tools))
        data = cellfun (@(x) x.Data, tools, 'UniformOutput', false);
        r = occt ('solid.Shape.subtract', 'cut', C.Data, data{:});
        A = C;
        C = solid.Shape (r{1});
        tools = cellfun (@bare, tools, 'UniformOutput', false);
        [C.Colour, C.Name] = inherit (r{2}, A, tools{:});
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{C} =} intersect (@var{A}, @var{B}, @dots{})
    ##
    ## The intersection of shapes, the material common to all of them.
    ##
    ## @code{@var{C} = intersect (@var{A}, @var{B}, @dots{})} keeps only what
    ## lies inside every shape given.  Shapes that do not all meet, and an
    ## empty shape among them, give the empty shape.  The intersection of a
    ## single shape is that shape.
    ##
    ## Intersecting with a box trims a shape to the box, and intersecting two
    ## parts tells whether they collide: the volume of their intersection is
    ## the volume of the interference, and parts that stay apart give the
    ## empty shape.  Each solid of the result takes the colour of the first
    ## coloured solid it came from.
    ##
    ## A shape may hold solids that overlap, as the shape of an assembly
    ## does where its parts meet.  After the first it counts as the region
    ## its solids cover together, and each solid of @var{A} is intersected on
    ## its own and kept apart from the others, so intersecting a part with
    ## the shape of the assembly round it gives the interference with all its
    ## parts at once.
    ##
    ## @example
    ## @group
    ## ## A shaft through a gear, and the same shaft moved clear of it
    ## gear = solid.cylinder (20, 5);
    ## shaft = translate (solid.cylinder (4, 30), [0, 0, -10]);
    ## volume (intersect (gear, shaft))
    ## @result{} 251.33
    ## isempty (intersect (gear, translate (shaft, [30, 0, 0])))
    ## @result{} 1
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.union, solid.Shape.subtract}
    ## @end deftypefn
    function C = intersect (varargin)

      ## Input validation
      errmsg = checkoperands (varargin);
      if (! isempty (errmsg))
        error ("solid.Shape.intersect: %s", errmsg);
      endif

      if (any (cellfun (@isempty, varargin)))
        C = solid.Shape ();
      elseif (nargin == 1)
        C = varargin{1};
      else
        data = cellfun (@(x) x.Data, varargin, 'UniformOutput', false);
        r = occt ('solid.Shape.intersect', 'common', data{:});
        C = solid.Shape (r{1});
        [C.Colour, C.Name] = inherit (r{2}, varargin{:});
      endif

    endfunction

  endmethods

################################################################################
##                      ** Meshing, viewing and files **                      ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'tessellate'      'show'            'write'                                ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{M} =} tessellate (@var{S})
    ## @deftypefnx {solid.Shape} {@var{M} =} tessellate (@var{S}, @var{TOL})
    ##
    ## A triangle mesh of a shape.
    ##
    ## @code{@var{M} = tessellate (@var{S}, @var{TOL})} returns a
    ## @code{polymesh.Mesh} of the surface of @var{S}: flat triangles whose
    ## corners lie on it and which stray from it by at most @var{TOL}
    ## millimetres, 0.01 by default, nor span more than 20 degrees of a
    ## curved face.  The triangles meet edge to edge, sharing their corners,
    ## and are turned outwards, so the mesh of a solid is closed.  A coloured
    ## shape gives each triangle the colour of its solid as the mesh's
    ## @code{FaceColour}, and the grey @code{[0.72, 0.74, 0.78]} where its
    ## solid has none.  The empty shape gives the empty mesh.
    ##
    ## This is the mesh @code{write} writes to STL, OBJ, PLY and 3MF, and it
    ## can be shown, cut, measured, coloured and written as any other.
    ##
    ## @example
    ## @group
    ## M = tessellate (solid.cylinder (4, 12), 0.05);
    ## write (M, 'pin.obj');
    ## @end group
    ## @end example
    ##
    ## @seealso{polymesh.Mesh, solid.Shape.write, solid.polyhedron}
    ## @end deftypefn
    function M = tessellate (this, TOL = 0.01)

      ## Input validation
      if (! (isfloat (TOL) && isreal (TOL) && isscalar (TOL) &&
             isfinite (TOL) && TOL > 0))
        error (strcat ("solid.Shape.tessellate: TOL must be a positive", ...
                       " and finite real scalar."));
      endif

      if (isempty (this.Data))
        M = polymesh.Mesh ();
        return;
      endif
      M = meshof (this, TOL, 'solid.Shape.tessellate');

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {} show (@var{S})
    ## @deftypefnx {solid.Shape} {@var{V} =} show (@var{S})
    ##
    ## Show a shape in a viewer of its own, redrawing in place.
    ##
    ## @code{show (@var{S})} shows the shape @var{S} in a
    ## @code{model.Viewer}, a window drawn by Open CASCADE in a process of
    ## its own.  Every variable gets a viewer of its own, titled with its
    ## name: the first @code{show (part)} opens the window for @code{part},
    ## and every later one redraws that window in place and keeps the camera
    ## where it was, while @code{show (tool)} uses another.  So a script that
    ## ends by showing its parts can be run again and again, @code{clear all}
    ## and all, and each part changes in its own window.  A shape given as an
    ## expression rather than a variable, such as @code{show (fillet (part,
    ## E, 3))}, has no name, and all such shapes share one window.
    ##
    ## Drag with the left mouse button to rotate, keeping @math{z} up, the
    ## middle one to pan, and turn the wheel to zoom; @kbd{F} fits the part to
    ## the window, @kbd{0}, @kbd{1}, @kbd{2} and @kbd{3} turn it to the
    ## isometric, front, top and right views, and @kbd{T} lets it turn any way
    ## or keeps @math{z} up again.  Closing a window ends its viewer, and the
    ## next
    ## @code{show} of that variable opens a new one.  Showing the empty shape
    ## opens a variable's window before there is anything to draw in it.
    ##
    ## @code{@var{V} = show (@var{S})} also returns the viewer.  Assigning to
    ## @code{@var{V}.Model} redraws it at once, and
    ## @code{model.Viewer.pick} picks edges and faces with the mouse:
    ##
    ## @example
    ## @group
    ## part = solid.box (80, 40, 12);
    ## V = show (part);
    ## E = pick (V, 'edge');     # click the edges, then press Enter
    ## V.Model = fillet (V.Model, E, 3);
    ## @end group
    ## @end example
    ##
    ## Calling @code{show (@var{S})} is the same as assigning @var{S} to the
    ## @code{Model} of the variable's viewer.  Nothing else redraws it:
    ## changing the variable that was shown does not, until it is shown again.
    ##
    ## The viewer is built with the package, and needs a display to run.  It
    ## runs on Linux, FreeBSD, Windows and macOS.
    ##
    ## @seealso{model.Viewer, model.Viewer.pick, polymesh.Mesh.show}
    ## @end deftypefn
    function V = show (this)

      viewer = model.Viewer.__named__ (inputname (1, false));
      viewer.Model = this;
      if (nargout > 0)
        V = viewer;
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {} write (@var{S}, @var{FILE})
    ## @deftypefnx {solid.Shape} {} write (@var{S}, @var{FILE}, @qcode{'Tolerance'}, @var{TOL})
    ##
    ## Write a solid to a STEP, STL, OBJ, PLY or 3MF file.
    ##
    ## @code{write (@var{S}, @var{FILE})} writes the shape @var{S} in the format
    ## named by the extension of @var{FILE}, in either case:
    ##
    ## @table @asis
    ## @item @file{.step}, @file{.stp}
    ## STEP (ISO 10303-21, application protocol 214), in millimetres.  The
    ## exact geometry is kept, so this is the file to send to a CAD program or
    ## to another manufacturer.  The part is named after the base name of
    ## @var{FILE}, and each solid carries its @code{solid.Shape.Colour} and,
    ## as the name of the solid itself, its @code{solid.Shape.Name}.
    ##
    ## @item @file{.stl}, @file{.obj}, @file{.ply}, @file{.3mf}
    ## A mesh of triangles in millimetres, the mesh
    ## @code{solid.Shape.tessellate} makes, written by
    ## @code{polymesh.Mesh.write}: binary STL, OBJ, binary PLY, or 3MF, the
    ## archive slicers take.  The facets approximate every curved surface;
    ## their vertices lie on it.  OBJ, PLY and 3MF carry the solids' colours on
    ## their triangles; STL has none.  A 3MF file holds one object, named
    ## after the base name of @var{FILE}, or for a named shape an object for
    ## each name its solids carry, named by it, the solids without one an
    ## object without a name, and these placed in a group named after
    ## @var{FILE} when there are several.
    ## @end table
    ##
    ## @code{write (@dots{}, @qcode{'Tolerance'}, @var{TOL})} sets, for a
    ## mesh, the largest distance in millimetres between a facet and the true
    ## surface.  It is 0.01 by default, well below what a printer resolves; a
    ## larger value gives a smaller file.  No facet spans more than 20 degrees
    ## of a curved surface, whatever @var{TOL}.  A STEP file is exact and takes
    ## no tolerance.
    ##
    ## The empty shape has nothing to write and is refused, and so is a
    ## folder that does not exist.
    ##
    ## @example
    ## @group
    ## ## Exact for a CAD program, and a coarser mesh for a slicer
    ## S = subtract (solid.box (40, 30, 10), ...
    ##               translate (solid.cylinder (5, 10), [20, 15, 0]));
    ## write (S, 'block.step');
    ## write (S, 'block.stl', 'Tolerance', 0.05);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.read, solid.Shape.tessellate, polymesh.Mesh.write}
    ## @end deftypefn
    function write (this, FILE, varargin)

      ## Input validation
      if (nargin < 2)
        error ("solid.Shape.write: invalid number of input arguments.");
      endif
      if (! ischar (FILE) || ! isrow (FILE) || isempty (FILE))
        error (strcat ("solid.Shape.write: FILE must be a non-empty", ...
                       " character vector."));
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("solid.Shape.write: Name/Value arguments must come in pairs.");
      endif
      opt = struct ('Tolerance', []);
      for ii = 1:2:numel (varargin)
        name = varargin{ii};
        val = varargin{ii+1};
        if (! ischar (name) || ! isrow (name))
          error ("solid.Shape.write: option names must be character vectors.");
        endif
        switch (lower (name))
          case 'tolerance'
            if (isempty (val))
              error ("solid.Shape.write: Tolerance must not be empty.");
            endif
            opt.Tolerance = val;
          otherwise
            error ("solid.Shape.write: unknown option '%s'.", name);
        endswitch
      endfor
      [folder, base, ext] = fileparts (FILE);
      isstep = any (strcmpi (ext, {'.step', '.stp'}));
      if (! isstep
          && ! any (strcmpi (ext, {'.stl', '.obj', '.ply', '.3mf'})))
        error (strcat ("solid.Shape.write: FILE must end in .step, .stp,", ...
                       " .stl, .obj, .ply or .3mf."));
      endif
      if (isstep && ! isempty (opt.Tolerance))
        error ("solid.Shape.write: Tolerance applies to meshes only.");
      endif
      if (isempty (opt.Tolerance))
        opt.Tolerance = 0.01;
      endif
      if (! (isfloat (opt.Tolerance) && isreal (opt.Tolerance) &&
             isscalar (opt.Tolerance) && isfinite (opt.Tolerance) &&
             opt.Tolerance > 0))
        error (strcat ("solid.Shape.write: Tolerance must be a positive", ...
                       " and finite real scalar."));
      endif
      if (! isempty (folder) && ! isfolder (folder))
        error ("solid.Shape.write: folder '%s' does not exist.", folder);
      endif
      if (isempty (this))
        error (strcat ("solid.Shape.write: S is empty, so there is", ...
                       " nothing to write."));
      endif

      if (isstep)
        __occt__ ('writestep', 'solid.Shape.write', this.Data, FILE, base, ...
                  this.Colour, this.Name);
      elseif (strcmpi (ext, '.3mf') && ! isempty (this.Name))
        write3mf (this, FILE, base, opt.Tolerance);
      else
        write (tessellate (this, opt.Tolerance), FILE);
      endif

    endfunction

  endmethods

################################################################################
##                              ** Transforms **                              ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'translate'       'rotate'          'mirror'          'scale'              ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{S} =} translate (@var{S}, @var{V})
    ##
    ## Move a shape by the vector @var{V}.
    ##
    ## @var{V} is a 3-element vector in millimetres.
    ##
    ## Like every method, it returns a new shape and leaves @var{S} as it was,
    ## so one part can be placed many times.  The solids keep their colours.
    ##
    ## @example
    ## @group
    ## A = solid.box (10, 10, 10);
    ## B = translate (A, [0, 0, 10]);
    ## bbox (B)
    ## @result{} 0   0   10   10   10   20
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.rotate, solid.Shape.mirror, solid.Shape.scale}
    ## @end deftypefn
    function this = translate (this, V)

      ## Input validation
      if (nargin != 2)
        error ("solid.Shape.translate: invalid number of input arguments.");
      endif
      errmsg = checkvec (V, 'V');
      if (! isempty (errmsg))
        error ("solid.Shape.translate: %s", errmsg);
      endif

      if (! isempty (this.Data))
        this.Data = occt ('solid.Shape.translate', 'translate', this.Data, ...
                          double (V));
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} rotate (@var{S}, @var{ANGLE}, @var{AXIS})
    ## @deftypefnx {solid.Shape} {@var{S} =} rotate (@var{S}, @var{ANGLE}, @var{AXIS}, @var{P})
    ##
    ## Rotate a shape about an axis.
    ##
    ## @var{ANGLE} is in degrees and turns the shape anticlockwise when seen
    ## from the tip of @var{AXIS} looking back, the right-hand rule.
    ## @var{AXIS} is a nonzero 3-element direction, and @var{P} a point on the
    ## axis, the origin by default.
    ##
    ## To turn a shape in place, give its own centroid as @var{P}.  The
    ## solids keep their colours.
    ##
    ## @example
    ## @group
    ## ## A pin standing along z, laid down along x
    ## [~, L] = bbox (rotate (solid.cylinder (2, 20), 90, [0, 1, 0]))
    ## @result{} L = 20   4   4
    ##
    ## ## A block turned a quarter about its own centre
    ## S = solid.box (20, 10, 5);
    ## bbox (rotate (S, 90, [0, 0, 1], centroid (S)))
    ## @result{} 5   -5   0   15   15   5
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.translate, solid.Shape.mirror, solid.Shape.scale}
    ## @end deftypefn
    function this = rotate (this, ANGLE, AXIS, P = [0, 0, 0])

      ## Input validation
      if (nargin < 3 || nargin > 4)
        error ("solid.Shape.rotate: invalid number of input arguments.");
      endif
      if (! isfloat (ANGLE) || ! isreal (ANGLE) || ! isscalar (ANGLE)
          || ! isfinite (ANGLE))
        error ("solid.Shape.rotate: ANGLE must be a finite real scalar.");
      endif
      errmsg = checkvec (AXIS, 'AXIS', true);
      if (isempty (errmsg))
        errmsg = checkvec (P, 'P');
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.rotate: %s", errmsg);
      endif

      if (! isempty (this.Data))
        this.Data = occt ('solid.Shape.rotate', 'rotate', this.Data, ...
                          double (ANGLE), double (AXIS), double (P));
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} mirror (@var{S}, @var{N})
    ## @deftypefnx {solid.Shape} {@var{S} =} mirror (@var{S}, @var{N}, @var{P})
    ##
    ## Reflect a shape in a plane.
    ##
    ## The plane passes through the point @var{P}, the origin by default, with
    ## the nonzero 3-element normal @var{N}.  @code{mirror (@var{S}, [1, 0,
    ## 0])} reflects in the @math{yz} plane.  A reflection turns a right-handed
    ## part into its left-handed twin; the result is a valid solid of the same
    ## volume.
    ##
    ## The solids keep their colours.
    ##
    ## @example
    ## @group
    ## ## An L-shaped bracket and its mirror image, joined into one part
    ## L = union (solid.box (30, 10, 5), solid.box (5, 10, 20));
    ## S = union (L, mirror (L, [1, 0, 0]));
    ## bbox (S)
    ## @result{} -30   0   0   30   10   20
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.translate, solid.Shape.rotate, solid.Shape.scale}
    ## @end deftypefn
    function this = mirror (this, N, P = [0, 0, 0])

      ## Input validation
      if (nargin < 2 || nargin > 3)
        error ("solid.Shape.mirror: invalid number of input arguments.");
      endif
      errmsg = checkvec (N, 'N', true);
      if (isempty (errmsg))
        errmsg = checkvec (P, 'P');
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.mirror: %s", errmsg);
      endif

      if (! isempty (this.Data))
        this.Data = occt ('solid.Shape.mirror', 'mirror', this.Data, ...
                          double (N), double (P));
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} scale (@var{S}, @var{F})
    ## @deftypefnx {solid.Shape} {@var{S} =} scale (@var{S}, @var{F}, @var{P})
    ##
    ## Scale a shape uniformly about a point.
    ##
    ## Every length is multiplied by the positive factor @var{F}, so the volume
    ## grows by its cube.  @var{P}, the origin by default, is the point that
    ## stays where it is.
    ##
    ## To bring a shape to a size, each axis on its own if need be, use
    ## @code{solid.Shape.resize}.  The solids keep their colours.
    ##
    ## @example
    ## @group
    ## ## A ball doubled about its own centre, eight times the volume
    ## S = translate (solid.sphere (5), [20, 0, 0]);
    ## T = scale (S, 2, [20, 0, 0]);
    ## volume (T) / volume (S)
    ## @result{} 8
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.translate, solid.Shape.rotate, solid.Shape.mirror,
    ## solid.Shape.resize}
    ## @end deftypefn
    function this = scale (this, F, P = [0, 0, 0])

      ## Input validation
      if (nargin < 2 || nargin > 3)
        error ("solid.Shape.scale: invalid number of input arguments.");
      endif
      if (! (isfloat (F) && isreal (F) && isscalar (F) && isfinite (F) &&
             F > 0))
        error (strcat ("solid.Shape.scale: F must be a positive", ...
                       " and finite real scalar."));
      endif
      errmsg = checkvec (P, 'P');
      if (! isempty (errmsg))
        error ("solid.Shape.scale: %s", errmsg);
      endif

      if (! isempty (this.Data))
        this.Data = occt ('solid.Shape.scale', 'scale', this.Data, ...
                          double (F), double (P));
      endif

    endfunction

  endmethods

################################################################################
##                               ** Measures **                               ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'volume'          'area'            'centroid'        'bbox'               ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{V} =} volume (@var{S})
    ## @deftypefnx {solid.Shape} {@var{V} =} volume (@var{S}, @qcode{'RelTol'}, @var{TOL})
    ##
    ## The volume of a shape in cubic millimetres.
    ##
    ## The volume is computed from the exact surfaces, not from facets, by an
    ## integration that aims at a relative error of @var{TOL} on every face,
    ## 1e-9 unless @qcode{'RelTol'} sets it.  @var{TOL} must be positive and
    ## no larger than 1e-3.  The empty shape has volume zero.
    ##
    ## Multiplied by a density it gives the mass of a part.  Most shapes take
    ## milliseconds.  The spline surfaces of a shape made by
    ## @code{solid.surface} take seconds, and there a @qcode{'RelTol'} of 1e-6
    ## is about three times faster, at an error of up to about 1e-7 on spline
    ## faces.  @var{TOL} is a target, not a guarantee: on the hardest faces the
    ## integration may stop short of it.
    ##
    ## @example
    ## @group
    ## ## The mass in grams of a steel block with a bore, steel weighing
    ## ## 7.85e-3 grams per cubic millimetre
    ## S = subtract (solid.box (80, 40, 12), ...
    ##               translate (solid.cylinder (4, 12), [20, 20, 0]));
    ## mass = volume (S) * 7.85e-3
    ## @result{} mass = 296.70
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.area, solid.Shape.centroid}
    ## @end deftypefn
    function V = volume (this, varargin)

      [errmsg, TOL] = reltol (varargin);
      if (! isempty (errmsg))
        error ("solid.Shape.volume: %s", errmsg);
      endif
      if (isempty (this.Data))
        V = 0;
      else
        V = occt ('solid.Shape.volume', 'volume', this.Data, TOL);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{A} =} area (@var{S})
    ##
    ## The surface area of a shape in square millimetres.
    ##
    ## The area is the sum over every face, computed from the exact surfaces.
    ## A flat face is measured exactly, whatever its edges, and so is a
    ## cylinder, a cone, a sphere, a torus, or a face extruded or revolved from
    ## a spline, the walls of text included.  Any other curved face, as a loft,
    ## a sweep along a curve or a surface through a grid makes, is measured as
    ## Open CASCADE integrates it, to about 1e-6.  The empty shape has area
    ## zero.
    ##
    ## It is what a coating, a plating or a coat of paint is reckoned by.
    ##
    ## @example
    ## @group
    ## ## A sphere of radius 10, whose area is 4 pi r^2
    ## area (solid.sphere (10))
    ## @result{} 1256.6
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.volume}
    ## @end deftypefn
    function A = area (this)

      if (isempty (this.Data))
        A = 0;
      else
        A = occt ('solid.Shape.area', 'area', this.Data);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{C} =} centroid (@var{S})
    ## @deftypefnx {solid.Shape} {@var{C} =} centroid (@var{S}, @qcode{'RelTol'}, @var{TOL})
    ##
    ## The centre of volume of a shape, as a 1-by-3 vector in millimetres.
    ##
    ## For a part of uniform density this is its centre of mass, computed as
    ## the volume is, @qcode{'RelTol'} included.  The empty shape has no
    ## centroid and returns an empty @var{C}, and a shape that encloses no
    ## volume returns @code{NaN} in every coordinate.
    ##
    ## The centre takes far longer to integrate than the volume: a second or
    ## more on a sphere, a cone or a torus, and a minute or more on the
    ## spline surfaces of a shape made by @code{solid.surface}, where a looser
    ## @qcode{'RelTol'} saves little.
    ##
    ## @example
    ## @group
    ## ## An L-shaped bracket balances off its corner
    ## L = union (solid.box (30, 10, 5), solid.box (5, 10, 20));
    ## centroid (L)
    ## @result{} 10.8333    5.0000    5.8333
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.volume, solid.Shape.bbox}
    ## @end deftypefn
    function C = centroid (this, varargin)

      [errmsg, TOL] = reltol (varargin);
      if (! isempty (errmsg))
        error ("solid.Shape.centroid: %s", errmsg);
      endif
      if (isempty (this.Data))
        C = [];
      else
        C = occt ('solid.Shape.centroid', 'centroid', this.Data, TOL);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{B} =} bbox (@var{S})
    ## @deftypefnx {solid.Shape} {[@var{B}, @var{L}] =} bbox (@var{S})
    ##
    ## Axis-aligned extents of a shape.
    ##
    ## @var{B} is the 1-by-6 vector @code{[@var{xmin}, @var{ymin}, @var{zmin},
    ## @var{xmax}, @var{ymax}, @var{zmax}]} in millimetres, and @var{L} the
    ## 1-by-3 vector of the lengths along each axis.
    ##
    ## The box is computed from the exact surfaces, with no allowance for the
    ## tolerance Open CASCADE carries on its edges, so a cylinder of radius 4
    ## reaches exactly 4 from its axis.  On planes, cylinders, cones and
    ## spheres it is tight; on a torus or a spline surface it may exceed the
    ## true extent by up to 1e-7 millimetres, the precision Open CASCADE
    ## computes it to there.  The empty shape has no extent and returns an
    ## empty @var{B} and @var{L}.
    ##
    ## @example
    ## @group
    ## [B, L] = bbox (solid.cylinder (4, 10))
    ## @result{} B = -4   -4   0   4   4   10
    ## @result{} L = 8   8   10
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.centroid, geom.bbox}
    ## @end deftypefn
    function [B, L] = bbox (this)

      if (isempty (this.Data))
        B = [];
        L = [];
      else
        B = occt ('solid.Shape.bbox', 'bbox', this.Data);
        L = B(4:6) - B(1:3);
      endif

    endfunction

  endmethods

################################################################################
##                               ** Queries **                                ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'isvalid'         'isempty'         'numsolids'       'numfaces'           ##
## 'numedges'        'solids'                                                 ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{TF} =} isvalid (@var{S})
    ##
    ## True if a shape passes Open CASCADE's validity check.
    ##
    ## The check confirms that the faces close up, that the edges lie on the
    ## surfaces they bound, and that nothing intersects itself.  Every shape
    ## made by the @code{solid} namespace should pass; a failure means that an
    ## operation went wrong, usually a boolean between faces that nearly but
    ## not quite coincide, and the shape should not be written or drawn.  The
    ## empty shape is valid.
    ##
    ## A test of a part can assert it after the booleans that made it.
    ##
    ## @example
    ## @group
    ## S = subtract (solid.box (20, 20, 20), ...
    ##               translate (solid.sphere (8), [10, 10, 20]));
    ## isvalid (S)
    ## @result{} 1
    ## @end group
    ## @end example
    ##
    ## @end deftypefn
    function TF = isvalid (this)

      if (isempty (this.Data))
        TF = true;
      else
        TF = occt ('solid.Shape.isvalid', 'valid', this.Data);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{TF} =} isempty (@var{S})
    ##
    ## True for the empty shape, which holds no material.
    ##
    ## @code{@var{TF} = isempty (@var{S})} is true for the shape
    ## @code{solid.Shape ()} returns and for the result of a boolean that
    ## leaves no material, such as the intersection of shapes that do not
    ## meet.  A boolean returns the empty shape rather than raising an error,
    ## so a script tests for it here.  It has no volume, area, faces or
    ## extent, and @code{solid.Shape.write} refuses it.  For an array of
    ## shapes, @var{TF} is true when the array has no elements.
    ##
    ## @example
    ## @group
    ## A = solid.box (10, 10, 10);
    ## isempty (intersect (A, translate (A, [20, 0, 0])))
    ## @result{} 1
    ## isempty (intersect (A, translate (A, [5, 0, 0])))
    ## @result{} 0
    ## @end group
    ## @end example
    ##
    ## @end deftypefn
    function TF = isempty (this)

      if (! isscalar (this))
        TF = (numel (this) == 0);
      else
        TF = isempty (this.Data);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{N} =} numsolids (@var{S})
    ##
    ## The number of separate solids in a shape.
    ##
    ## A boolean can leave more than one: cutting a bar across its whole
    ## section leaves two.
    ##
    ## @example
    ## @group
    ## bar = solid.box (60, 10, 10);
    ## cut = translate (solid.box (2, 20, 20), [29, -5, -5]);
    ## numsolids (subtract (bar, cut))
    ## @result{} 2
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.numfaces, solid.Shape.numedges}
    ## @end deftypefn
    function N = numsolids (this)

      N = topology (this, 'solid', 'solid.Shape.numsolids');

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{N} =} numfaces (@var{S})
    ##
    ## The number of faces of a shape.
    ##
    ## A box has six.  A cylinder has three, its curved side being one face.
    ##
    ## It is a quick check that a feature did what was meant: a bore adds one
    ## face, and a fillet one for each edge it rounds.
    ##
    ## @example
    ## @group
    ## ## Six flat faces and the bore
    ## S = subtract (solid.box (40, 30, 10), ...
    ##               translate (solid.cylinder (5, 10), [20, 15, 0]));
    ## numfaces (S)
    ## @result{} 7
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.numsolids, solid.Shape.numedges}
    ## @end deftypefn
    function N = numfaces (this)

      N = topology (this, 'face', 'solid.Shape.numfaces');

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{N} =} numedges (@var{S})
    ##
    ## The number of edges of a shape, each counted once.
    ##
    ## An edge shared by two faces is one edge.  A box has twelve.  A cylinder
    ## has three: its two circles and the seam where its curved face closes on
    ## itself, which bounds that face but is not a feature of the part.
    ##
    ## @example
    ## @group
    ## numedges (solid.box (10, 20, 30))
    ## @result{} 12
    ## numedges (solid.cylinder (5, 10))
    ## @result{} 3
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.numsolids, solid.Shape.numfaces}
    ## @end deftypefn
    function N = numedges (this)

      N = topology (this, 'edge', 'solid.Shape.numedges');

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{L} =} solids (@var{S})
    ##
    ## The solids of a shape, one by one.
    ##
    ## @code{@var{L} = solids (@var{S})} returns an @math{N}-by-1 struct
    ## array, an element for each of the shape's @math{N} solids in the order
    ## @code{solid.Shape.numsolids} counts them, with the fields:
    ##
    ## @multitable @columnfractions 0.15 0.85
    ## @item @code{index} @tab its index, from 1 to @math{N}
    ## @item @code{name} @tab its @code{solid.Shape.Name}, @qcode{''} where it
    ## has none
    ## @item @code{colour} @tab its @code{solid.Shape.Colour}, a row of
    ## @code{NaN} where it has none
    ## @item @code{path} @tab an empty cell, since a shape places nothing
    ## @item @code{part} @tab @qcode{''}, for the same reason
    ## @end multitable
    ##
    ## @code{model.Assembly.solids} lists the solids of an assembly with the
    ## same fields, and @code{model.Viewer.opacity} takes the names either
    ## gives to choose which solids to hide or show through.
    ##
    ## @example
    ## @group
    ## S = union (solid.box (10, 10, 10), ...
    ##            translate (solid.sphere (4), [30, 0, 0]));
    ## S.Name = @{'block'; 'ball'@};
    ## L = solids (S);
    ## L(2).name
    ## @result{} ball
    ## @end group
    ## @end example
    ##
    ## @seealso{model.Assembly.solids, model.Viewer.opacity,
    ## solid.Shape.numsolids}
    ## @end deftypefn
    function L = solids (this)

      N = numsolids (this);
      name = this.Name;
      if (isempty (name))
        name = repmat ({''}, N, 1);
      endif
      C = this.Colour;
      if (isempty (C))
        C = NaN (N, 3);
      endif
      L = struct ('index', num2cell ((1:N)'), 'name', name, ...
                  'colour', num2cell (C, 2), 'path', {cell(1, 0)}, ...
                  'part', '');

    endfunction

  endmethods

################################################################################
##                           ** Edges and faces **                            ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'edges'           'faces'                                                  ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{E} =} edges (@var{S})
    ## @deftypefnx {solid.Shape} {@var{E} =} edges (@var{S}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Choose edges of a shape, to round, chamfer or inspect.
    ##
    ## @code{@var{E} = edges (@var{S})} returns the indices of the edges of
    ## @var{S} as a row vector, in the order @code{solid.Shape.numedges}
    ## counts them.  Seam edges, where a curved face closes on itself, and the
    ## degenerate edges at the poles of a sphere are left out: they bound
    ## faces without being features of the part, and nothing can be done to
    ## them.
    ##
    ## The indices belong to @var{S} alone.  Every operation that makes a new
    ## shape numbers its edges afresh, so choose edges from the shape the
    ## feature is applied to, immediately before applying it.
    ##
    ## Name/Value pairs narrow the choice, and an edge is returned only when
    ## it meets all of them:
    ##
    ## @table @asis
    ## @item @qcode{'Type'}
    ## The kind of curve the edge lies on: @qcode{'line'}, @qcode{'circle'},
    ## @qcode{'ellipse'}, @qcode{'bspline'} or @qcode{'other'}, or a cell
    ## array of several.
    ##
    ## @item @qcode{'Direction'}
    ## A nonzero 3-element vector.  A straight edge is chosen when it runs
    ## parallel to it, either way; a circle or an ellipse when its axis does.
    ## Other edges have no direction and are never chosen.
    ##
    ## @item @qcode{'Within'}
    ## A box @code{[@var{xmin}, @var{ymin}, @var{zmin}, @var{xmax},
    ## @var{ymax}, @var{zmax}]}, as @code{solid.Shape.bbox} returns one.  An
    ## edge is chosen when it lies wholly inside, to within 1e-6 millimetres.
    ##
    ## @item @qcode{'Face'}
    ## Face indices, as @code{solid.Shape.faces} returns them.  An edge is
    ## chosen when it bounds any of these faces, so all the edges round a
    ## face can be rounded or chamfered in one step:
    ## @code{fillet (@var{S}, edges (@var{S}, 'Face', @var{F}), @var{R})}.
    ## @end table
    ##
    ## @example
    ## @group
    ## B = solid.box (10, 20, 30);
    ## E = edges (B, 'Direction', [0, 0, 1]);    # the four upright edges
    ## B = fillet (B, E, 2);
    ## @end group
    ## @end example
    ##
    ## The empty shape has no edges.
    ##
    ## @seealso{solid.Shape.faces, solid.Shape.fillet, solid.Shape.chamfer}
    ## @end deftypefn
    function E = edges (this, varargin)

      ## Input validation
      kinds = {'line', 'circle', 'ellipse', 'bspline', 'other'};
      [errmsg, opt] = options (varargin, struct ('Type', [], ...
                                                 'Direction', [], ...
                                                 'Within', [], 'Face', []));
      if (isempty (errmsg))
        [errmsg, opt.Type] = checktype (opt.Type, kinds, 'curve');
      endif
      if (isempty (errmsg) && ! isempty (opt.Direction))
        errmsg = checkvec (opt.Direction, 'Direction', true);
      endif
      if (isempty (errmsg))
        errmsg = checkbox (opt.Within);
      endif
      if (isempty (errmsg) && ! isempty (opt.Face))
        errmsg = checkindex (opt.Face, numfaces (this), 'Face', 'face', false);
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.edges: %s", errmsg);
      endif

      E = zeros (1, 0);
      if (isempty (this.Data))
        return;
      endif
      info = occt ('solid.Shape.edges', 'edges', this.Data);
      [type, dir, box, seam, onfaces] = info{:};
      keep = ! seam;
      if (! isempty (opt.Type))
        keep &= ismember (type, opt.Type);
      endif
      if (! isempty (opt.Direction))
        keep &= parallel (dir, opt.Direction);
      endif
      if (! isempty (opt.Within))
        keep &= inside (box, opt.Within);
      endif
      if (! isempty (opt.Face))
        keep &= cellfun (@(f) any (ismember (f, opt.Face)), onfaces);
      endif
      E = find (keep)';

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{F} =} faces (@var{S})
    ## @deftypefnx {solid.Shape} {@var{F} =} faces (@var{S}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Choose faces of a shape, to open when hollowing it or to inspect.
    ##
    ## @code{@var{F} = faces (@var{S})} returns the indices of the faces of
    ## @var{S} as a row vector, in the order @code{solid.Shape.numfaces}
    ## counts them.  The indices belong to @var{S} alone: every operation that
    ## makes a new shape numbers its faces afresh, so choose faces from the
    ## shape the feature is applied to, immediately before applying it.
    ##
    ## Name/Value pairs narrow the choice, and a face is returned only when it
    ## meets all of them:
    ##
    ## @table @asis
    ## @item @qcode{'Type'}
    ## The kind of surface the face lies on: @qcode{'plane'},
    ## @qcode{'cylinder'}, @qcode{'cone'}, @qcode{'sphere'}, @qcode{'torus'},
    ## @qcode{'revolution'}, @qcode{'extrusion'}, @qcode{'bspline'} or
    ## @qcode{'other'}, or a cell array of several.
    ##
    ## @item @qcode{'Normal'}
    ## A nonzero 3-element vector.  A flat face is chosen when its outward
    ## normal points the same way, so @code{[0, 0, 1]} picks faces looking up
    ## and not those looking down.  Curved faces are never chosen.
    ##
    ## @item @qcode{'Axis'}
    ## A nonzero 3-element vector.  A face on a cylinder, cone, torus or
    ## other surface of revolution is chosen when its axis runs parallel to
    ## it, either way.
    ##
    ## @item @qcode{'Within'}
    ## A box @code{[@var{xmin}, @var{ymin}, @var{zmin}, @var{xmax},
    ## @var{ymax}, @var{zmax}]}, as @code{solid.Shape.bbox} returns one.  A
    ## face is chosen when it lies wholly inside, to within 1e-6 millimetres.
    ## @end table
    ##
    ## The empty shape has no faces.
    ##
    ## @example
    ## @group
    ## ## The bore of a block, its edges chamfered 1 x 45
    ## S = subtract (solid.box (40, 30, 10), ...
    ##               translate (solid.cylinder (5, 10), [20, 15, 0]));
    ## bore = faces (S, 'Type', 'cylinder');
    ## S = chamfer (S, edges (S, 'Face', bore), 1);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.edges, solid.Shape.shell}
    ## @end deftypefn
    function F = faces (this, varargin)

      ## Input validation
      kinds = {'plane', 'cylinder', 'cone', 'sphere', 'torus', ...
               'revolution', 'extrusion', 'bspline', 'other'};
      [errmsg, opt] = options (varargin, struct ('Type', [], 'Normal', [], ...
                                                 'Axis', [], 'Within', []));
      if (isempty (errmsg))
        [errmsg, opt.Type] = checktype (opt.Type, kinds, 'surface');
      endif
      if (isempty (errmsg) && ! isempty (opt.Normal))
        errmsg = checkvec (opt.Normal, 'Normal', true);
      endif
      if (isempty (errmsg) && ! isempty (opt.Axis))
        errmsg = checkvec (opt.Axis, 'Axis', true);
      endif
      if (isempty (errmsg))
        errmsg = checkbox (opt.Within);
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.faces: %s", errmsg);
      endif

      F = zeros (1, 0);
      if (isempty (this.Data))
        return;
      endif
      info = occt ('solid.Shape.faces', 'faces', this.Data);
      [type, normal, axis, box] = info{:};
      keep = true (numel (type), 1);
      if (! isempty (opt.Type))
        keep &= ismember (type, opt.Type);
      endif
      if (! isempty (opt.Normal))
        v = opt.Normal(:)' / norm (opt.Normal);
        keep &= (normal * v' >= 1 - 1e-9);
      endif
      if (! isempty (opt.Axis))
        keep &= parallel (axis, opt.Axis);
      endif
      if (! isempty (opt.Within))
        keep &= inside (box, opt.Within);
      endif
      F = find (keep)';

    endfunction

  endmethods

################################################################################
##                               ** Features **                               ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'fillet'          'facefillet'      'chamfer'         'shell'              ##
## 'hole'            'pocket'          'knurl'                                ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{S} =} fillet (@var{S}, @var{E}, @var{R})
    ##
    ## Round edges of a shape to a radius.
    ##
    ## @code{@var{S} = fillet (@var{S}, @var{E}, @var{R})} rounds the edges
    ## of @var{S} indexed by @var{E}, as @code{solid.Shape.edges} returns
    ## them, to the radius @var{R} millimetres.  An outside edge loses
    ## material and an inside edge gains it, as a fillet on a casting or a
    ## radius left by a cutter does.  Where rounded edges meet at a corner the
    ## corner is blended.
    ##
    ## An edge is rounded together with every edge that runs on from it
    ## smoothly, tangent where they meet, as Open CASCADE rounds a chain.  On
    ## a box whose upright edges are already rounded, choosing one top edge
    ## rounds the whole top rim.
    ##
    ## A radius too large for the faces beside an edge cannot be built and
    ## raises an error, as does an edge that cannot be rounded at all.  Nor
    ## can fillets use up a face: two of radius 10 on the long edges of a face
    ## 20 wide would meet across it and leave none of it, and raise an error.
    ## @code{solid.Shape.facefillet} builds that shape as a full round.
    ##
    ## @example
    ## @group
    ## ## A block with its four upright edges rounded to 5
    ## S = solid.box (40, 30, 10);
    ## S = fillet (S, edges (S, 'Direction', [0, 0, 1]), 5);
    ## numfaces (S)
    ## @result{} 10
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.edges, solid.Shape.facefillet, solid.Shape.chamfer}
    ## @end deftypefn
    function this = fillet (this, E, R)

      ## Input validation
      if (nargin != 3)
        error ("solid.Shape.fillet: invalid number of input arguments.");
      endif
      errmsg = checkindex (E, numedges (this), 'E', 'edge', false);
      if (! isempty (errmsg))
        error ("solid.Shape.fillet: %s", errmsg);
      endif
      if (! (isfloat (R) && isreal (R) && isscalar (R) && isfinite (R) &&
             R > 0))
        error (strcat ("solid.Shape.fillet: R must be a positive", ...
                       " and finite real scalar."));
      endif

      r = occt ('solid.Shape.fillet', 'fillet', this.Data, ...
                unique (double (E)), double (R));
      A = this;
      this.Data = r{1};
      [this.Colour, this.Name] = inherit (r{2}, A);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} facefillet (@var{S}, @var{F})
    ## @deftypefnx {solid.Shape} {@var{S} =} facefillet (@var{S}, @var{F}, @var{R})
    ##
    ## Round a shape between faces chosen by index.
    ##
    ## @code{@var{S} = facefillet (@var{S}, @var{F})} makes a full round on
    ## each row of the @math{N}-by-3 matrix @var{F}, a row of face indices
    ## @code{[@var{A}, @var{M}, @var{B}]} as @code{solid.Shape.faces} returns
    ## them: the middle face @var{M} is replaced by a round tangent to the
    ## sides @var{A} and @var{B} and to the face @var{M} itself, so the end of
    ## a wall becomes a half cylinder.  There is no radius to give: between
    ## parallel sides it is half the distance between them.
    ##
    ## The three faces must be flat, and parallel to the edges @var{M} shares
    ## with @var{A} and @var{B}, so that the round is part of a cylinder;
    ## sides need not be parallel to each other.  Every other face @var{M}
    ## borders must be flat and square to those edges, as the front and back
    ## of a wall are to its end.  Parallel and square are judged across each
    ## face: a face may stray from them by 1e-7 millimetres, the precision of
    ## Open CASCADE@.  @var{M} must meet each side at an outside corner, and
    ## the round must touch each face within it.  Rows may share sides, but
    ## the middle face of a row cannot appear in another row.
    ## @code{model.Viewer.pick} returns faces in the order they are clicked,
    ## so a row can be picked side, middle, side.
    ##
    ## @code{@var{S} = facefillet (@var{S}, @var{F}, @var{R})} rounds, on each
    ## row of the @math{N}-by-2 matrix @var{F}, the edges the two faces of
    ## the row share, to the radius @var{R} millimetres, as
    ## @code{solid.Shape.fillet} rounds them.  The two faces must share at
    ## least one edge.
    ##
    ## @code{solid.Shape.fillet} cannot use up a face: two fillets that would
    ## meet across it, such as two of radius 10 on the ends of a face 20
    ## wide, raise an error.  A full round builds that shape.
    ##
    ## @example
    ## @group
    ## ## A wall 50 long, 5 thick and 20 high with rounded ends
    ## W = solid.box (50, 5, 20);
    ## top = faces (W, 'Normal', [0, 0, 1]);
    ## bottom = faces (W, 'Normal', [0, 0, -1]);
    ## left = faces (W, 'Normal', [-1, 0, 0]);
    ## right = faces (W, 'Normal', [1, 0, 0]);
    ## W = facefillet (W, [top, left, bottom; top, right, bottom]);
    ## numfaces (W)
    ## @result{} 6
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.faces, solid.Shape.fillet}
    ## @end deftypefn
    function this = facefillet (this, F, R)

      ## Input validation
      if (nargin < 2 || nargin > 3)
        error ("solid.Shape.facefillet: invalid number of input arguments.");
      endif
      full = nargin == 2;
      if (! isnumeric (F) || ! isreal (F) || ndims (F) != 2 || isempty (F)
          || columns (F) != 3 - ! full || any (F(:) != fix (F(:)))
          || any (F(:) < 1) || any (F(:) > numfaces (this)))
        if (full)
          error (strcat ("solid.Shape.facefillet: F must be an N-by-3", ...
                         " matrix of face indices of S."));
        else
          error (strcat ("solid.Shape.facefillet: with a radius R, F must", ...
                         " be an N-by-2 matrix of face indices of S."));
        endif
      endif
      if (! full)
        if (! (isfloat (R) && isreal (R) && isscalar (R) && isfinite (R) &&
               R > 0))
          error (strcat ("solid.Shape.facefillet: R must be a positive", ...
                         " and finite real scalar."));
        endif
      endif
      F = double (F);
      [errmsg, E] = checkrounds (this, F);
      if (! isempty (errmsg))
        error ("solid.Shape.facefillet: %s", errmsg);
      endif

      if (full)
        r = occt ('solid.Shape.facefillet', 'fullround', this.Data, F);
      else
        r = occt ('solid.Shape.facefillet', 'fillet', this.Data, E, ...
                  double (R));
      endif
      A = this;
      this.Data = r{1};
      [this.Colour, this.Name] = inherit (r{2}, A);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} chamfer (@var{S}, @var{E}, @var{D})
    ## @deftypefnx {solid.Shape} {@var{S} =} chamfer (@var{S}, @var{E}, [@var{D1}, @var{D2}], @var{F})
    ## @deftypefnx {solid.Shape} {@var{S} =} chamfer (@var{S}, @var{E}, @var{D}, @var{F}, @qcode{'Angle'}, @var{A})
    ##
    ## Bevel edges of a shape.
    ##
    ## @code{@var{S} = chamfer (@var{S}, @var{E}, @var{D})} cuts the edges of
    ## @var{S} indexed by @var{E}, as @code{solid.Shape.edges} returns them,
    ## back by @var{D} millimetres on both faces, so a chamfer on a square
    ## corner is the 45 degree bevel a drawing calls @code{@var{D} x 45}.
    ## An edge is bevelled together with every edge that runs on from it
    ## smoothly, tangent where they meet, as Open CASCADE bevels a chain.  On
    ## a box whose upright edges are already rounded, choosing one top edge
    ## bevels the whole top rim.
    ##
    ## @code{@var{S} = chamfer (@var{S}, @var{E}, [@var{D1}, @var{D2}],
    ## @var{F})} cuts each edge back by @var{D1} along the face @var{F}, a face
    ## index as @code{solid.Shape.faces} returns one, and by @var{D2} along the
    ## other face of the edge.  Every edge must bound @var{F}, as the edges
    ## round a face do: @code{edges (@var{S}, 'Face', @var{F})}.
    ##
    ## @code{@var{S} = chamfer (@var{S}, @var{E}, @var{D}, @var{F},
    ## @qcode{'Angle'}, @var{A})} cuts each edge back by @var{D} along the face
    ## @var{F}, with the chamfer face meeting @var{F} at @var{A} degrees, in
    ## the range @math{(0, 90)}: the chamfer a drawing calls @code{@var{D} x
    ## @var{A}}.  Along the other face it reaches @code{@var{D} * tand
    ## (@var{A})}, so 45 degrees is the equal chamfer.
    ##
    ## A chamfer too large for the faces beside an edge cannot be built and
    ## raises an error, as does an edge that cannot be chamfered at all.
    ##
    ## @example
    ## @group
    ## ## The top rim of a plate bevelled 1 x 45, and 2 x 30
    ## S = solid.box (40, 30, 10);
    ## F = faces (S, 'Normal', [0, 0, 1]);
    ## A = chamfer (S, edges (S, 'Face', F), 1);
    ## B = chamfer (S, edges (S, 'Face', F), 2, F, 'Angle', 30);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.edges, solid.Shape.fillet}
    ## @end deftypefn
    function this = chamfer (this, E, D, varargin)

      ## Input validation
      if (nargin < 3)
        error ("solid.Shape.chamfer: invalid number of input arguments.");
      endif
      ## The face, if any, then Name/Value pairs
      F = [];
      hasF = mod (numel (varargin), 2) == 1;
      if (hasF)
        F = varargin{1};
        varargin(1) = [];
      endif
      [errmsg, opt] = options (varargin, struct ('Angle', []));
      if (! isempty (errmsg))
        error ("solid.Shape.chamfer: %s", errmsg);
      endif
      A = opt.Angle;
      if (! isempty (A) && (! isfloat (A) || ! isreal (A)
                            || ! isscalar (A) || ! (A > 0) || ! (A < 90)))
        error (strcat ("solid.Shape.chamfer: Angle must be in the range", ...
                       " (0, 90) degrees."));
      endif
      if (! isfloat (D) || ! isreal (D) || ! isvector (D)
          || numel (D) > 2 || ! all (isfinite (D)) || ! all (D > 0))
        error (strcat ("solid.Shape.chamfer: D must be one positive finite", ...
                       " distance, or two with a face F."));
      endif
      if (! isempty (A) && numel (D) != 1)
        error ("solid.Shape.chamfer: an angle goes with one distance D.");
      endif
      if (! isempty (A) && ! hasF)
        error ("solid.Shape.chamfer: an angle needs the face F of D.");
      endif
      if (numel (D) == 2 && ! hasF)
        error ("solid.Shape.chamfer: two distances need the face F of D1.");
      endif
      if (numel (D) == 1 && isempty (A) && hasF)
        error (strcat ("solid.Shape.chamfer: a face F goes with two", ...
                       " distances, or with an angle."));
      endif
      if (hasF && ! isscalar (F))
        error ("solid.Shape.chamfer: F must be a single face index of S.");
      endif
      errmsg = checkindex (E, numedges (this), 'E', 'edge', false);
      if (! isempty (errmsg))
        error ("solid.Shape.chamfer: %s", errmsg);
      endif
      F0 = 0;
      if (hasF)
        errmsg = checkindex (F, numfaces (this), 'F', 'face', false);
        if (! isempty (errmsg))
          error ("solid.Shape.chamfer: %s", errmsg);
        endif
        on = edges (this, 'Face', F);
        if (! all (ismember (E, on)))
          error ("solid.Shape.chamfer: every edge in E must bound the face F.");
        endif
        F0 = double (F);
      endif

      if (isempty (A))
        A = 0;
      endif
      r = occt ('solid.Shape.chamfer', 'chamfer', this.Data, ...
                unique (double (E)), double (D), F0, double (A));
      A = this;
      this.Data = r{1};
      [this.Colour, this.Name] = inherit (r{2}, A);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} shell (@var{S}, @var{F}, @var{T})
    ## @deftypefnx {solid.Shape} {@var{S} =} shell (@dots{}, @qcode{'Outward'}, @var{TF})
    ## @deftypefnx {solid.Shape} {@var{S} =} shell (@dots{}, @qcode{'Thickness'}, @{@var{FACES}, @var{T2}, @dots{}@})
    ##
    ## Hollow a shape to a uniform wall thickness.
    ##
    ## @code{@var{S} = shell (@var{S}, @var{F}, @var{T})} removes the faces of
    ## @var{S} indexed by @var{F}, as @code{solid.Shape.faces} returns them,
    ## and hollows what is left to walls @var{T} millimetres thick, as a box,
    ## a cup or an enclosure is made.  The walls grow inwards, so the outside
    ## of the part keeps its size and the inner corners stay sharp.  With
    ## @var{F} empty no face is removed and the result is a closed shell
    ## around a sealed cavity.
    ##
    ## @code{@var{S} = shell (@dots{}, @qcode{'Outward'}, true)} grows the
    ## walls outwards instead, so the inside keeps the size and shape of
    ## @var{S} and the outside grows by @var{T}: the way to make a box that a
    ## part of the shape of @var{S} fits into.  It is @code{false} by default.
    ##
    ## @code{@var{S} = shell (@dots{}, @qcode{'Thickness'}, @{@var{FACES},
    ## @var{T2}, @dots{}@})} gives the faces indexed by @var{FACES} walls
    ## @var{T2} thick instead of @var{T}, and so on for every pair in the cell
    ## array: a thicker floor, a thinner lid.  The faces come from
    ## @code{solid.Shape.faces}, none may be opened, and none may be given two
    ## thicknesses:
    ##
    ## @example
    ## @group
    ## ## A box of 2 walls with a floor 4 thick, open at the top
    ## B = solid.box (60, 40, 30);
    ## B = shell (B, faces (B, 'Normal', [0, 0, 1]), 2, ...
    ##            'Thickness', @{faces(B, 'Normal', [0, 0, -1]), 4@});
    ## @end group
    ## @end example
    ##
    ## Walls too thick for the shape, which would meet in the middle, cannot
    ## be built and raise an error.
    ##
    ## @example
    ## @group
    ## ## An open box of 1 mm walls
    ## B = solid.box (10, 20, 30);
    ## B = shell (B, faces (B, 'Normal', [0, 0, 1]), 1);
    ## volume (B)
    ## @result{} 1824.0
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.faces}
    ## @end deftypefn
    function this = shell (this, F, T, varargin)

      ## Input validation
      if (nargin < 3)
        error ("solid.Shape.shell: invalid number of input arguments.");
      endif
      [errmsg, opt] = options (varargin, struct ('Outward', false, ...
                                                 'Thickness', {{}}));
      if (isempty (errmsg) && (! islogical (opt.Outward)
                               || ! isscalar (opt.Outward)))
        errmsg = "Outward must be true or false.";
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.shell: %s", errmsg);
      endif
      ## The faces with walls of their own, and their thicknesses
      C = opt.Thickness;
      if (! iscell (C) || mod (numel (C), 2) != 0)
        error (strcat ("solid.Shape.shell: Thickness must be a cell array", ...
                       " of faces and thicknesses, in pairs."));
      endif
      TF = zeros (1, 0);
      TT = zeros (1, 0);
      for k = 1:2:numel (C)
        if (! isnumeric (C{k}) || ! isreal (C{k}) || isempty (C{k})
            || ! isvector (C{k}) || any (C{k} != fix (C{k})))
          error (strcat ("solid.Shape.shell: Thickness must give each set", ...
                         " of faces as a vector of face indices."));
        endif
        if (! (isfloat (C{k+1}) && isreal (C{k+1}) && isscalar (C{k+1}) &&
               isfinite (C{k+1}) && C{k+1} > 0))
          error (strcat ("solid.Shape.shell: Thickness must give each", ...
                         " thickness as a positive and finite real scalar."));
        endif
        TF = [TF, double(C{k}(:)')];
        TT = [TT, repmat(double (C{k+1}), 1, numel (C{k}))];
      endfor
      if (numel (unique (TF)) != numel (TF))
        error ("solid.Shape.shell: Thickness gives a face two thicknesses.");
      endif
      if (isnumeric (F) && any (ismember (TF, F)))
        error (strcat ("solid.Shape.shell: a face cannot be both opened", ...
                       " and given a thickness."));
      endif
      errmsg = checkindex (F, numfaces (this), 'F', 'face', true);
      if (! isempty (errmsg))
        error ("solid.Shape.shell: %s", errmsg);
      endif
      if (! (isfloat (T) && isreal (T) && isscalar (T) && isfinite (T) &&
             T > 0))
        error (strcat ("solid.Shape.shell: T must be a positive", ...
                       " and finite real scalar."));
      endif
      if (! isempty (TF))
        errmsg = checkindex (TF, numfaces (this), 'Thickness', 'face', false);
      endif
      if (isempty (errmsg) && isempty (this.Data))
        errmsg = "S is empty, so there is nothing to hollow.";
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.shell: %s", errmsg);
      endif

      r = occt ('solid.Shape.shell', 'shell', this.Data, ...
                unique (double (F)), double (T), logical (opt.Outward), TF, TT);
      A = this;
      this.Data = r{1};
      [this.Colour, this.Name] = inherit (r{2}, A);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} hole (@var{S}, @var{P}, @var{D}, @var{DEPTH})
    ## @deftypefnx {solid.Shape} {@var{S} =} hole (@dots{}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Drill holes into a shape.
    ##
    ## @code{@var{S} = hole (@var{S}, @var{P}, @var{D}, @var{DEPTH})} drills a
    ## hole of diameter @var{D} millimetres at every row of the
    ## @math{M}-by-3 matrix @var{P}, each starting at its point and running
    ## down the @math{z} axis, @var{DEPTH} millimetres deep.  An
    ## @code{Inf} @var{DEPTH} drills right through, however thick the part.
    ## The point is where the hole's axis meets the surface of the part, and
    ## @var{DEPTH} is measured from it, as a drawing dimensions a hole.  The
    ## drill comes from outside: everything on the axis before the point is
    ## cleared too, at the widest diameter of the hole, so a hole entering a
    ## sloping or curved face is clean all round.  A hole started under
    ## material that its axis passes through first cuts that material as
    ## well.  All the holes are cut in one operation.  A hole that would
    ## remove nothing, its axis missing the part or its point too far from
    ## it for @var{DEPTH} to reach, is an error naming the point, as a thread
    ## whose axis meets no bore or cylinder is for @code{solid.Shape.thread}.
    ##
    ## @var{P} may instead be a @code{geom.UCS}, such as @code{geom.UCS
    ## (@var{V})} picks off a face in the viewer: the hole starts at its origin
    ## and runs against its normal, which points out of the part, so its
    ## normal sets the direction.  With @qcode{'At'}, a hole is drilled at
    ## every point given in the plane of the UCS instead, which places a bolt
    ## circle or a row of holes on a face in one call.
    ##
    ## @subheading Tapping holes
    ##
    ## @var{D} may instead name an ISO metric thread from M1 to M64 with a
    ## diameter and pitch of ISO 261: a coarse thread by its diameter, as
    ## @qcode{'M6'}, a fine one with its pitch, as @qcode{'M10x1.25'}.  The
    ## hole is then drilled for tapping that thread by hand, and the thread
    ## itself is cut by @code{solid.Shape.thread}.  The drill is the one ISO
    ## 2306:1972 lists for the thread in its tables 1 and 2, so @qcode{'M6'}
    ## drills 5 millimetres and @qcode{'M8'} 6.8; for a thread it does not
    ## list, M60 and M64 among them, it is the rule ISO 2306 states, the
    ## nominal diameter less the pitch.
    ##
    ## With @qcode{'Custom'}, @var{D} may name a thread of any diameter and
    ## pitch, as @qcode{'M16x0.8'}, or @qcode{'M6.35x1.27'} for the 1/4-20
    ## UNC of an imperial screw, whose basic profile is the same.  Its drill
    ## is the nominal diameter less the pitch rounded to a step of 0.05
    ## millimetres, the step nearest that inside the band below.
    ##
    ## Every drill lies in the 6H tolerance band of the thread's minor
    ## diameter, from @math{D_1}, the nominal diameter less @math{1.0825 P},
    ## up by the tolerance of ISO 965-1:1998, 13.3.2, table 3, so a drawing
    ## that states 6H is met.  At a pitch of 0.25 and 0.2, where ISO 965-1
    ## has no grade 6, the band is the coarsest grade it has, 5 and 4.  Tough
    ## materials take a larger drill than soft ones, and @qcode{'Material'}
    ## and @qcode{'Engagement'} choose another drill inside the band.  For a
    ## custom thread the drills are the steps of 0.05 millimetres, and a band
    ## too narrow to hold one, at the finest pitches, is an error naming the
    ## thread.  A drill chosen otherwise is the ISO 2306 drill or one of the
    ## sizes of the twist drills in RUKO's catalogue, chapter 1.01
    ## @cite{Twist drills} (2014): DIN 338 type N, HSS ground, article 214,
    ## 0.3 to 20 millimetres, pages 54 to 56; DIN 345 type N, HSS, article
    ## 204, 10 to 60 millimetres, pages 78 and 79.
    ##
    ## A tapping hole is countersunk at its entry, as IS 1369 (Part 3):1995,
    ## prepared from DIN 76-1:1983, draws the entry of an internal thread:
    ## 120 degrees, and 1.05 times the nominal diameter across at the
    ## surface, the largest its band from the nominal diameter allows, 6.3
    ## for M6, so that the tap starts square and the thread starts clean.  A
    ## hole drilled through, with an @code{Inf} @var{DEPTH} or one that
    ## reaches past the part, is countersunk alike where its axis last leaves
    ## the part.  @qcode{'Countersink'} false leaves both out, and numbers
    ## size both.  A tapping hole takes no counterbore.
    ##
    ## A tapping hole is expected to be drilled, not milled, so a blind one
    ## ends in the cone the point of a 118 degree twist drill leaves, beyond
    ## @var{DEPTH}, as the drawing of a blind tapped hole in IS 1369 (Part 3)
    ## shows it.  @qcode{'Tip'} gives another angle, and false a flat bottom.
    ##
    ## Name/Value pairs shape the hole:
    ##
    ## @table @asis
    ## @item @qcode{'Direction'}
    ## The nonzero 3-element direction the holes run in from their points,
    ## @code{[0, 0, -1]} by default.  It cannot be given when @var{P} is a
    ## @code{geom.UCS}.
    ##
    ## @item @qcode{'At'}
    ## An @math{N}-by-2 matrix of points in the plane of the @code{geom.UCS}
    ## @var{P}, one hole at each, all against its normal; the UCS origin alone
    ## by default.  It applies only when @var{P} is a @code{geom.UCS}.
    ##
    ## @item @qcode{'Material'}
    ## The material tapped, for a named thread.  A tough one,
    ## @qcode{'stainless'} or @qcode{'nickel'}, takes the largest drill inside
    ## the band, and @qcode{'steel'}, @qcode{'aluminium'}, @qcode{'brass'},
    ## @qcode{'castiron'} and @qcode{'plastic'} keep the ISO 2306 drill.  The
    ## tough ones are those OSG's chart @cite{Tap Drill Size and Pitch
    ## Diameter Limit}, volume 3 (2024), names hard or tough: stainless
    ## steel, nickel steel, Monel, cast steel and drop forgings.
    ##
    ## @item @qcode{'Engagement'}
    ## The thread engagement for a named thread, as a percentage of the full
    ## thread in ISO's terms, 100 drilling at @math{D_1}: the diameter asked
    ## is the nominal diameter less @math{1.0825 P} times the percentage over
    ## 100, and the drill is the one nearest it inside the band.  A
    ## percentage that falls outside the band is an error naming the thread
    ## and the band, from 78.2 to 100 for M6.  It cannot be given with
    ## @qcode{'Material'}.
    ##
    ## @item @qcode{'Custom'}
    ## True to take a named thread of any diameter and pitch, false by
    ## default, so that a name outside ISO 261, as a mistyped pitch, is an
    ## error.  A thread of ISO 261 is drilled as without it.
    ##
    ## @item @qcode{'Clearance'}
    ## For a named thread, @qcode{'fine'}, @qcode{'medium'} or
    ## @qcode{'coarse'}: the hole is the clearance hole of ISO 273 in that
    ## series for a screw of the thread, not a hole for tapping it, 6.6 for
    ## M6 in the medium series.
    ##
    ## @item @qcode{'Counterbore'}
    ## @code{[@var{CD}, @var{CDEPTH}]}: a flat-bottomed bore of diameter
    ## @var{CD}, wider than the hole, @var{CDEPTH} deep, shallower than the
    ## hole, for the head of a cap screw.  With a named thread and
    ## @qcode{'Clearance'}, true takes the counterbore of IS 3406 (Part 2)
    ## for a socket head cap screw of ISO 4762, and @qcode{'washer'} the one
    ## for the same screw on a plain washer.  A tapping hole takes none.
    ##
    ## @item @qcode{'Countersink'}
    ## @var{CD}, @code{[@var{CD}, @var{ANGLE}]} or @code{[@var{CD},
    ## @var{ANGLE}, @var{CDEPTH}]}: a conical seat of diameter @var{CD} at the
    ## surface, wider than the hole, with an included angle of @var{ANGLE}
    ## degrees, 90 by default as for ISO countersunk screws, below a cylinder
    ## of the same diameter @var{CDEPTH} deep, none by default.  It must be
    ## shallower than the hole.  With a named thread and @qcode{'Clearance'},
    ## true takes the countersink of IS 3406 (Part 1) for the countersunk
    ## heads of ISO 7721, and @qcode{'socket'} the one for a hexagon socket
    ## countersunk screw of ISO 10642.  A tapping hole takes the countersink
    ## of an internal thread by default, as the tapping holes above describe;
    ## false leaves it out, and numbers replace it.
    ##
    ## @item @qcode{'Tip'}
    ## The included angle in degrees of the cone a twist drill leaves at the
    ## bottom of a blind hole, 118 for a standard drill, or false for none.
    ## It is beyond @var{DEPTH}, which is measured to the full diameter as a
    ## drawing dimensions it.  A blind tapping hole is drilled, so it takes
    ## the point of a 118 degree drill by default; false leaves it
    ## flat-bottomed, as an end mill or a flat-bottom drill leaves it.  Every
    ## other blind hole is flat-bottomed by default, as an end mill leaves it.
    ## @end table
    ##
    ## A counterbore and a countersink cannot both be given, and a tip applies
    ## only to a blind hole.  The standard ones need a named thread, and
    ## those for a screw head @qcode{'Clearance'}, fine or medium;
    ## @code{solid.holespec} gives their sizes, and the sizes of every hole
    ## for a named thread, before it is drilled.  A hole may break into
    ## another, but holes that would cut a solid of @var{S} into pieces are an
    ## error, as a bore reaching the roots of a knurl, which leaves its teeth
    ## loose.  Drilling the empty shape leaves it empty.
    ##
    ## @example
    ## @group
    ## ## A plate with four counterbored holes for M6 cap screws
    ## S = solid.box (80, 40, 12);
    ## P = [10, 10, 12; 70, 10, 12; 10, 30, 12; 70, 30, 12];
    ## S = hole (S, P, 6.6, Inf, 'Counterbore', [11, 6.5]);
    ## @end group
    ## @end example
    ##
    ## @example
    ## @group
    ## ## Four holes tapped M5 in stainless steel on a bolt circle of 30
    ## S = solid.cylinder (25, 10);
    ## U = geom.UCS ([0, 0, 1], [0, 0, 10]);
    ## XY = 15 * [1, 0; 0, 1; -1, 0; 0, -1];
    ## S = hole (S, U, 'M5', 8, 'At', XY, 'Material', 'stainless');
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.thread, solid.holespec, solid.threadspec,
    ## solid.Shape.subtract, solid.cylinder}
    ## @end deftypefn
    function this = hole (this, P, D, DEPTH, varargin)

      ## Input validation
      if (nargin < 4)
        error ("solid.Shape.hole: invalid number of input arguments.");
      endif
      [errmsg, opt] = options (varargin, struct ('Direction', [], ...
                                                 'At', [], ...
                                                 'Clearance', [], ...
                                                 'Counterbore', [], ...
                                                 'Countersink', [], ...
                                                 'Tip', [], ...
                                                 'Material', [], ...
                                                 'Engagement', [], ...
                                                 'Custom', []));
      if (isempty (errmsg))
        [errmsg, P, opt.Direction] = placement (P, opt.Direction, opt.At);
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.hole: %s", errmsg);
      endif
      cb = opt.Counterbore;
      cs = opt.Countersink;
      tapped = ischar (D) && isempty (opt.Clearance);
      if (ischar (D))
        ## The hole for the thread, with the options that size it
        names = {'Clearance', 'Counterbore', 'Countersink', 'Material', ...
                 'Engagement', 'Custom'};
        args = {};
        for k = 1:numel (names)
          if (! isempty (opt.(names{k})))
            args(end+1:end+2) = {names{k}, opt.(names{k})};
          endif
        endfor
        H = solid.holespec (D, args{:});
        D = H.drill;
        cb = H.counterbore;
        cs = H.countersink;
      elseif (! isempty (opt.Material) || ! isempty (opt.Engagement))
        error (strcat ("solid.Shape.hole: Material and Engagement apply", ...
                       " only to a named thread."));
      elseif (! isempty (opt.Custom))
        error ("solid.Shape.hole: Custom applies only to a named thread.");
      elseif (! isempty (opt.Clearance))
        error ("solid.Shape.hole: Clearance applies only to a named thread.");
      elseif (ischar (cb) || ischar (cs) || (islogical (cb) && any (cb))
              || (islogical (cs) && any (cs)))
        error (strcat ("solid.Shape.hole: a standard Counterbore or", ...
                       " Countersink needs a named thread."));
      endif
      if (islogical (cb) && isscalar (cb) && ! cb)
        cb = [];
      endif
      if (islogical (cs) && isscalar (cs) && ! cs)
        cs = [];
      endif
      if (! (isfloat (D) && isreal (D) && isscalar (D) && isfinite (D) &&
             D > 0))
        error (strcat ("solid.Shape.hole: D must be a positive and finite", ...
                       " real scalar or the name of an ISO metric thread", ...
                       " such as 'M6' or 'M10x1.25'."));
      endif
      if (! isfloat (DEPTH) || ! isreal (DEPTH) || ! isscalar (DEPTH)
          || ! (DEPTH > 0))
        error (strcat ("solid.Shape.hole: DEPTH must be positive, or Inf", ...
                       " for a through hole."));
      endif
      if (! isempty (cb) && (! isfloat (cb) || ! isreal (cb)
                             || numel (cb) != 2 || ! all (isfinite (cb))
                             || ! (cb(1) > D) || ! (cb(2) > 0)
                             || ! (cb(2) < DEPTH)))
        error (strcat ("solid.Shape.hole: Counterbore must be", ...
                       " [CD, CDEPTH],", ...
                       " wider than D and shallower than DEPTH."));
      endif
      if (! isempty (cs))
        if (isnumeric (cs) && isscalar (cs))
          cs(2) = 90;
        endif
        if (isnumeric (cs) && numel (cs) == 2)
          cs(3) = 0;
        endif
        if (! isfloat (cs) || ! isreal (cs) || numel (cs) != 3
            || ! all (isfinite (cs)) || ! (cs(1) > D) || ! (cs(2) > 0)
            || ! (cs(2) < 180) || ! (cs(3) >= 0)
            || ! (cs(3) + (cs(1) - D) / 2 / tand (cs(2) / 2) < DEPTH))
          error (strcat ("solid.Shape.hole: Countersink must be CD,", ...
                         " [CD, ANGLE] or [CD, ANGLE, CDEPTH], wider than", ...
                         " D, with ANGLE in the range (0, 180), and", ...
                         " shallower than DEPTH."));
        endif
      endif
      if (! isempty (cb) && ! isempty (cs))
        error (strcat ("solid.Shape.hole: Counterbore and Countersink", ...
                       " cannot both be given."));
      endif
      ## A blind tapping hole is drilled, so it ends in the point of a twist
      ## drill unless a tip is given or refused
      tip = opt.Tip;
      point = tapped && isempty (tip) && ! isinf (DEPTH);
      if (islogical (tip) && isscalar (tip) && ! tip)
        tip = [];
      elseif (! isempty (tip))
        if (! isfloat (tip) || ! isreal (tip) || ! isscalar (tip)
            || ! (tip > 0) || ! (tip < 180))
          error (strcat ("solid.Shape.hole: Tip must be false or an angle", ...
                         " in the range (0, 180)."));
        endif
        if (isinf (DEPTH))
          error ("solid.Shape.hole: Tip applies to blind holes only.");
        endif
      endif

      if (isempty (this.Data))
        return;
      endif

      ## How far the part reaches from any of the points, which is how far
      ## a through hole runs and how far back the drill clears
      B = bbox (this);
      [X, Y, Z] = ndgrid (B([1, 4]), B([2, 5]), B([3, 6]));
      C = [X(:), Y(:), Z(:)];
      reach = 0;
      for i = 1:rows (P)
        reach = max (reach, max (sqrt (sum ((C - P(i,:)) .^ 2, 2))));
      endfor
      reach += 1;
      if (isinf (DEPTH))
        DEPTH = reach;
      endif

      ## The cutters of one hole, running up the z axis from the origin.  The
      ## drill comes from outside, so each also clears the axis back to beyond
      ## the part, which leaves a hole entering a sloping face clean all round.
      T = {translate(solid.cylinder (D / 2, reach + DEPTH), [0, 0, -reach])};
      if (! isempty (cb))
        T{end+1} = translate (solid.cylinder (cb(1) / 2, reach + cb(2)), ...
                              [0, 0, -reach]);
      endif
      if (! isempty (cs))
        h = (cs(1) - D) / 2 / tand (cs(2) / 2);
        T{end+1} = translate (solid.cone (cs(1) / 2, D / 2, h), [0, 0, cs(3)]);
        T{end+1} = translate (solid.cylinder (cs(1) / 2, reach + cs(3)), ...
                              [0, 0, -reach]);
      endif
      if (! isempty (tip))
        T{end+1} = translate (solid.cone (D / 2, 0, D / 2 / tand (tip / 2)), ...
                              [0, 0, DEPTH]);
      endif

      ## Turned onto the direction and placed at every point
      T = aim (T, opt.Direction);
      tools = cell (1, rows (P) * numel (T));
      for i = 1:rows (P)
        for j = 1:numel (T)
          tools{(i - 1) * numel (T) + j} = translate (T{j}, P(i,:));
        endfor
      endfor
      owner = repelem (1:rows (P), numel (T));

      ## A hole that would remove nothing misses the part
      for i = 1:rows (P)
        k = (i - 1) * numel (T);
        j = 1;
        while (j <= numel (T) && isempty (intersect (this, tools{k + j})))
          j++;
        endwhile
        if (j > numel (T))
          error ("solid.Shape.hole: the hole at (%s) misses the part.", ...
                 pointstr (P(i,:)));
        endif
      endfor

      ## A tapped hole drilled through is countersunk alike where its axis
      ## last leaves the part, the cone widening outwards and its cylinder
      ## clearing the axis on beyond the part; one that stops in the part
      ## ends in the point of a 118 degree drill
      if (tapped && (! isempty (cs) || point))
        for i = 1:rows (P)
          z = leaves (this, P(i,:), opt.Direction, reach);
          if (z <= DEPTH + 1e-9 && ! isempty (cs))
            E = {translate(solid.cone (D / 2, cs(1) / 2, h), ...
                           [0, 0, z - cs(3) - h]), ...
                 translate(solid.cylinder (cs(1) / 2, reach + cs(3)), ...
                           [0, 0, z - cs(3)])};
          elseif (z > DEPTH + 1e-9 && point)
            E = {translate(solid.cone (D / 2, 0, D / 2 / tand (59)), ...
                           [0, 0, DEPTH])};
          else
            continue;
          endif
          E = aim (E, opt.Direction);
          for j = 1:numel (E)
            tools{end+1} = translate (E{j}, P(i,:));
            owner(end+1) = i;
          endfor
        endfor
      endif

      ## A hole may break into another, never cut a solid into pieces, as
      ## one drilled through the roots of a knurl leaves its teeth loose
      N = numsolids (this);
      C = subtract (this, tools{:});
      if (numsolids (C) > N)
        for i = 1:rows (P)
          if (numsolids (subtract (this, tools{owner == i})) > N)
            error (strcat ("solid.Shape.hole: the hole at (%s) would cut S", ...
                           " into pieces."), pointstr (P(i,:)));
          endif
        endfor
        error ("solid.Shape.hole: the holes would cut S into pieces.");
      endif
      this = C;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} thread (@var{S}, @var{P}, @var{NAME}, @var{DEPTH})
    ## @deftypefnx {solid.Shape} {@var{S} =} thread (@dots{}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Cut screw threads into a shape.
    ##
    ## @code{@var{S} = thread (@var{S}, @var{P}, @var{NAME}, @var{DEPTH})} cuts
    ## the ISO metric thread @var{NAME} at every row of the @math{M}-by-3
    ## matrix @var{P}, each along an axis starting at its point and running
    ## down the @math{z} axis, @var{DEPTH} millimetres deep.  @var{NAME} is
    ## named as for @code{solid.Shape.hole}: a coarse thread by its diameter,
    ## as @qcode{'M6'}, a fine one with its pitch, as @qcode{'M10x1.25'}, from
    ## M1 to M64 with a diameter and pitch of ISO 261, or any diameter and
    ## pitch with @qcode{'Custom'}, cut by the same profile and turned to the
    ## same class 6g as an ISO thread.  @var{P} and
    ## @var{DEPTH} are those of @code{solid.Shape.hole}, so a thread is placed
    ## as its tapping hole is: @var{DEPTH} is the usable length of thread,
    ## the full profile reaching it, and a blind tapped hole is drilled deeper
    ## than it is threaded.  An @code{Inf} @var{DEPTH} threads right through,
    ## and no thread runs more than a pitch past the far side of the part.
    ##
    ## What the axis meets decides the thread.  Where it runs through a bore
    ## between the thread's minor diameter @math{D_1 = D - 1.0825 P} and its
    ## nominal diameter, the thread is internal and is cut from the bore as
    ## drilled, so its crest stands where the drill left it: a hole drilled
    ## with @code{solid.Shape.hole} for steel or for stainless steel models
    ## the engagement each gives.  Where it runs into a solid cylinder from
    ## halfway between the pitch diameter @math{d - 0.6495 P} and the nominal
    ## diameter up to the nominal diameter, 5.675 to 6 for M6, the thread is
    ## external and is cut from the cylinder as turned.  A cylinder at the
    ## nominal diameter, which is how a rod is designed, is first turned down
    ## over the threaded length to the largest major diameter of tolerance
    ## class 6g, as a machinist turns a blank before threading it: the
    ## nominal diameter plus the fundamental deviation of position g,
    ## @math{-(15 + 11 P)} micrometres, of ISO 965-1:1998, 13.1, rounded as
    ## its table 1 is, to the R 40 series of ISO 3 and then to a whole
    ## number.  M6 is turned to 5.974.  A blank of another diameter is turned
    ## in the design.  An axis that meets neither is an error naming the
    ## thread and the point, and so is a thread that would cut beyond its
    ## bore or cylinder: the bore must run on 0.03 pitches past the thread,
    ## and a cylinder must reach as far before any shoulder.
    ##
    ## A tube is threaded inside or outside, by whichever of its bore and its
    ## cylinder fits: a tube of 6 with a bore of 2 takes an external M6.  A
    ## wall whose bore and cylinder both fit is thinner than either thread is
    ## deep, and is an error, as is an internal thread that would cut through
    ## the wall round its bore: a cylinder, or any other outline, as the flats
    ## of a hexagon or the teeth of a knurl.
    ##
    ## The profile is the basic profile of ISO 68-1, its 60 degree flanks
    ## swept round the axis by @code{solid.helix}: an internal thread's root
    ## is flat at the nominal diameter, an external thread's flat at
    ## @math{D_1}.  The thread is right-handed, and starts a pitch before the
    ## point so that it runs out of the surface clean.
    ##
    ## Open CASCADE fails to cut some threads, at depths no rule predicts.
    ## Such a thread is cut again by a tool built another way, and kept only
    ## when it removes the volume its groove holds inside the part; otherwise
    ## it is an error naming the thread and the point.
    ##
    ## Name/Value pairs place the threads as for @code{solid.Shape.hole}:
    ##
    ## @table @asis
    ## @item @qcode{'Direction'}
    ## The nonzero 3-element direction the axes run in from their points,
    ## @code{[0, 0, -1]} by default.  It cannot be given when @var{P} is a
    ## @code{geom.UCS}.
    ##
    ## @item @qcode{'At'}
    ## An @math{N}-by-2 matrix of points in the plane of the @code{geom.UCS}
    ## @var{P}, one thread at each, all against its normal; the UCS origin
    ## alone by default.  It applies only when @var{P} is a @code{geom.UCS}.
    ##
    ## @item @qcode{'Custom'}
    ## True to take a thread of any diameter and pitch, as for
    ## @code{solid.Shape.hole}, false by default.
    ## @end table
    ##
    ## Threading the empty shape leaves it empty.
    ##
    ## @example
    ## @group
    ## ## A block tapped M6 12 deep, its hole drilled 15 deep
    ## S = solid.box (20, 20, 20);
    ## S = hole (S, [10, 10, 20], 'M6', 15);
    ## S = thread (S, [10, 10, 20], 'M6', 12);
    ## @end group
    ## @end example
    ##
    ## @example
    ## @group
    ## ## A rod of 10 threaded M10 for 15 from its end
    ## S = solid.cylinder (5, 40);
    ## S = thread (S, [0, 0, 40], 'M10', 15);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.hole, solid.threadspec, solid.helix}
    ## @end deftypefn
    function this = thread (this, P, NAME, DEPTH, varargin)

      ## Input validation
      if (nargin < 4)
        error ("solid.Shape.thread: invalid number of input arguments.");
      endif
      [errmsg, opt] = options (varargin, struct ('Direction', [], 'At', [], ...
                                                 'Custom', []));
      if (isempty (errmsg))
        [errmsg, P, opt.Direction] = placement (P, opt.Direction, opt.At);
      endif
      if (isempty (errmsg) && ! ischar (NAME))
        errmsg = strcat ("NAME must be the name of an ISO metric thread", ...
                         " such as 'M6' or 'M10x1.25'.");
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.thread: %s", errmsg);
      endif
      if (isempty (opt.Custom))
        t = solid.threadspec (NAME);
      else
        t = solid.threadspec (NAME, 'Custom', opt.Custom);
      endif
      if (! isfloat (DEPTH) || ! isreal (DEPTH) || ! isscalar (DEPTH)
          || ! (DEPTH > 0))
        error (strcat ("solid.Shape.thread: DEPTH must be positive, or Inf", ...
                       " to thread right through."));
      endif

      if (isempty (this.Data))
        return;
      endif

      ## The diameters the axis may meet, and the tools that cut each thread,
      ## made along the z axis and turned onto the direction.  A thread runs
      ## at most a pitch past the far side of the part, however deep asked.
      d = t.d;
      p = t.P;
      D1 = d - 1.25 * sqrt (3) / 2 * p;
      d0 = d - 3 * sqrt (3) / 16 * p;
      v = double (opt.Direction(:)') / norm (opt.Direction);
      B = bbox (this);
      [X, Y, Z] = ndgrid (B([1, 4]), B([2, 5]), B([3, 6]));
      C = [X(:), Y(:), Z(:)];
      tol = 1e-6;
      n = rows (P);
      specs = cell (1, n);
      tools = cell (1, n);
      for i = 1:n
        far = max ((C - P(i,:)) * v');
        L = max (min (DEPTH, far + p), p);
        ## The bores and cylinders about the axis that fit a thread; a wall
        ## that fits both is thinner than either thread is deep
        [bores, rods, walls] = axisrings (this, P(i,:), v, min (L / 2, p));
        inner = bores(2 * bores >= D1 - tol & 2 * bores < d - tol);
        outer = rods(2 * rods >= d0 - tol & 2 * rods <= d + tol);
        if (! isempty (inner) && ! isempty (outer))
          error (strcat ("solid.Shape.thread: %s at (%s): the wall between", ...
                         " the bore of %.3f and the cylinder of %.3f is", ...
                         " too thin to thread."), t.name, ...
                 pointstr (P(i,:)), 2 * min (inner), 2 * max (outer));
        endif
        ## The space the cutter clears beside the profile, from a pitch
        ## before the point to the groove's far corner, must hold no material
        ## or the thread would cut beyond its bore or cylinder
        len = L + p + p / 20 * tand (30);
        if (! isempty (inner))
          r = min (inner);
          ## A cylinder round the bore inside the root would be cut through
          wall = rods(rods > r & 2 * rods < d + tol);
          if (! isempty (wall))
            error (strcat ("solid.Shape.thread: %s at (%s): the thread", ...
                           " would cut through the cylinder of %.3f round", ...
                           " the bore."), t.name, pointstr (P(i,:)), ...
                   2 * min (wall));
          endif
          ## So would any other outline round it, as the flats of a hexagon
          ## or the teeth of a knurl, coming inside the root
          near = min (walls(bores == r));
          if (2 * near < d + tol)
            error (strcat ("solid.Shape.thread: %s at (%s): the thread", ...
                           " would cut through the wall round the bore,", ...
                           " %.3f from the axis at its nearest."), t.name, ...
                   pointstr (P(i,:)), near);
          endif
          specs{i} = {p, r, d / 2, true, L};
          K = solid.cylinder (r, len);
          beyond = "the bore is shallower than the thread";
        elseif (! isempty (outer))
          r = max (outer);
          K = subtract (solid.cylinder (r + p / 10, len), ...
                        solid.cylinder (r, len));
          if (2 * r > d - tol)
            r = t.major / 2;
          endif
          specs{i} = {p, D1 / 2, r, false, L};
          beyond = "the thread runs past the end of the cylinder";
        else
          error (strcat ("solid.Shape.thread: %s at (%s): the axis meets", ...
                         " neither a bore from %.3f up to %g nor a", ...
                         " cylinder from %.3f to %g."), t.name, ...
                 pointstr (P(i,:)), D1, d, d0, d);
        endif
        K = place (translate (K, [0, 0, -p]), v, P(i,:));
        if (volume (intersect (this, K)) > 1e-6 * volume (K))
          error ("solid.Shape.thread: %s at (%s): %s.", t.name, ...
                 pointstr (P(i,:)), beyond);
        endif
        tools{i} = place (cutter (specs{i}{:}), v, P(i,:));
      endfor

      ## Open CASCADE fails to cut some threads, returning the groove as a
      ## solid of its own or raising an error, so on failure each thread is
      ## cut on its own, and again another way where it fails.  A single
      ## thread goes straight to its own cut, which is the same cut.
      N = numsolids (this);
      ok = false;
      if (n > 1)
        try
          S = subtract (this, tools{:});
          ok = numsolids (S) <= N;
        end_try_catch
      endif
      if (ok)
        this = S;
      else
        for i = 1:n
          this = cutthread (this, tools{i}, specs{i}, v, P(i,:), t.name);
        endfor
      endif

    endfunction


    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} pocket (@var{S}, @var{R}, @var{DEPTH})
    ## @deftypefnx {solid.Shape} {@var{S} =} pocket (@dots{}, @qcode{'Taper'}, @var{A})
    ##
    ## Cut a pocket into a shape.
    ##
    ## @code{@var{S} = pocket (@var{S}, @var{R}, @var{DEPTH})} cuts the
    ## @code{geom.Region} @var{R} into @var{S}, @var{DEPTH} millimetres deep
    ## from the region's plane, against the normal of its @code{geom.UCS}:
    ## a recess, a slot, a cavity.  Lay the region on a face with the face's
    ## UCS, whose normal points out of the part, as @code{geom.UCS (@var{V})}
    ## picks one.  An @code{Inf} @var{DEPTH} cuts right through.
    ##
    ## The holes of the region are left standing as islands, so a pocket round
    ## a boss is one region with the boss as its hole, and @code{fillet} on
    ## the region rounds the pocket's corners as a milling cutter leaves them.
    ##
    ## @var{R} may also be a cell array of regions, such as @code{geom.text}
    ## and @code{geom.Region.union} return: every one is cut, each from its own
    ## plane, so a name is engraved in one call.  The cell must not be empty.
    ##
    ## The cutter comes from outside, as for @code{solid.Shape.hole}:
    ## everything inside the outline beyond the region's plane, on the side its
    ## normal points to, is cleared too, so a pocket drawn on a sloping or
    ## uneven face is clean all round.  A pocket drawn under material that its
    ## outline passes through first cuts that material as well.
    ##
    ## @code{@var{S} = pocket (@dots{}, @qcode{'Taper'}, @var{A})} leans the
    ## pocket's walls in by @var{A} degrees as they go deeper, the draft of a
    ## moulded recess, as @code{solid.extrude} tapers a wall; the islands
    ## widen to match.  @var{A} is in the range @math{(-90, 90)}.  A region
    ## with splines takes no taper, as for @code{solid.extrude}.
    ##
    ## Pocketing the empty shape leaves it empty.
    ##
    ## @example
    ## @group
    ## ## A slot 30 by 8 with round ends, 4 deep in the top of a plate
    ## S = solid.box (80, 40, 12);
    ## R = geom.Region ([25, 16, 0; 55, 16, 1; 55, 24, 0; 25, 24, 1]);
    ## R.UCS = geom.UCS ([0, 0, 1], [0, 0, 12]);
    ## S = pocket (S, R, 4);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.hole, solid.extrude, geom.Region.fillet}
    ## @end deftypefn
    function this = pocket (this, R, DEPTH, varargin)

      ## Input validation
      if (nargin < 3)
        error ("solid.Shape.pocket: invalid number of input arguments.");
      endif
      if (iscell (R))
        if (isempty (R))
          error ("solid.Shape.pocket: R must not be an empty cell array.");
        endif
        for k = 1:numel (R)
          this = pocket (this, R{k}, DEPTH, varargin{:});
        endfor
        return;
      endif
      if (! isa (R, 'geom.Region') || ! isscalar (R))
        error ("solid.Shape.pocket: R must be a geom.Region object.");
      endif
      if (! isfloat (DEPTH) || ! isreal (DEPTH) || ! isscalar (DEPTH)
          || ! (DEPTH > 0))
        error (strcat ("solid.Shape.pocket: DEPTH must be positive, or Inf", ...
                       " for a pocket right through."));
      endif
      [errmsg, opt] = options (varargin, struct ('Taper', 0));
      if (isempty (errmsg) && (! isfloat (opt.Taper)
                               || ! isreal (opt.Taper)
                               || ! isscalar (opt.Taper)
                               || ! (abs (opt.Taper) < 90)))
        errmsg = "Taper must be an angle in the range (-90, 90) degrees.";
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.pocket: %s", errmsg);
      endif

      if (isempty (this.Data))
        return;
      endif

      ## How far the part reaches from the region's origin, which is how far
      ## the cutter clears outwards and how deep a pocket through goes
      B = bbox (this);
      [X, Y, Z] = ndgrid (B([1, 4]), B([2, 5]), B([3, 6]));
      reach = max (sqrt (sum (([X(:), Y(:), Z(:)] - R.UCS.Origin) .^ 2, ...
                              2))) + 1;
      if (isinf (DEPTH))
        DEPTH = reach;
      endif

      ## The cutter: the region clearing outwards, tapering inwards
      try
        tool = solid.extrude (R, [reach, double(DEPTH)], ...
                              'Taper', [0, double(opt.Taper)]);
      catch err
        error ("solid.Shape.pocket: %s", ...
               regexprep (err.message, '^solid\.extrude: ', ''));
      end_try_catch
      this = subtract (this, tool);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} knurl (@var{S}, @var{F}, @var{PITCH})
    ## @deftypefnx {solid.Shape} {@var{S} =} knurl (@var{S}, @var{F}, @var{PITCH}, @var{DEPTH})
    ## @deftypefnx {solid.Shape} {@var{S} =} knurl (@dots{}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Knurl a cylindrical face of a shape.
    ##
    ## @code{@var{S} = knurl (@var{S}, @var{F}, @var{PITCH})} knurls the face
    ## of @var{S} indexed by @var{F}, as @code{solid.Shape.faces} returns it,
    ## with the crossed knurl of DIN 82 type RGE: two sets of grooves at 30
    ## degrees either side of the axis, teeth of 90 degrees, cut to full depth,
    ## leaving raised points.  @var{F} must be the outside of the part, a
    ## cylinder all the way round its axis, and must end at each end in a
    ## circle on one flat face square to the axis: the free end of the part,
    ## or a shoulder.  The wall under @var{F} must be thicker than the teeth
    ## are deep, and than a fillet or chamfer at an end of @var{F} is large:
    ## a bore, its thread or anything else reaching into it is an error.  So
    ## is a hole or pocket in @var{F}: knurl first, then cut it.
    ##
    ## @var{PITCH} is in millimetres, measured square to the grooves as DIN 82
    ## gives it, whose series is 0.5, 0.6, 0.8, 1.0, 1.2 and 1.6.  A whole
    ## number of grooves must go round the face, so the pitch is fitted to the
    ## nearest that gives one: the count is @math{pi d cos (A) / @var{PITCH}}
    ## rounded, @math{d} the diameter of @var{F} and @math{A} the
    ## angle of the grooves from the axis.  Rings, at 90 degrees, are counted
    ## along the length of @var{F} the same way.
    ##
    ## @code{@var{S} = knurl (@var{S}, @var{F}, @var{PITCH}, @var{DEPTH})}
    ## cuts the grooves @var{DEPTH} millimetres deep, which leaves flat lands
    ## at the diameter of @var{F} between them.  By default they are cut to
    ## full depth, where the flanks of neighbouring grooves meet in a point:
    ## @math{@var{P} / (2 tan (@var{PROFILE} / 2))}, half the pitch at 90
    ## degrees, @var{P} the pitch as fitted.  A deeper @var{DEPTH} is an
    ## error.
    ##
    ## The knurl is built on the surfaces of its teeth directly rather than
    ## cut, which makes it many times faster than cutting its grooves: a
    ## knob 28 across knurled at 0.8 takes about two seconds.
    ##
    ## That knob has nearly 5000 faces, and every later operation on the
    ## shape takes them all in: a boolean or a hole takes seconds, and a
    ## projection for a drawing over half a minute.  Knurl a part after its
    ## other features, and draw it from the shape before knurling, as a
    ## drawing shows a knurl: the blank, with the knurl's type and pitch
    ## stated, never its teeth.
    ##
    ## Name/Value pairs choose the knurl and finish its ends:
    ##
    ## @table @asis
    ## @item @qcode{'Pattern'}
    ## @qcode{'crossed'}, the default, for two sets of grooves, or
    ## @qcode{'single'} for one.
    ##
    ## @item @qcode{'Angle'}
    ## The angle of the grooves from the axis, in degrees, 30 by default.  A
    ## single knurl takes one angle in the range @math{(-90, 90)}, a positive
    ## one running right-handed, as a thread does, and 0 giving straight
    ## grooves along the axis.  A crossed knurl takes one angle @math{A} in
    ## the range @math{(0, 90)}, for grooves at @math{A} and @math{-A}, or two
    ## different angles from -90 to 90, 90 being rings round the axis.
    ##
    ## @item @qcode{'Points'}
    ## For a crossed knurl only: @qcode{'raised'}, the default, for points
    ## standing between the grooves, or @qcode{'indented'} for pits sunk
    ## between ridges.
    ##
    ## @item @qcode{'Profile'}
    ## The angle between the flanks of a tooth, in degrees, in the range
    ## @math{(0, 180)}, 90 by default.
    ##
    ## @item @qcode{'Fillet'}
    ## A radius @var{R} rounds every free end of @var{F}, an end at a shoulder
    ## being left as it is.  A cell array @code{@{@var{E}, @var{R}@}} rounds
    ## the end at the edge @var{E} to @var{R}, and with a row for each end,
    ## @code{@{@var{E1}, @var{R1}; @var{E2}, @var{R2}@}}, gives each its own
    ## radius.  The edges are the circles at the ends of @var{F}, as
    ## @code{solid.Shape.edges} returns them, and the knurl runs out over the
    ## fillet as it does on a blank whose edge was rounded before knurling.
    ##
    ## @item @qcode{'Chamfer'}
    ## As @qcode{'Fillet'}, for a chamfer of 45 degrees set back @var{D}
    ## millimetres both ways: a distance @var{D} for every free end, or
    ## @code{@{@var{E}, @var{D}@}} with a row for each end.
    ## @end table
    ##
    ## An end of @var{F} takes one fillet or chamfer at most, and an end at a
    ## shoulder takes neither, so naming its edge is an error.  The ends given
    ## by their edges are treated first, and a single size given to the other
    ## option treats the free ends left: @qcode{'Fillet', 0.5, 'Chamfer',
    ## @{@var{E}, 1@}} chamfers the end at @var{E} and rounds the other.  A
    ## single size with no free end left to take it is an error, as are single
    ## sizes for both.  The fillets and chamfers must be smaller than the
    ## radius of @var{F} and must not overlap.
    ##
    ## The types of DIN 82 are made so:
    ##
    ## @multitable @columnfractions 0.12 0.38 0.50
    ## @headitem Type @tab Knurl @tab Options
    ## @item RAA @tab straight @tab
    ## @qcode{'Pattern', 'single', 'Angle', 0}
    ## @item RBL @tab single, left-hand @tab
    ## @qcode{'Pattern', 'single', 'Angle', -30}
    ## @item RBR @tab single, right-hand @tab
    ## @qcode{'Pattern', 'single'}
    ## @item RGE @tab crossed, raised points @tab none
    ## @item RGV @tab crossed, indented points @tab
    ## @qcode{'Points', 'indented'}
    ## @item RKE @tab square, raised points @tab
    ## @qcode{'Angle', [0, 90]}
    ## @item RKV @tab square, indented points @tab
    ## @qcode{'Angle', [0, 90], 'Points', 'indented'}
    ## @end multitable
    ##
    ## @example
    ## @group
    ## ## A knob 28 across, knurled RGE 0.8 with its top edge chamfered 0.5
    ## S = solid.cylinder (14, 10);
    ## F = faces (S, 'Type', 'cylinder');
    ## E = edges (S, 'Type', 'circle', 'Within', [-15, -15, 10, 15, 15, 10]);
    ## S = knurl (S, F, 0.8, 'Chamfer', @{E, 0.5@});
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.faces, solid.Shape.edges, solid.Shape.fillet,
    ## solid.Shape.chamfer}
    ## @end deftypefn
    function this = knurl (this, F, PITCH, varargin)

      ## Input validation
      if (nargin < 3)
        error ("solid.Shape.knurl: invalid number of input arguments.");
      endif
      ## The depth, if given, then Name/Value pairs
      DEPTH = 0;
      if (mod (numel (varargin), 2) == 1)
        DEPTH = varargin{1};
        varargin(1) = [];
        if (! (isfloat (DEPTH) && isreal (DEPTH) && isscalar (DEPTH) &&
               isfinite (DEPTH) && DEPTH > 0))
          error (strcat ("solid.Shape.knurl: DEPTH must be a positive", ...
                         " and finite real scalar."));
        endif
      endif
      [errmsg, opt] = options (varargin, struct ('Pattern', 'crossed', ...
                                                 'Angle', 30, ...
                                                 'Points', [], ...
                                                 'Profile', 90, ...
                                                 'Fillet', [], ...
                                                 'Chamfer', []));
      if (! isempty (errmsg))
        error ("solid.Shape.knurl: %s", errmsg);
      endif
      if (! (isfloat (PITCH) && isreal (PITCH) && isscalar (PITCH) &&
             isfinite (PITCH) && PITCH > 0))
        error (strcat ("solid.Shape.knurl: PITCH must be a positive", ...
                       " and finite real scalar."));
      endif
      if (! any (strcmp (opt.Pattern, {'single', 'crossed'})))
        error ("solid.Shape.knurl: Pattern must be 'single' or 'crossed'.");
      endif
      crossed = strcmp (opt.Pattern, 'crossed');
      A = opt.Angle;
      if (crossed)
        a = A;
        a(a == -90) = 90;
        if (! isfloat (A) || ! isreal (A) || ! any (numel (A) == [1, 2])
            || (isscalar (A) && ! (A > 0 && A < 90))
            || (numel (A) == 2 && ! (all (abs (A) <= 90) && a(1) != a(2))))
          error (strcat ("solid.Shape.knurl: Angle of a crossed knurl must", ...
                         " be one angle in the range (0, 90) degrees, or", ...
                         " two different angles from -90 to 90."));
        endif
        if (isscalar (A))
          A = [A, -A];
        endif
      elseif (! isfloat (A) || ! isreal (A) || ! isscalar (A)
              || ! (abs (A) < 90))
        error (strcat ("solid.Shape.knurl: Angle of a single knurl must be", ...
                       " in the range (-90, 90) degrees."));
      endif
      indented = false;
      if (! isempty (opt.Points))
        if (! crossed)
          error ("solid.Shape.knurl: Points applies only to a crossed knurl.");
        endif
        if (! any (strcmp (opt.Points, {'raised', 'indented'})))
          error ("solid.Shape.knurl: Points must be 'raised' or 'indented'.");
        endif
        indented = strcmp (opt.Points, 'indented');
      endif
      P = opt.Profile;
      if (! isfloat (P) || ! isreal (P) || ! isscalar (P)
          || ! (P > 0 && P < 180))
        error (strcat ("solid.Shape.knurl: Profile must be an angle in the", ...
                       " range (0, 180) degrees."));
      endif
      if (! isscalar (F)
          || ! isempty (checkindex (F, numfaces (this), 'F', 'face', false)))
        error ("solid.Shape.knurl: F must be a single face index of S.");
      endif
      if (! ismember (F, faces (this, 'Type', 'cylinder')))
        error ("solid.Shape.knurl: F must be a cylindrical face.");
      endif
      ## The treated ends, a row [EDGE, TYPE, SIZE] each, TYPE 1 for a fillet
      ## and 2 for a chamfer, EDGE 0 for every free end left
      T = zeros (0, 3);
      kinds = {'Fillet', 'R', 'radius'; 'Chamfer', 'D', 'distance'};
      for k = 1:2
        if (isempty (opt.(kinds{k,1})))
          continue;
        endif
        [errmsg, E] = endedges (opt.(kinds{k,1}), kinds{k,:}, numedges (this));
        if (! isempty (errmsg))
          error ("solid.Shape.knurl: %s", errmsg);
        endif
        T = [T; E(:,1), k * ones(rows (E), 1), E(:,2)];
      endfor
      if (sum (T(:,1) == 0) > 1)
        error (strcat ("solid.Shape.knurl: Fillet and Chamfer cannot both", ...
                       " be a single size for every free end."));
      endif
      E = T(T(:,1) > 0, 1);
      if (numel (unique (E)) != numel (E))
        error (strcat ("solid.Shape.knurl: an edge can take one fillet or", ...
                       " chamfer only."));
      endif

      r = occt ('solid.Shape.knurl', 'knurl', this.Data, double (F), ...
                double (PITCH), double (DEPTH), double (A), indented, ...
                double (P), T);
      S = this;
      this.Data = r{1};
      [this.Colour, this.Name] = inherit (r{2}, S);

    endfunction

  endmethods

################################################################################
##                       ** Sections and projections **                       ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'section'         'projection'                                             ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{R} =} section (@var{S}, @var{U})
    ##
    ## Cut a shape with a plane.
    ##
    ## @code{@var{R} = section (@var{S}, @var{U})} cuts the shape @var{S} with
    ## the plane of the @code{geom.UCS} @var{U} and returns the cut as a
    ## 1-by-@math{N} cell array of @code{geom.Region} objects in @var{U}, one
    ## for each separate piece of it, largest first.  A piece is an outline
    ## with the holes in it; a piece standing in a hole of another is a piece
    ## of its own.  A face of @var{S} lying in the plane is part of the cut, so
    ## a box cut in the plane of its base gives its base.  Where the plane
    ## only touches @var{S}, along an edge or at a point, or misses it, the cut
    ## has no area and @var{R} is the empty @code{cell (1, 0)}.
    ##
    ## Open CASCADE can lose a piece of the cut where the plane meets a curved
    ## face at a grazing angle, as a plane within a few hundredths of a
    ## millimetre of the wall of a tapped bore does.  @code{section} then
    ## raises an error rather than return the cut with the piece missing.
    ##
    ## The cut is exact enough to build from again.  Straight edges are
    ## straight segments and circles are arcs, a whole circle two half arcs.
    ## An ellipse or another conic, as a plane cuts from a cylinder or a cone at
    ## a slant, is a rational @code{geom.Spline} that follows it exactly; any
    ## other curve, as from a torus or a spline surface, is the B-spline Open
    ## CASCADE computes for it.
    ##
    ## @example
    ## @group
    ## ## A plate with a bore, cut through the middle and made again
    ## S = solid.extrude (geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
    ##                                 @{[20, 20, 1; 40, 20, 1]@}), 8);
    ## R = section (S, geom.UCS ([0, 0, 1], [0, 0, 4]));
    ## T = solid.extrude (R@{1@}, 2);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Region, geom.UCS, solid.extrude}
    ## @end deftypefn
    function R = section (this, U)

      ## Input validation
      if (nargin != 2)
        error ("solid.Shape.section: invalid number of input arguments.");
      endif
      if (! isa (U, 'geom.UCS') || ! isscalar (U))
        error ("solid.Shape.section: U must be a geom.UCS object.");
      endif

      R = cell (1, 0);
      if (isempty (this.Data))
        return;
      endif
      F = occt ('solid.Shape.section', 'section', this.Data, ...
                [U.Origin; U.XAxis; U.YAxis; U.Normal]);
      R = geom.Region.__faces__ (F, U);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{R} =} projection (@var{S})
    ## @deftypefnx {solid.Shape} {@var{R} =} projection (@var{S}, @var{U})
    ##
    ## Outline of a shape seen along a direction.
    ##
    ## @code{@var{R} = projection (@var{S}, @var{U})} projects the shape @var{S}
    ## along the normal of the @code{geom.UCS} @var{U} onto its plane and
    ## returns the area it covers as a 1-by-@math{N} cell array of
    ## @code{geom.Region} objects in @var{U}, one for each separate piece of
    ## it, largest first.  This is the shadow the shape casts on the plane in
    ## light falling along the normal: a bore seen along its axis is a hole in
    ## the outline, and seen from the side it is not there.  A piece standing
    ## in a hole of another is a piece of its own.  Where the plane lies along
    ## its normal changes only the plane the regions lie in.  The empty shape
    ## has no outline, and @var{R} is the empty @code{cell (1, 0)}.
    ##
    ## @code{@var{R} = projection (@var{S})} projects onto the @math{xy} plane,
    ## as seen from above, which is what OpenSCAD's @code{projection} does.
    ##
    ## The outline is drawn from the edges of @var{S} and the outlines of its
    ## curved faces.  Straight edges are straight segments and a circle seen
    ## square on is a circle; a circle seen at a slant is the ellipse it makes,
    ## and the outline of a cylinder, a cone or a sphere is exact too.  That of
    ## a torus or of a spline surface is the B-spline Open CASCADE fits to it.
    ## @code{section} cuts a shape with a plane instead.
    ##
    ## @example
    ## @group
    ## ## A plate with a bore, seen from above and from the front
    ## S = subtract (solid.box (80, 40, 12), ...
    ##               translate (solid.cylinder (4, 12), [20, 20, 0]));
    ## top = projection (S);
    ## numel (top@{1@}.Holes)
    ## @result{} 1
    ## front = projection (S, geom.UCS ([0, -1, 0], [0, 0, 0]));
    ## numel (front@{1@}.Holes)
    ## @result{} 0
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.section, geom.Region, geom.UCS}
    ## @end deftypefn
    function R = projection (this, U)

      ## Input validation
      if (nargin < 2)
        U = geom.UCS ();
      elseif (! isa (U, 'geom.UCS') || ! isscalar (U))
        error ("solid.Shape.projection: U must be a geom.UCS object.");
      endif

      R = cell (1, 0);
      if (isempty (this.Data))
        return;
      endif
      F = occt ('solid.Shape.projection', 'projection', this.Data, ...
                [U.Origin; U.XAxis; U.YAxis; U.Normal]);
      R = geom.Region.__faces__ (F, U);

    endfunction

  endmethods

################################################################################
##                       ** Hulls, sizes and copies **                        ##
################################################################################
##                             Available Methods                              ##
##                                                                            ##
## 'hull'            'resize'          'copy'            'rectarray'          ##
## 'polararray'                                                               ##
################################################################################

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{H} =} hull (@var{A}, @var{B}, @dots{})
    ## @deftypefnx {solid.Shape} {@var{H} =} hull (@dots{}, @qcode{'Tolerance'}, @var{TOL})
    ##
    ## The convex hull of shapes and points.
    ##
    ## @code{@var{H} = hull (@var{A}, @var{B}, @dots{})} returns the smallest
    ## convex solid that holds every shape and point given, the shape a sheet
    ## shrunk round them takes.  Each argument is a @code{solid.Shape} or an
    ## @math{N}-by-3 matrix of points.  This is OpenSCAD's @code{hull} of
    ## solids: a slot from two cylinders, a rounded block from eight spheres
    ## at its corners, a tapered arm from the bosses at its ends.  Empty
    ## shapes add nothing, and the hull of nothing is the empty shape.
    ##
    ## The hull has flat faces.  The surface of each shape is taken as the
    ## points of a triangulation that strays no further than @var{TOL} from
    ## it, 0.01 by default, so the hull lies inside the exact one by at most
    ## @var{TOL}; where the exact hull is flat, as between boxes, it is exact
    ## and its triangles meet as whole faces.  Open CASCADE has no exact hull
    ## of curved faces.
    ##
    ## The hull is a new solid, no one operand's material, so it takes no
    ## @code{Colour} and no @code{Name} from them.
    ##
    ## @example
    ## @group
    ## ## A slot 30 long and 10 wide, 4 deep, cut through a plate
    ## C = solid.cylinder (5, 4);
    ## slot = hull (C, translate (C, [20, 0, 0]));
    ## plate = subtract (translate (solid.box (50, 30, 4), [-15, -15, 0]), ...
    ##                   slot);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Region.hull, solid.polyhedron, solid.Shape.union}
    ## @end deftypefn
    function H = hull (varargin)

      ## Input validation
      TOL = 0.01;
      k = find (cellfun (@ischar, varargin), 1);
      args = {};
      if (! isempty (k))
        args = varargin(k:end);
        varargin = varargin(1:k-1);
      endif
      if (mod (numel (args), 2) != 0)
        error ("solid.Shape.hull: Name/Value arguments must come in pairs.");
      endif
      for ii = 1:2:numel (args)
        name = args{ii};
        val = args{ii+1};
        if (! ischar (name) || ! isrow (name))
          error ("solid.Shape.hull: option names must be character vectors.");
        endif
        switch (lower (name))
          case 'tolerance'
            TOL = val;
            if (! (isfloat (TOL) && isreal (TOL) && isscalar (TOL) &&
                   isfinite (TOL) && TOL > 0))
              error (strcat ("solid.Shape.hull: Tolerance must be a", ...
                             " positive and finite real scalar."));
            endif
          otherwise
            error ("solid.Shape.hull: unknown option '%s'.", name);
        endswitch
      endfor
      isshape = cellfun (@(x) isa (x, 'solid.Shape') && isscalar (x), ...
                         varargin);
      ispoints = cellfun (@(x) isfloat (x) && isreal (x) && ismatrix (x) ...
                               && columns (x) == 3 && all (isfinite (x(:))), ...
                          varargin);
      if (! all (isshape | ispoints))
        error (strcat ("solid.Shape.hull: every operand must be a", ...
                       " solid.Shape object or an N-by-3 matrix of points."));
      endif

      P = cellfun (@double, varargin(ispoints), 'UniformOutput', false);
      for S = varargin(isshape)
        if (! isempty (S{1}))
          P{end+1} = occt ('solid.Shape.hull', 'points', S{1}.Data, ...
                           double (TOL), 20);
        endif
      endfor
      P = unique (vertcat (zeros (0, 3), P{:}), 'rows');
      if (isempty (P))
        H = solid.Shape ();
        return;
      endif
      flat = 'solid.Shape.hull: the hull is flat and encloses no volume.';
      if (rows (P) < 4)
        error (flat);
      endif
      sv = svd (P - mean (P, 1));
      if (sv(3) <= 1e-12 * sv(1))
        error (flat);
      endif
      try
        F = convhulln (P);
      catch
        error (flat);
      end_try_catch
      H = solid.polyhedron (polymesh.Mesh (P, F));

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{S} =} resize (@var{S}, @var{SZ})
    ## @deftypefnx {solid.Shape} {@var{S} =} resize (@var{S}, @var{SZ}, @qcode{'Uniform'}, @var{TF})
    ##
    ## Scale a shape to a size.
    ##
    ## @code{@var{S} = resize (@var{S}, @var{SZ})} scales the shape evenly so
    ## that its bounding box is as large as it can be within the sizes
    ## @code{@var{SZ} = [@var{x}, @var{y}, @var{z}]} in millimetres; a size of
    ## 0 leaves that direction free.  @code{resize (@var{S}, [30, 0, 0])}
    ## makes the shape 30 long in @math{x} and keeps its proportions.  The
    ## corner of the box at the least @math{x}, @math{y} and @math{z} stays
    ## where it is, and every face keeps its type: a cylinder stays a
    ## cylinder.
    ##
    ## With @qcode{'Uniform'} set to @code{false} each direction given is
    ## scaled to its size on its own and a direction left at 0 keeps its
    ## size, as OpenSCAD's @code{resize} does.  Flat faces stay planes, but a
    ## curved face stretched so is no longer a cylinder, a cone or a sphere:
    ## Open CASCADE carries it as the exact B-spline surface it becomes, so
    ## @code{solid.Shape.faces} finds a stretched cylinder among the faces of
    ## type @qcode{'bspline'}, not @qcode{'cylinder'}.
    ##
    ## @example
    ## @group
    ## ## A sphere of diameter 10 stretched into an ellipsoid 40 by 20 by 10
    ## E = resize (solid.sphere (5), [40, 20, 0], 'Uniform', false);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.scale, solid.ellipsoid, geom.Region.resize}
    ## @end deftypefn
    function this = resize (this, SZ, varargin)

      ## Input validation
      if (nargin != 2 && nargin != 4)
        error ("solid.Shape.resize: invalid number of input arguments.");
      endif
      if (! isfloat (SZ) || ! isreal (SZ) || numel (SZ) != 3
          || ! all (isfinite (SZ)) || any (SZ < 0) || ! any (SZ > 0))
        error (strcat ("solid.Shape.resize: SZ must be a 3-element vector", ...
                       " of nonnegative finite sizes, not all zero."));
      endif
      [errmsg, even] = flag (varargin, 'Uniform', true);
      if (! isempty (errmsg))
        error ("solid.Shape.resize: %s", errmsg);
      endif

      if (isempty (this.Data))
        return;
      endif
      [B, L] = bbox (this);
      f = double (SZ(:)') ./ L;
      given = SZ(:)' > 0;
      if (even)
        f(:) = min (f(given));
      else
        f(! given) = 1;
      endif
      if (all (f == f(1)))
        this.Data = occt ('solid.Shape.resize', 'scale', this.Data, f(1), ...
                          B(1:3));
      else
        this.Data = occt ('solid.Shape.resize', 'gscale', this.Data, f, ...
                          B(1:3));
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{C} =} copy (@var{S}, @var{D})
    ##
    ## Copies of a shape, united.
    ##
    ## @code{@var{C} = copy (@var{S}, @var{D})} places a copy of the shape
    ## moved by each row of @var{D}, an @math{N}-by-3 matrix of offsets in
    ## millimetres, and returns them as one shape, united as
    ## @code{solid.Shape.union} unites shapes.  The shape itself is among them
    ## only where a row of @var{D} is zero.  Copies apart from one another are
    ## kept side by side, separate solids of the one shape, with no boolean
    ## to compute; only copies that overlap or touch are fused, so a hundred
    ## pins standing apart cost little more than one.  This is OpenSCAD's
    ## @code{for} loop of @code{translate}.
    ##
    ## @example
    ## @group
    ## ## Four pins on the corners of a square, one shape of four solids
    ## P = copy (solid.cylinder (2, 10), ...
    ##           [0, 0, 0; 30, 0, 0; 0, 30, 0; 30, 30, 0]);
    ## numsolids (P)
    ## @result{} 4
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.rectarray, solid.Shape.polararray, geom.Region.copy}
    ## @end deftypefn
    function C = copy (this, D)

      ## Input validation
      if (nargin != 2)
        error ("solid.Shape.copy: invalid number of input arguments.");
      endif
      if (! isfloat (D) || ! isreal (D) || ! ismatrix (D)
          || columns (D) != 3 || rows (D) < 1 || ! all (isfinite (D(:))))
        error (strcat ("solid.Shape.copy: D must be an N-by-3 real matrix", ...
                       " of finite offsets."));
      endif

      C = copies (this, double (D), [], [], [], 'solid.Shape.copy');

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{C} =} rectarray (@var{S}, @var{COUNT}, @var{SPACING})
    ##
    ## Copies of a shape in rows, columns and layers, united.
    ##
    ## @code{@var{C} = rectarray (@var{S}, @var{COUNT}, @var{SPACING})} places
    ## @code{@var{COUNT} = [@var{nx}, @var{ny}, @var{nz}]} copies of the shape
    ## along the @math{x}, @math{y} and @math{z} axes, @code{@var{SPACING} =
    ## [@var{dx}, @var{dy}, @var{dz}]} millimetres apart, the first where the
    ## shape is; a negative spacing runs the other way.  It returns them as one
    ## shape, as @code{solid.Shape.copy} does.  This is a grid of holes cut
    ## into a plate in one subtraction, or of ribs, pins or bosses standing on
    ## it.
    ##
    ## @example
    ## @group
    ## ## A plate 70 by 50 with four rows of six holes of diameter 4
    ## H = rectarray (translate (solid.cylinder (2, 5), [10, 10, 0]), ...
    ##                [6, 4, 1], [10, 10, 0]);
    ## P = subtract (solid.box (70, 50, 5), H);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.copy, solid.Shape.polararray}
    ## @end deftypefn
    function C = rectarray (this, COUNT, SPACING)

      ## Input validation
      if (nargin != 3)
        error ("solid.Shape.rectarray: invalid number of input arguments.");
      endif
      [errmsg, D] = geom.__grid__ (COUNT, SPACING, 3);
      if (! isempty (errmsg))
        error ("solid.Shape.rectarray: %s", errmsg);
      endif

      C = copies (this, D, [], [], [], 'solid.Shape.rectarray');

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {solid.Shape} {@var{C} =} polararray (@var{S}, @var{N}, @var{ANGLE})
    ## @deftypefnx {solid.Shape} {@var{C} =} polararray (@var{S}, @var{N}, @var{ANGLE}, @var{AXIS})
    ## @deftypefnx {solid.Shape} {@var{C} =} polararray (@var{S}, @var{N}, @var{ANGLE}, @var{AXIS}, @var{P})
    ## @deftypefnx {solid.Shape} {@var{C} =} polararray (@dots{}, @qcode{'Rotate'}, @var{TF})
    ##
    ## Copies of a shape round an axis, united.
    ##
    ## @code{@var{C} = polararray (@var{S}, @var{N}, @var{ANGLE}, @var{AXIS},
    ## @var{P})} places @var{N} copies of the shape round the axis through the
    ## point @var{P} in the direction @var{AXIS}, the @math{z} axis through the
    ## origin by default, the first where the shape is and the rest turned on
    ## by the right-hand rule, the other way for a negative @var{ANGLE}.  A
    ## whole turn, @var{ANGLE} of 360, spaces them evenly @code{@var{ANGLE} /
    ## @var{N}} apart; a part of a turn puts one at each end, @code{@var{ANGLE}
    ## / (@var{N} - 1)} apart.  It returns them as one shape, as
    ## @code{solid.Shape.copy} does.
    ##
    ## Each copy is turned as it goes round, as the holes of a bolt circle,
    ## the teeth of a wheel or the blades of a fan are.  With
    ## @qcode{'Rotate'} set to @code{false} each copy keeps the shape's own
    ## direction, moved as the centre of its bounding box moves.
    ##
    ## @example
    ## @group
    ## ## A flange of diameter 60 with six bolt holes of 6 on a circle of 40
    ## H = polararray (translate (solid.cylinder (3, 8), [20, 0, 0]), 6, 360);
    ## F = subtract (solid.cylinder (30, 8), solid.cylinder (10, 8), H);
    ## @end group
    ## @end example
    ##
    ## @seealso{solid.Shape.copy, solid.Shape.rectarray, solid.Shape.rotate}
    ## @end deftypefn
    function C = polararray (this, N, ANGLE, varargin)

      ## Input validation
      if (nargin < 3 || nargin > 7)
        error ("solid.Shape.polararray: invalid number of input arguments.");
      endif
      AXIS = [0, 0, 1];
      P = [0, 0, 0];
      if (! isempty (varargin) && ! ischar (varargin{1}))
        AXIS = varargin{1};
        varargin(1) = [];
        if (! isempty (varargin) && ! ischar (varargin{1}))
          P = varargin{1};
          varargin(1) = [];
        endif
      endif
      [errmsg, a] = geom.__turns__ (N, ANGLE);
      if (isempty (errmsg))
        errmsg = checkvec (AXIS, 'AXIS', true);
      endif
      if (isempty (errmsg))
        errmsg = checkvec (P, 'P');
      endif
      if (isempty (errmsg))
        [errmsg, turning] = flag (varargin, 'Rotate', true);
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.polararray: %s", errmsg);
      endif

      k = double (AXIS(:)') / norm (double (AXIS));
      P = double (P(:)');
      if (turning || isempty (this.Data))
        C = copies (this, zeros (numel (a), 3), a, k, P, ...
                    'solid.Shape.polararray');
      else
        ## The centre of the box carried round the axis
        B = bbox (this);
        v = (B(1:3) + B(4:6)) / 2 - P;
        t = a(:) * pi / 180;
        w = v .* cos (t) + cross (repmat (k, numel (t), 1), ...
                                  repmat (v, numel (t), 1), 2) .* sin (t) ...
            + k * (k * v') .* (1 - cos (t));
        C = copies (this, w - v, [], [], [], 'solid.Shape.polararray');
      endif

    endfunction

  endmethods


  methods

    function this = set.Colour (this, C)

      if (isempty (C))
        this.Colour = [];
        return;
      endif
      n = numsolids (this);
      if (! isfloat (C) || ! isreal (C) || ! ismatrix (C) || columns (C) != 3 ||
          ! any (rows (C) == [1, n]) || n == 0 ||
          ! all (all (isnan (C), 2) | all (C >= 0 & C <= 1, 2)))
        error (strcat ("solid.Shape: Colour must be empty or a 1-by-3 or", ...
                       " N-by-3 matrix of values from 0 to 1, N the number", ...
                       " of solids, a row of NaN for no colour."));
      endif
      C = repmat (double (C), n / rows (C), 1);
      if (all (isnan (C(:))))
        C = [];
      endif
      this.Colour = C;

    endfunction

    function this = set.Name (this, N)

      if (isempty (N))
        this.Name = {};
        return;
      endif
      n = numsolids (this);
      if (ischar (N))
        N = {N};
      endif
      if (! iscell (N) || ! isvector (N) || ! any (numel (N) == [1, n]) ||
          n == 0 || ! all (cellfun (@(x) ischar (x) && (isrow (x) ||
                                                        isempty (x)), N)))
        error (strcat ("solid.Shape: Name must be empty, a character", ...
                       " vector, or a cell of 1 or N character vectors, N", ...
                       " the number of solids, '' for no name."));
      endif
      N = repmat (N(:), n / numel (N), 1);
      none = cellfun (@isempty, N);
      N(none) = {''};
      if (all (none))
        N = {};
      endif
      this.Name = N;

    endfunction

  endmethods

endclassdef

## Run an Open CASCADE operation on behalf of CALLER, which names any error
function out = occt (caller, cmd, varargin)

  out = __occt__ (cmd, caller, varargin{:});

endfunction

## Validate the operands of a boolean, which must be scalar solid.Shape objects;
## Octave only calls the method when at least one of them is a solid.Shape.
## Returns an error message body, empty when they are valid.
function errmsg = checkoperands (S)

  errmsg = '';
  if (! all (cellfun (@(x) isa (x, 'solid.Shape') && isscalar (x), S)))
    errmsg = "every operand must be a solid.Shape object.";
  endif

endfunction

## The copies of the shape S, each turned A(k) degrees about the unit axis K
## through P when A is given, then moved by the row k of D, as one shape for
## CALLER: copies apart are put side by side, and only when the boxes of two
## meet are they fused
function C = copies (S, D, A, K, P, caller)

  C = S;
  if (isempty (S.Data))
    return;
  endif
  n = rows (D);
  data = cell (1, n);
  B = zeros (n, 6);
  for k = 1:n
    data{k} = S.Data;
    if (! isempty (A) && A(k) != 0)
      data{k} = occt (caller, 'rotate', data{k}, A(k), K, P);
    endif
    if (any (D(k,:)))
      data{k} = occt (caller, 'translate', data{k}, D(k,:));
    endif
    B(k,:) = occt (caller, 'bbox', data{k});
  endfor
  tol = 1e-9 * max ([1, abs(B(:))']);
  apart = true (n);
  for j = 1:3
    apart &= B(:,j+3) < B(:,j)' - tol | B(:,j) > B(:,j+3)' + tol;
  endfor
  apart(1:n+1:end) = true;
  if (n == 1)
    C = solid.Shape (data{1});
    C.Colour = S.Colour;
    C.Name = S.Name;
    return;
  elseif (all (apart(:)))
    r = occt (caller, 'compound', data{:});
  else
    r = occt (caller, 'fuse', data{:});
  endif
  C = solid.Shape (r{1});
  [C.Colour, C.Name] = inherit (r{2}, repmat ({S}, 1, n){:});

endfunction

## The mesh of the shape S that tessellate describes, made for CALLER, and
## the solid each of its triangles lies on, an index from 1 into a map of
## them, 0 for a face of no solid
function [M, K] = meshof (S, TOL, caller)

  c = occt (caller, 'tessellate', S.Data, double (TOL), 20);

  ## Points that are equal are one vertex, and a triangle two of whose
  ## corners become one is dropped
  [V, ~, j] = unique (c{1}, 'rows', 'stable');
  F = reshape (j(c{2}), size (c{2}));
  keep = F(:,1) != F(:,2) & F(:,2) != F(:,3) & F(:,3) != F(:,1);
  K = c{3}(keep);
  M = polymesh.Mesh (V, F(keep,:));

  ## Each triangle in the colour of its solid, grey where it has none
  if (! isempty (S.Colour))
    C = [NaN, NaN, NaN; S.Colour](K + 1,:);
    C(isnan (C(:,1)),:) = repmat ([0.72, 0.74, 0.78], ...
                                  nnz (isnan (C(:,1))), 1);
    M.FaceColour = C;
  endif

endfunction

## The shape S written to the 3MF file FILE within TOL as an object for each
## name its solids carry, in a group named BASE when there are several; the
## solids without a name are an object without one
function write3mf (S, FILE, BASE, TOL)

  [M, K] = meshof (S, TOL, 'solid.Shape.write');
  N = [{''}; names(S)](K + 1);
  [u, ~, g] = unique (N, 'stable');
  n = numel (u);
  [V, F, FC] = deal (cell (1, n));
  for k = 1:n
    t = (g == k);
    f = M.Faces(t,:);
    [iv, ~, jv] = unique (f(:));
    V{k} = M.Vertices(iv,:);
    F{k} = reshape (jv, [], 3);
    FC{k} = zeros (0, 3);
    if (! isempty (M.FaceColour))
      FC{k} = M.FaceColour(t,:);
    endif
  endfor
  C = {[]};
  if (n > 1)
    u{end+1} = BASE;
    [V{end+1}, F{end+1}, FC{end+1}] = deal ([]);
    C = [repmat({[]}, 1, n), ...
         {[(1:n)', zeros(n, 3), repmat([1, 0, 0, 0, 1, 0, 0, 0, 1], n, 1)]}];
  endif
  __mesh__ ('write3mf', 'solid.Shape.write', FILE, u(:)', V, F, FC, C);

endfunction

## The colours and names of a result's solids, each the colour of the first
## coloured solid it came from and the name of the first named one: L a row
## for each, the indices from 1 of the solids it came from, in increasing
## order and padded with 0, into the solids of the shapes SRC, those of each
## in turn
function [C, N] = inherit (L, varargin)

  C = [];
  N = {};
  if (isempty (L))
    return;
  endif
  if (! all (cellfun (@(s) isempty (s.Colour), varargin)))
    P = cellfun (@colours, varargin, 'UniformOutput', false);
    P = [NaN, NaN, NaN; vertcat(P{:})];
    C = P(firstof (L, ! isnan (P(:,1))) + 1,:);
  endif
  if (! all (cellfun (@(s) isempty (s.Name), varargin)))
    P = cellfun (@names, varargin, 'UniformOutput', false);
    P = [{''}; vertcat(P{:})];
    N = P(firstof (L, ! cellfun (@isempty, P)) + 1);
  endif

endfunction

## For each row of L, as inherit takes it, the first solid it came from for
## which HAS is true, HAS indexed from 0 for no solid, or 0 when none is
function first = firstof (L, HAS)

  has = reshape (HAS(L + 1), size (L));
  [found, k] = max (has, [], 2);
  first = L(sub2ind (size (L), (1:rows (L))', k));
  first(! found) = 0;

endfunction

## S without colours or names, a tool whose material is taken away
function S = bare (S)

  S.Colour = [];
  S.Name = {};

endfunction

## The colour of each solid of S, a row of NaN where it has none
function C = colours (S)

  C = S.Colour;
  if (isempty (C))
    C = NaN (numsolids (S), 3);
  endif

endfunction

## The name of each solid of S, a cell column, '' where it has none
function N = names (S)

  N = S.Name;
  if (isempty (N))
    N = repmat ({''}, numsolids (S), 1);
  endif

endfunction

## The value of the option NAME in the Name/Value pairs ARGS, a logical
## scalar, DEF when not given.  Returns an error message body, empty when ARGS
## is valid.
function [errmsg, TF] = flag (ARGS, NAME, DEF)

  errmsg = '';
  TF = DEF;
  if (mod (numel (ARGS), 2) != 0)
    errmsg = "Name/Value arguments must come in pairs.";
    return;
  endif
  for ii = 1:2:numel (ARGS)
    name = ARGS{ii};
    val = ARGS{ii+1};
    if (! ischar (name) || ! isrow (name))
      errmsg = "option names must be character vectors.";
      return;
    endif
    switch (lower (name))
      case lower (NAME)
        if (! islogical (val) || ! isscalar (val))
          errmsg = sprintf ("%s must be true or false.", NAME);
          return;
        endif
        TF = logical (val);
      otherwise
        errmsg = sprintf ("unknown option '%s'.", name);
        return;
    endswitch
  endfor

endfunction

## Count the distinct sub-shapes of one kind
function N = topology (S, kind, caller)

  if (isempty (S.Data))
    N = 0;
  else
    N = occt (caller, 'count', S.Data, kind);
  endif

endfunction

## Validate a 3-element vector, which must be nonzero when NONZERO is true.
## Returns an error message body, empty when V is valid.
function errmsg = checkvec (V, name, nonzero = false)

  errmsg = '';
  if (! isfloat (V) || ! isreal (V) || numel (V) != 3
      || ! isvector (V) || ! all (isfinite (V)))
    errmsg = sprintf (strcat ("%s must be a real 3-element vector of", ...
                              " finite values."), name);
  elseif (nonzero && all (V == 0))
    errmsg = sprintf ("%s must not be the zero vector.", name);
  endif

endfunction

## Parse Name/Value pairs into the fields of OPT, which holds their defaults.
## Returns an error message body, empty when they are valid.
function [errmsg, opt] = options (args, opt)

  errmsg = '';
  if (mod (numel (args), 2) != 0)
    errmsg = "Name/Value arguments must come in pairs.";
    return;
  endif
  known = fieldnames (opt);
  for ii = 1:2:numel (args)
    name = args{ii};
    val = args{ii+1};
    if (! ischar (name) || ! isrow (name))
      errmsg = "option names must be character vectors.";
      return;
    endif
    switch (lower (name))
      case lower (known)
        key = known{strcmpi (name, known)};
        if (isempty (val))
          errmsg = sprintf ("%s must not be empty.", key);
          return;
        endif
        opt.(key) = val;
      otherwise
        errmsg = sprintf ("unknown option '%s'.", name);
        return;
    endswitch
  endfor

endfunction

## The relative error the volume integration aims at, from the Name/Value
## pairs ARGS, 1e-9 when not given.  Returns an error message body, empty when
## ARGS is valid.
function [errmsg, TOL] = reltol (ARGS)

  [errmsg, opt] = options (ARGS, struct ('RelTol', 1e-9));
  TOL = opt.RelTol;
  if (isempty (errmsg) && (! isfloat (TOL) || ! isreal (TOL)
                           || ! isscalar (TOL) || ! (TOL > 0)
                           || ! (TOL <= 1e-3)))
    errmsg = "RelTol must be a positive real scalar no larger than 1e-3.";
  elseif (isempty (errmsg))
    TOL = double (TOL);
  endif

endfunction

## Validate a Type filter, one name or a cell array of names from KINDS, and
## return it as a cell array.  Returns an error message body, empty when it
## is valid.
function [errmsg, T] = checktype (T, kinds, what)

  errmsg = '';
  if (isempty (T))
    return;
  endif
  if (ischar (T) && isrow (T))
    T = {T};
  endif
  if (! iscellstr (T) || ! all (ismember (T, kinds)))
    errmsg = sprintf ("Type must name a kind of %s: %s.", what, ...
                      strjoin (kinds, ', '));
  endif

endfunction

## Validate a Within box, which may be empty.  Returns an error message body,
## empty when it is valid.
function errmsg = checkbox (W)

  errmsg = '';
  if (! isempty (W) && (! isfloat (W) || ! isreal (W) || numel (W) != 6
                        || ! isvector (W) || any (isnan (W))
                        || any (W(1:3) > W(4:6))))
    errmsg = strcat ("Within must be a box [xmin, ymin, zmin, xmax,", ...
                     " ymax, zmax] with each minimum no greater than", ...
                     " its maximum.");
  endif

endfunction

## Validate indices into the N edges or faces of a shape; an empty set is
## allowed only when EMPTYOK is true.  Returns an error message body, empty
## when they are valid.
function errmsg = checkindex (I, N, name, what, emptyok)

  errmsg = '';
  if (! isnumeric (I) || ! isreal (I) || ! (isvector (I) || isempty (I))
      || (isempty (I) && ! emptyok) || any (I != fix (I)) || any (I < 1)
      || any (I > N))
    errmsg = sprintf ("%s must be a vector of %s indices of S.", name, what);
  endif

endfunction

## The rows of faces F of S checked for facefillet: as full rounds with three
## columns, and with two, as pairs of faces sharing edges, which come back in
## E.  Returns an error message body, empty when F is valid.
function [errmsg, E] = checkrounds (S, F)

  errmsg = '';
  E = zeros (1, 0);
  info = occt ('solid.Shape.facefillet', 'edges', S.Data);
  [seam, onfaces] = info{4:5};
  onfaces(seam) = {[]};
  info = occt ('solid.Shape.facefillet', 'faces', S.Data);
  [type, normal, ~, box] = info{:};
  ## A face leaning off the direction of a round, over the diagonal of its
  ## box, may stray from the round's cylinder by no more than Open CASCADE's
  ## precision, 1e-7 millimetres
  span = sqrt (sumsq (box(:,4:6) - box(:,1:3), 2));
  for i = 1:rows (F)
    f = F(i,:);
    if (numel (unique (f)) != numel (f))
      errmsg = sprintf ("the faces in row %d of F must be different.", i);
    elseif (columns (F) == 2)
      k = find (cellfun (@(o) all (ismember (f, o)), onfaces))';
      if (isempty (k))
        errmsg = sprintf ("the faces in row %d of F share no edge.", i);
      endif
      E = [E, k];
    elseif (! all (strcmp (type(f), 'plane')))
      errmsg = sprintf ("the faces in row %d of F must be flat.", i);
    else
      m = f(2);
      near = unique ([onfaces{cellfun (@(o) any (o == m), onfaces)}]);
      if (! all (ismember (f([1, 3]), near)))
        errmsg = sprintf (strcat ("the middle face in row %d of F must", ...
                                  " share an edge with each side."), i);
      else
        d = cross (normal(f(1),:), normal(m,:));
        d /= norm (d);
        ends = setdiff (near, f);
        lean = sqrt (sumsq (cross (normal(ends,:), ...
                                   repmat (d, numel (ends), 1), 2), 2));
        if (abs (dot (d, normal(f(3),:))) * span(m) > 1e-7)
          errmsg = sprintf (strcat ("the faces in row %d of F must all be", ...
                                    " parallel to one direction."), i);
        elseif (! all (strcmp (type(ends), 'plane'))
                || any (lean .* span(ends) > 1e-7))
          errmsg = sprintf (strcat ("the middle face in row %d of F must", ...
                                    " end on flat faces square to the", ...
                                    " edges it shares with its sides."), i);
        elseif (nnz (F == m) > 1)
          errmsg = sprintf (strcat ("the middle face in row %d of F", ...
                                    " appears in another row."), i);
        endif
      endif
    endif
    if (! isempty (errmsg))
      return;
    endif
  endfor
  E = unique (E);

endfunction

## The ends the option NAME of knurl treats, as rows [EDGE, SIZE]: a size X
## for every free end as EDGE 0, or {E, X} with a row for each end; WHAT names
## X and N is the number of edges of S.  Returns an error message body, empty
## when VAL is valid.
function [errmsg, E] = endedges (VAL, NAME, X, WHAT, N)

  errmsg = '';
  E = zeros (0, 2);
  if (iscell (VAL))
    ok = columns (VAL) == 2 && any (rows (VAL) == [1, 2]);
    for i = 1:rows (VAL)
      ok = ok && isscalar (VAL{i,1}) ...
           && isempty (checkindex (VAL{i,1}, N, 'E', 'edge', false)) ...
           && isfloat (VAL{i,2}) && isreal (VAL{i,2}) && isscalar (VAL{i,2}) ...
           && isfinite (VAL{i,2}) && VAL{i,2} > 0;
    endfor
    if (ok)
      E = double ([VAL{:,1}; VAL{:,2}]');
    endif
  else
    ok = (isfloat (VAL) && isreal (VAL) && isscalar (VAL) && isfinite (VAL)
          && VAL > 0);
    if (ok)
      E = [0, double(VAL)];
    endif
  endif
  if (! ok)
    errmsg = sprintf (strcat ("%s must be a positive %s %s for every free", ...
                              " end, or a cell array {E, %s} with a row", ...
                              " for each end, E an edge index of S."), ...
                      NAME, WHAT, X, X);
  endif

endfunction

## Rows of DIR parallel to V either way; a NaN row is not
function TF = parallel (DIR, V)

  v = double (V(:)') / norm (V);
  TF = sqrt (sum (cross (DIR, repmat (v, rows (DIR), 1), 2) .^ 2, 2)) <= 1e-9;

endfunction

## Rows of BOX lying inside the box W, to within 1e-6
function TF = inside (BOX, W)

  TF = all (BOX(:,1:3) >= W(1:3) - 1e-6, 2) ...
       & all (BOX(:,4:6) <= W(4:6) + 1e-6, 2);

endfunction

## The points and the direction a hole or a thread takes from P, an M-by-3
## matrix of points or a geom.UCS, and from the Direction and At given, each
## empty when not.  Returns an error message body, empty when they fit.
function [errmsg, P, DIR] = placement (P, DIR, AT)

  errmsg = '';
  if (isa (P, 'geom.UCS') && isscalar (P))
    if (! isempty (DIR))
      errmsg = strcat ("Direction cannot be given when P is a geom.UCS,", ...
                       " whose normal sets it.");
      return;
    endif
    if (isempty (AT))
      AT = [0, 0];
    elseif (! isfloat (AT) || ! isreal (AT) || ! ismatrix (AT)
            || columns (AT) != 2 || rows (AT) < 1 || ! all (isfinite (AT(:))))
      errmsg = "At must be an N-by-2 real matrix of finite values.";
      return;
    endif
    DIR = -P.Normal;
    P = toworld (P, double (AT));
  else
    if (! isfloat (P) || ! isreal (P) || ! ismatrix (P)
        || columns (P) != 3 || rows (P) < 1 || ! all (isfinite (P(:))))
      errmsg = strcat ("P must be an M-by-3 real matrix of finite values", ...
                       " or a geom.UCS.");
      return;
    endif
    if (! isempty (AT))
      errmsg = "At applies only when P is a geom.UCS.";
      return;
    endif
    if (isempty (DIR))
      DIR = [0, 0, -1];
    else
      errmsg = checkvec (DIR, 'Direction', true);
    endif
    P = double (P);
  endif

endfunction

## The tools T, made along the z axis, turned so that it runs along V
function T = aim (T, V)

  v = double (V(:)') / norm (V);
  k = cross ([0, 0, 1], v);
  if (norm (k) > 1e-12)
    T = cellfun (@(t) rotate (t, atan2d (norm (k), v(3)), k), T, ...
                 'UniformOutput', false);
  elseif (v(3) < 0)
    T = cellfun (@(t) rotate (t, 180, [1, 0, 0]), T, 'UniformOutput', false);
  endif

endfunction

## The shape S turned back from running along V to running along the z
## axis, as aim turned it
function S = unaim (S, V)

  v = double (V(:)') / norm (V);
  k = cross ([0, 0, 1], v);
  if (norm (k) > 1e-12)
    S = rotate (S, -atan2d (norm (k), v(3)), k);
  elseif (v(3) < 0)
    S = rotate (S, 180, [1, 0, 0]);
  endif

endfunction

## How far from the point P along V the axis last leaves the shape S, within
## REACH of it, measured along a thin core of the axis; -Inf where the axis
## meets no material
function z = leaves (S, P, V, REACH)

  z = -Inf;
  X = intersect (S, place (solid.cylinder (1e-3, REACH), V, P));
  if (! isempty (X))
    B = bbox (unaim (translate (X, -P), V));
    z = B(6);
  endif

endfunction

## The tool T, made along the z axis, turned to run along V from the point P
function T = place (T, V, P)

  T = aim ({T}, V);
  T = translate (T{1}, P);

endfunction

## The radii of the circles about the axis at P along V in the section of S
## a distance Z along it: BORES those that bound a hole of the section, RODS
## those that are the outline of the material round the axis, and WALLS for
## each bore the nearest the other loops of its piece come to the axis
function [bores, rods, walls] = axisrings (S, P, V, Z)

  bores = [];
  rods = [];
  walls = [];
  regions = section (S, geom.UCS (V, P + Z * V));
  for i = 1:numel (regions)
    loops = [{regions{i}.Outline}, regions{i}.Holes];
    r = cellfun (@ring, loops);
    for j = find (! isinf (r))
      if (j == 1)
        rods(end+1) = r(j);
      else
        bores(end+1) = r(j);
        others = loops([1:j-1, j+1:end]);
        walls(end+1) = min (cellfun (@nearest, others));
      endif
    endfor
  endfor

endfunction

## The nearest the closed path L comes to the origin of its plane, measured
## to the chords of its arcs and splines, which lie nearer than they do
function r = nearest (L)

  A = __sample__ (L);
  A = A(:,1:2);
  B = circshift (A, -1);
  U = B - A;
  t = min (max (-sum (A .* U, 2) ./ max (sum (U .^ 2, 2), eps), 0), 1);
  r = min (sqrt (sum ((A + t .* U) .^ 2, 2)));

endfunction

## The radius of the closed path L when it is a circle about the origin of
## its plane, made of arcs alone; Inf when it is not
function r = ring (L)

  r = Inf;
  M = L.Midpoints;
  if (any (! cellfun (@isempty, L.Splines)) || any (isnan (M(:,1))))
    return;
  endif
  Q = [L.Vertices; M];
  q = sqrt (sum (Q .^ 2, 2));
  if (max (q) - min (q) < 1e-6)
    r = mean (q);
  endif

endfunction

## The point P written for a message, as 10, 10, 20
function s = pointstr (P)

  s = strjoin (arrayfun (@(x) sprintf ('%g', x), P, 'UniformOutput', false), ...
               ', ');

endfunction

## The thread of the spec SPEC, the arguments of cutter, cut from S along V
## from the point P by the tool T, or, where Open CASCADE fails on it, by
## the tool with the shorter core, kept only when it removes what the groove
## alone and the core or sleeve alone remove; NAME names the thread
function S = cutthread (S, T, SPEC, V, P, NAME)

  N = numsolids (S);
  try
    C = subtract (S, T);
    if (numsolids (C) <= N)
      S = C;
      return;
    endif
  end_try_catch
  want = volume (intersect (S, place (cutter (SPEC{:}, 'groove'), V, P))) ...
         + volume (intersect (S, place (cutter (SPEC{:}, 'body'), V, P)));
  try
    C = subtract (S, place (cutter (SPEC{:}, 'short'), V, P));
    ok = (numsolids (C) <= N
          && abs (volume (S) - volume (C) - want) <= 1e-3 * want);
  catch
    ok = false;
  end_try_catch
  if (! ok)
    error (strcat ("solid.Shape.thread: %s at (%s): Open CASCADE could", ...
                   " not cut the thread; a slightly different DEPTH may", ...
                   " cut."), NAME, pointstr (P));
  endif
  S = C;

endfunction

## The cutter of a thread of pitch P, along the z axis from a pitch before
## the origin until the thread's full profile reaches L: the groove of the
## basic profile swept round the axis, fused with the cylinder of the bore
## or the sleeve outside the crest it is cut from, since Open CASCADE cuts
## the fused tool reliably where it can fail on the bare groove.  For an
## INTERNAL thread the bore has the radius INNER and the root, flat P/8
## wide, lies at OUTER; for an external one the root, flat P/4 wide, lies at
## INNER and the crest at OUTER.  KIND 'short' ends the cylinder or sleeve
## half a pitch sooner, 'groove' gives the groove alone clear of them, and
## 'body' the cylinder or sleeve alone.
function G = cutter (P, INNER, OUTER, INTERNAL, L, KIND = 'tool')

  c = tand (30);
  e = P / 20;
  len = L + P / (1 + strcmp (KIND, 'short'));
  if (INTERNAL)
    r = INNER - e;
    w = P / 8 + 2 * (OUTER - r) * c;
    Q = [r, -w/2; OUTER, -P/16; OUTER, P/16; r, w/2];
    B = solid.cylinder (INNER, len);
  else
    r = OUTER + e;
    w = P / 4 + 2 * (r - INNER) * c;
    Q = [INNER, -P/8; r, -w/2; r, w/2; INNER, P/8];
    B = subtract (solid.cylinder (OUTER + 2 * e, len), ...
                  solid.cylinder (OUTER, len));
  endif
  if (strcmp (KIND, 'body'))
    G = translate (B, [0, 0, -P]);
    return;
  endif
  ## The groove ends where its width at the bore or the crest reaches L
  w = P / 8 * (1 + ! INTERNAL) + 2 * (OUTER - INNER) * c;
  R = geom.Region (Q);
  R.UCS = geom.UCS ([0, -1, 0], [0, 0, 0]);
  G = solid.helix (R, P, (L + P - w / 2) / P);
  if (strcmp (KIND, 'groove'))
    ## The cylinder that bounds the groove runs a pitch clear of both its ends
    if (INTERNAL)
      G = subtract (G, translate (solid.cylinder (INNER, L + 3 * P), ...
                                  [0, 0, -P]));
    else
      G = intersect (G, translate (solid.cylinder (OUTER, L + 3 * P), ...
                                   [0, 0, -P]));
    endif
  else
    G = union (G, B);
  endif
  G = translate (G, [0, 0, -P]);

endfunction

## The tests for this classdef are in inst/tests/Shape.m-tst, which is
## where a classdef of this size keeps them; this block is here so the
## file is not reported as untested.
%!test  # see inst/tests/Shape.m-tst for the tests of this class
%! assert_equal (isempty (solid.Shape ()), true);
