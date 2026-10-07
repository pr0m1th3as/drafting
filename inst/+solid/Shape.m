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
  ## intersection of two solids that do not meet, returns it.  A shape is
  ## saved and loaded with @code{save} and @code{load} like any other value.
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
    ## a shape in Open CASCADE's binary format.  This is how the functions of
    ## the @code{solid} namespace return what Open CASCADE computed, and it is
    ## not for direct use: bytes that do not begin with that format's signature
    ## are refused.
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
    ## faces.  Empty shapes add nothing, and the union of a single shape is
    ## that shape.
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
        C.Colour = inherit (r{2}, S{:});
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
        C.Colour = inherit (r{2}, A, tools{:});
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
        C.Colour = inherit (r{2}, varargin{:});
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
      errmsg = solid.__checkpos__ (TOL, 'TOL');
      if (! isempty (errmsg))
        error ("solid.Shape.tessellate: %s", errmsg);
      endif

      if (isempty (this.Data))
        M = polymesh.Mesh ();
        return;
      endif
      c = occt ('solid.Shape.tessellate', 'tessellate', this.Data, ...
                double (TOL), 20);

      ## Points that are equal are one vertex, and a triangle two of whose
      ## corners become one is dropped
      [V, ~, j] = unique (c{1}, 'rows', 'stable');
      F = reshape (j(c{2}), size (c{2}));
      keep = F(:,1) != F(:,2) & F(:,2) != F(:,3) & F(:,3) != F(:,1);
      M = polymesh.Mesh (V, F(keep,:));

      ## Each triangle in the colour of its solid, grey where it has none
      if (! isempty (this.Colour))
        C = [NaN, NaN, NaN; this.Colour](c{3}(keep) + 1,:);
        C(isnan (C(:,1)),:) = repmat ([0.72, 0.74, 0.78], ...
                                      nnz (isnan (C(:,1))), 1);
        M.FaceColour = C;
      endif

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
    ## Drag with the left mouse button to rotate, the middle one to pan, and
    ## turn the wheel to zoom; @kbd{F} fits the part to the window and
    ## @kbd{0}, @kbd{1}, @kbd{2} and @kbd{3} turn it to the isometric, front,
    ## top and right views.  Closing a window ends its viewer, and the next
    ## @code{show} of that variable opens a new one.  Showing the empty shape
    ## opens a variable's window before there is anything to draw in it.
    ##
    ## @code{@var{V} = show (@var{S})} also returns the viewer.  Assigning to
    ## @code{@var{V}.Shape} redraws it at once, and
    ## @code{model.Viewer.pick} picks edges and faces with the mouse:
    ##
    ## @example
    ## @group
    ## part = solid.box (80, 40, 12);
    ## V = show (part);
    ## E = pick (V, 'edge');     # click the edges, then press Enter
    ## V.Shape = fillet (V.Shape, E, 3);
    ## @end group
    ## @end example
    ##
    ## Calling @code{show (@var{S})} is the same as assigning @var{S} to the
    ## @code{Shape} of the variable's viewer.  Nothing else redraws it:
    ## changing the variable that was shown does not, until it is shown again.
    ##
    ## The viewer is built with the package when Open CASCADE and X11 are
    ## found, and needs a display to run.  It runs on Linux.
    ##
    ## @seealso{model.Viewer, model.Viewer.pick, polymesh.Mesh.show}
    ## @end deftypefn
    function V = show (this)

      viewer = model.Viewer.__named__ (inputname (1, false));
      viewer.Shape = this;
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
    ## @item @file{.step}
    ## STEP (ISO 10303-21, application protocol 214), in millimetres.  The
    ## exact geometry is kept, so this is the file to send to a CAD program or
    ## to another manufacturer.  The part is named after the base name of
    ## @var{FILE}, and each solid carries its @code{solid.Shape.Colour}.
    ##
    ## @item @file{.stl}, @file{.obj}, @file{.ply}, @file{.3mf}
    ## A mesh of triangles in millimetres, the mesh
    ## @code{solid.Shape.tessellate} makes, written by
    ## @code{polymesh.Mesh.write}: binary STL, OBJ, binary PLY, or 3MF, the
    ## archive slicers take.  The facets approximate every curved surface;
    ## their vertices lie on it.  OBJ, PLY and 3MF carry the solids' colours on
    ## their triangles; STL has none.
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
            opt.Tolerance = val;
          otherwise
            error ("solid.Shape.write: unknown option '%s'.", name);
        endswitch
      endfor
      [folder, base, ext] = fileparts (FILE);
      isstep = strcmpi (ext, '.step');
      if (! isstep
          && ! any (strcmpi (ext, {'.stl', '.obj', '.ply', '.3mf'})))
        error (strcat ("solid.Shape.write: FILE must end in .step, .stl,", ...
                       " .obj, .ply or .3mf."));
      endif
      if (isstep && ! isempty (opt.Tolerance))
        error ("solid.Shape.write: Tolerance applies to meshes only.");
      endif
      if (isempty (opt.Tolerance))
        opt.Tolerance = 0.01;
      endif
      errmsg = solid.__checkpos__ (opt.Tolerance, 'Tolerance');
      if (! isempty (errmsg))
        error ("solid.Shape.write: %s", errmsg);
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
                  this.Colour);
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
      if (! isnumeric (ANGLE) || ! isreal (ANGLE) || ! isscalar (ANGLE)
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
      errmsg = solid.__checkpos__ (F, 'F');
      if (isempty (errmsg))
        errmsg = checkvec (P, 'P');
      endif
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
    ## A flat face is measured to a relative error of about 1e-9, whatever its
    ## edges.  A curved face is measured as Open CASCADE integrates it: exactly
    ## for a cylinder, a cone, a sphere or a torus, to about 1e-4 for a face
    ## swept from a spline.  The empty shape has area zero.
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
## 'numedges'                                                                 ##
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
## 'fillet'          'chamfer'         'shell'           'hole'               ##
## 'pocket'                                                                   ##
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
    ## raises an error, as does an edge that cannot be rounded at all.
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
    ## @seealso{solid.Shape.edges, solid.Shape.chamfer}
    ## @end deftypefn
    function this = fillet (this, E, R)

      ## Input validation
      if (nargin != 3)
        error ("solid.Shape.fillet: invalid number of input arguments.");
      endif
      errmsg = checkindex (E, numedges (this), 'E', 'edge', false);
      if (isempty (errmsg))
        errmsg = solid.__checkpos__ (R, 'R');
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.fillet: %s", errmsg);
      endif

      r = occt ('solid.Shape.fillet', 'fillet', this.Data, ...
                unique (double (E)), double (R));
      A = this;
      this.Data = r{1};
      this.Colour = inherit (r{2}, A);

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
      if (! isempty (A) && (! isnumeric (A) || ! isreal (A)
                            || ! isscalar (A) || ! (A > 0) || ! (A < 90)))
        error (strcat ("solid.Shape.chamfer: Angle must be in the range", ...
                       " (0, 90) degrees."));
      endif
      if (! isnumeric (D) || ! isreal (D) || ! isvector (D)
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
      this.Colour = inherit (r{2}, A);

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
      if (isempty (errmsg) && (! (islogical (opt.Outward)
                                  || isnumeric (opt.Outward))
                               || ! isscalar (opt.Outward)
                               || ! any (opt.Outward == [0, 1])))
        errmsg = "Outward must be a logical scalar.";
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
        if (! isempty (solid.__checkpos__ (C{k+1}, 'T')))
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
      if (isempty (errmsg))
        errmsg = solid.__checkpos__ (T, 'T');
      endif
      if (isempty (errmsg) && ! isempty (TF))
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
      this.Colour = inherit (r{2}, A);

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
    ## well.  All the holes are cut in one operation.
    ##
    ## @var{D} may instead name an ISO metric coarse thread, such as
    ## @qcode{'M6'} or @qcode{'M2.5'}, from M1 to M64: the hole is then drilled
    ## at the tapping size for that thread, its nominal diameter less its
    ## pitch, so @qcode{'M6'} drills 5 millimetres.  The thread itself is not
    ## modelled.
    ##
    ## Name/Value pairs shape the hole:
    ##
    ## @table @asis
    ## @item @qcode{'Direction'}
    ## The nonzero 3-element direction the holes run in from their points,
    ## @code{[0, 0, -1]} by default.
    ##
    ## @item @qcode{'Counterbore'}
    ## @code{[@var{CD}, @var{CDEPTH}]}: a flat-bottomed bore of diameter
    ## @var{CD}, wider than the hole, @var{CDEPTH} deep, shallower than the
    ## hole, for the head of a cap screw.
    ##
    ## @item @qcode{'Countersink'}
    ## @var{CD} or @code{[@var{CD}, @var{ANGLE}]}: a conical seat of diameter
    ## @var{CD} at the surface, wider than the hole, with an included angle of
    ## @var{ANGLE} degrees, 90 by default as for ISO countersunk screws.  It
    ## must be shallower than the hole.
    ##
    ## @item @qcode{'Tip'}
    ## The included angle in degrees of the cone a twist drill leaves at the
    ## bottom of a blind hole, 118 for a standard drill.  It is beyond
    ## @var{DEPTH}, which is measured to the full diameter as a drawing
    ## dimensions it.  By default a blind hole is flat-bottomed.
    ## @end table
    ##
    ## A counterbore and a countersink cannot both be given, and a tip applies
    ## only to a blind hole.  Drilling the empty shape leaves it empty.
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
    ## @seealso{solid.Shape.subtract, solid.cylinder}
    ## @end deftypefn
    function this = hole (this, P, D, DEPTH, varargin)

      ## Input validation
      if (nargin < 4)
        error ("solid.Shape.hole: invalid number of input arguments.");
      endif
      if (! isnumeric (P) || ! isreal (P) || ! ismatrix (P)
          || columns (P) != 3 || rows (P) < 1 || ! all (isfinite (P(:))))
        error (strcat ("solid.Shape.hole: P must be an M-by-3 real matrix", ...
                       " of finite values."));
      endif
      if (ischar (D))
        D = tapdrill (D);
      endif
      if (! isempty (solid.__checkpos__ (D, 'D')))
        error (strcat ("solid.Shape.hole: D must be a positive and finite", ...
                       " real scalar or an ISO metric coarse thread such", ...
                       " as 'M6'."));
      endif
      if (! isnumeric (DEPTH) || ! isreal (DEPTH) || ! isscalar (DEPTH)
          || ! (DEPTH > 0))
        error (strcat ("solid.Shape.hole: DEPTH must be positive, or Inf", ...
                       " for a through hole."));
      endif
      [errmsg, opt] = options (varargin, struct ('Direction', [0, 0, -1], ...
                                                 'Counterbore', [], ...
                                                 'Countersink', [], ...
                                                 'Tip', []));
      if (isempty (errmsg))
        errmsg = checkvec (opt.Direction, 'Direction', true);
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.hole: %s", errmsg);
      endif
      cb = opt.Counterbore;
      if (! isempty (cb) && (! isnumeric (cb) || ! isreal (cb)
                             || numel (cb) != 2 || ! all (isfinite (cb))
                             || ! (cb(1) > D) || ! (cb(2) > 0)
                             || ! (cb(2) < DEPTH)))
        error (strcat ("solid.Shape.hole: Counterbore must be", ...
                       " [CD, CDEPTH],", ...
                       " wider than D and shallower than DEPTH."));
      endif
      cs = opt.Countersink;
      if (! isempty (cs))
        if (isnumeric (cs) && isscalar (cs))
          cs(2) = 90;
        endif
        if (! isnumeric (cs) || ! isreal (cs) || numel (cs) != 2
            || ! all (isfinite (cs)) || ! (cs(1) > D) || ! (cs(2) > 0)
            || ! (cs(2) < 180)
            || ! ((cs(1) - D) / 2 / tand (cs(2) / 2) < DEPTH))
          error (strcat ("solid.Shape.hole: Countersink must be CD or", ...
                         " [CD, ANGLE], wider than D, with ANGLE in the", ...
                         " range (0, 180), and shallower than DEPTH."));
        endif
      endif
      if (! isempty (cb) && ! isempty (cs))
        error (strcat ("solid.Shape.hole: Counterbore and Countersink", ...
                       " cannot both be given."));
      endif
      tip = opt.Tip;
      if (! isempty (tip))
        if (! isnumeric (tip) || ! isreal (tip) || ! isscalar (tip)
            || ! (tip > 0) || ! (tip < 180))
          error (strcat ("solid.Shape.hole: Tip must be an angle in the", ...
                         " range (0, 180)."));
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
        T{end+1} = solid.cone (cs(1) / 2, D / 2, ...
                               (cs(1) - D) / 2 / tand (cs(2) / 2));
        T{end+1} = translate (solid.cylinder (cs(1) / 2, reach), ...
                              [0, 0, -reach]);
      endif
      if (! isempty (tip))
        T{end+1} = translate (solid.cone (D / 2, 0, D / 2 / tand (tip / 2)), ...
                              [0, 0, DEPTH]);
      endif

      ## Turned onto the direction and placed at every point
      v = double (opt.Direction(:)') / norm (opt.Direction);
      k = cross ([0, 0, 1], v);
      if (norm (k) > 1e-12)
        T = cellfun (@(t) rotate (t, atan2d (norm (k), v(3)), k), T, ...
                     'UniformOutput', false);
      elseif (v(3) < 0)
        T = cellfun (@(t) rotate (t, 180, [1, 0, 0]), T, ...
                     'UniformOutput', false);
      endif
      tools = cell (1, rows (P) * numel (T));
      for i = 1:rows (P)
        for j = 1:numel (T)
          tools{(i - 1) * numel (T) + j} = translate (T{j}, P(i,:));
        endfor
      endfor
      this = subtract (this, tools{:});

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
      if (! isa (R, 'geom.Region') || ! isscalar (R))
        error ("solid.Shape.pocket: R must be a geom.Region object.");
      endif
      if (! isnumeric (DEPTH) || ! isreal (DEPTH) || ! isscalar (DEPTH)
          || ! (DEPTH > 0))
        error (strcat ("solid.Shape.pocket: DEPTH must be positive, or Inf", ...
                       " for a pocket right through."));
      endif
      [errmsg, opt] = options (varargin, struct ('Taper', 0));
      if (isempty (errmsg) && (! isnumeric (opt.Taper)
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
            errmsg = solid.__checkpos__ (TOL, 'Tolerance');
            if (! isempty (errmsg))
              error ("solid.Shape.hull: %s", errmsg);
            endif
          otherwise
            error ("solid.Shape.hull: unknown option '%s'.", name);
        endswitch
      endfor
      isshape = cellfun (@(x) isa (x, 'solid.Shape') && isscalar (x), ...
                         varargin);
      ispoints = cellfun (@(x) isnumeric (x) && isreal (x) && ismatrix (x) ...
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
      if (! isnumeric (SZ) || ! isreal (SZ) || numel (SZ) != 3
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
      if (! isnumeric (D) || ! isreal (D) || ! ismatrix (D)
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
    return;
  elseif (all (apart(:)))
    r = occt (caller, 'compound', data{:});
  else
    r = occt (caller, 'fuse', data{:});
  endif
  C = solid.Shape (r{1});
  C.Colour = inherit (r{2}, repmat ({S}, 1, n){:});

endfunction

## The colours of a result's solids, each the colour of the first coloured
## solid it came from: L a row for each, the indices from 1 of the solids it
## came from, in increasing order and padded with 0, into the solids of the
## shapes SRC, those of each in turn
function C = inherit (L, varargin)

  C = [];
  if (all (cellfun (@(s) isempty (s.Colour), varargin)) || isempty (L))
    return;
  endif
  P = cellfun (@colours, varargin, 'UniformOutput', false);
  P = [NaN, NaN, NaN; vertcat(P{:})];
  has = reshape (! isnan (P(L + 1,1)), size (L));
  [found, k] = max (has, [], 2);
  first = L(sub2ind (size (L), (1:rows (L))', k));
  first(! found) = 0;
  C = P(first + 1,:);

endfunction

## S without colours, a tool whose material is taken away
function S = bare (S)

  S.Colour = [];

endfunction

## The colour of each solid of S, a row of NaN where it has none
function C = colours (S)

  C = S.Colour;
  if (isempty (C))
    C = NaN (numsolids (S), 3);
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
        if (! (islogical (val) || isnumeric (val)) || ! isscalar (val)
            || ! any (val == [0, 1]))
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
  if (! isnumeric (V) || ! isreal (V) || numel (V) != 3
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
        opt.(known{strcmpi (name, known)}) = val;
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
  if (isempty (errmsg) && (! isnumeric (TOL) || ! isreal (TOL)
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
  if (! isempty (W) && (! isnumeric (W) || ! isreal (W) || numel (W) != 6
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

## The tapping drill for an ISO metric coarse thread, its nominal diameter
## less its pitch (ISO 261); NaN for a name that is not one
function D = tapdrill (name)

  d = [1, 1.2, 1.6, 2, 2.5, 3, 4, 5, 6, 8, 10, 12, 14, 16, 20, 24, 30, 36, ...
       42, 48, 56, 64];
  p = [0.25, 0.25, 0.35, 0.4, 0.45, 0.5, 0.7, 0.8, 1, 1.25, 1.5, 1.75, 2, ...
       2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6];
  D = NaN;
  if (isrow (name) && numel (name) > 1 && name(1) == 'M')
    k = find (d == str2double (name(2:end)));
    if (! isempty (k))
      D = d(k) - p(k);
    endif
  endif

endfunction

%!test
%! S = solid.Shape ();
%! assert_equal (isempty (S), true);
%! assert_equal (volume (S), 0);
%! assert_equal (area (S), 0);
%! assert_equal (centroid (S), []);
%! assert_equal (bbox (S), []);
%! assert_equal (isvalid (S), true);
%! assert_equal (numsolids (S), 0);
%! assert_equal (numfaces (S), 0);
%! assert_equal (numedges (S), 0);

%!test  # transforming the empty shape leaves it empty
%! S = solid.Shape ();
%! assert_equal (isempty (translate (S, [1, 2, 3])), true);
%! assert_equal (isempty (rotate (S, 90, [0, 0, 1])), true);
%! assert_equal (isempty (mirror (S, [1, 0, 0])), true);
%! assert_equal (isempty (scale (S, 2)), true);

%!test  # the bytes survive a round trip
%! A = solid.box (10, 20, 30);
%! B = solid.Shape (A.Data);
%! assert_equal (volume (B), volume (A));

%!test  # two overlapping blocks
%! A = solid.box (10, 10, 10);
%! C = union (A, translate (A, [5, 0, 0]));
%! assert_equal (volume (C), 1500, 1e-9);
%! assert_equal (numsolids (C), 1);
%! assert_equal (numfaces (C), 6);
%! assert_equal (isvalid (C), true);

%!test  # three blocks in one operation
%! A = solid.box (10, 10, 10);
%! C = union (A, translate (A, [20, 0, 0]), translate (A, [5, 5, 0]));
%! assert_equal (volume (C), 2750, 1e-9);
%! assert_equal (numsolids (C), 2);

%!test  # empty shapes add nothing
%! A = solid.box (10, 10, 10);
%! assert_equal (volume (union (A, solid.Shape ())), 1000, 1e-9);
%! assert_equal (volume (union (solid.Shape (), A)), 1000, 1e-9);
%! assert_equal (volume (union (A)), 1000, 1e-9);
%! assert_equal (isempty (union (solid.Shape (), solid.Shape ())), true);

%!test  # a through hole
%! C = subtract (solid.box (80, 40, 12), ...
%!               translate (solid.cylinder (4, 12), [20, 20, 0]));
%! assert_equal (volume (C), 38400 - 192 * pi, 1e-9);
%! assert_equal (numfaces (C), 7);
%! assert_equal (isvalid (C), true);

%!test  # several holes in one operation
%! h = solid.cylinder (3, 10);
%! C = subtract (solid.box (100, 20, 10), translate (h, [10, 10, 0]), ...
%!               translate (h, [50, 10, 0]), translate (h, [90, 10, 0]));
%! assert_equal (volume (C), 20000 - 3 * 90 * pi, 1e-9);
%! assert_equal (numfaces (C), 9);

%!test  # cutting a bar in two
%! C = subtract (solid.box (100, 10, 10), ...
%!               translate (solid.box (2, 10, 10), [49, 0, 0]));
%! assert_equal (numsolids (C), 2);
%! assert_equal (volume (C), 9800, 1e-9);

%!test  # subtracting empty shapes or nothing
%! A = solid.box (10, 10, 10);
%! assert_equal (volume (subtract (A, solid.Shape ())), 1000, 1e-9);
%! assert_equal (volume (subtract (A)), 1000, 1e-9);
%! assert_equal (isempty (subtract (solid.Shape (), A)), true);

%!test  # two overlapping blocks
%! A = solid.box (10, 10, 10);
%! C = intersect (A, translate (A, [5, 5, 0]));
%! assert_equal (volume (C), 250, 1e-9);
%! assert_equal (bbox (C), [5, 5, 0, 10, 10, 10], 1e-9);

%!test  # common to all three, not to the first
%! A = solid.box (10, 10, 10);
%! C = intersect (A, translate (A, [5, 0, 0]), translate (A, [0, 5, 0]));
%! assert_equal (volume (C), 250, 1e-9);
%! assert_equal (bbox (C), [5, 5, 0, 10, 10, 10], 1e-9);

%!test  # shapes that do not all meet
%! A = solid.box (10, 10, 10);
%! assert_equal (isempty (intersect (A, translate (A, [20, 0, 0]))), true);
%! assert_equal (isempty (intersect (A, translate (A, [5, 0, 0]), ...
%!                                   translate (A, [-8, 0, 0]))), true);
%! assert_equal (isempty (intersect (A, solid.Shape ())), true);
%! assert_equal (volume (intersect (A)), 1000, 1e-9);

%!test  # the operands are left unchanged
%! A = solid.box (10, 10, 10);
%! B = translate (A, [5, 0, 0]);
%! C = subtract (A, B);
%! assert_equal (volume (A), 1000, 1e-9);
%! assert_equal (bbox (B), [5, 0, 0, 15, 10, 10], 1e-9);

%!test
%! S = translate (solid.box (10, 20, 30), [1, -2, 3]);
%! assert_equal (bbox (S), [1, -2, 3, 11, 18, 33], 1e-9);

%!test  # a quarter turn about z
%! S = rotate (solid.box (10, 20, 30), 90, [0, 0, 1]);
%! assert_equal (bbox (S), [-20, 0, 0, 0, 10, 30], 1e-9);

%!test  # about an axis through a point
%! S = rotate (solid.box (10, 20, 30), 180, [0, 0, 1], [10, 0, 0]);
%! assert_equal (bbox (S), [10, -20, 0, 20, 0, 30], 1e-9);

%!test  # a reflection keeps volume and validity
%! S = mirror (solid.box (10, 20, 30), [1, 0, 0]);
%! assert_equal (bbox (S), [-10, 0, 0, 0, 20, 30], 1e-9);
%! assert_equal (volume (S), 6000, 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # in a plane through a point
%! S = mirror (solid.box (10, 20, 30), [0, 0, 1], [0, 0, 40]);
%! assert_equal (bbox (S), [0, 0, 50, 10, 20, 80], 1e-9);

%!test
%! S = scale (solid.box (10, 20, 30), 2);
%! assert_equal (volume (S), 48000, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 20, 40, 60], 1e-9);

%!test  # about a point that stays put
%! S = scale (solid.box (10, 10, 10), 0.5, [10, 10, 10]);
%! assert_equal (bbox (S), [5, 5, 5, 10, 10, 10], 1e-9);

%!test
%! S = solid.box (10, 20, 30);
%! assert_equal (area (S), 2200, 1e-9);
%! assert_equal (centroid (S), [5, 10, 15], 1e-9);
%! [B, L] = bbox (S);
%! assert_equal (B, [0, 0, 0, 10, 20, 30], 1e-9);
%! assert_equal (L, [10, 20, 30], 1e-9);

%!test  # spline faces: volume, centroid, area
%! H = geom.Spline ([20, 15; 35, 12; 40, 25; 28, 35; 18, 28], 'Closed', true);
%! R = geom.Region ([0, 0; 80, 0; 80, 50; 0, 50], {H});
%! A = 4000 + __area__ (R.Holes{1});
%! S = solid.extrude (R, 6);
%! assert_equal (volume (S), 6 * A, -1e-9);
%! assert_equal (centroid (S)(3), 3, 1e-9);
%! assert_equal (area (S), 2 * A + 6 * (260 + length (H)), -1e-5);
%!test  # a looser RelTol holds on a spline face
%! C = resize (solid.cylinder (5, 10), [20, 0, 0], 'Uniform', false);
%! assert_equal (volume (C, 'RelTol', 1e-6), 500 * pi, -1e-6);
%!test  # RelTol on the centroid, its name in any case
%! assert_equal (centroid (solid.box (10, 20, 30), 'reltol', 1e-3), ...
%!               [5, 10, 15], 1e-9);
%!test  # the empty shape takes RelTol too
%! assert_equal (volume (solid.Shape (), 'RelTol', 1e-6), 0);
%!error<solid.Shape.volume: Name/Value arguments must come in pairs.> ...
%! volume (solid.box (1, 1, 1), 'RelTol')
%!error<solid.Shape.volume: option names must be character vectors.> ...
%! volume (solid.box (1, 1, 1), 1, 1e-6)
%!error<solid.Shape.volume: unknown option 'AbsTol'.> ...
%! volume (solid.box (1, 1, 1), 'AbsTol', 1e-6)
%!error<solid.Shape.volume: RelTol must be a positive real scalar no larger than 1e-3.> ...
%! volume (solid.box (1, 1, 1), 'RelTol', 0)
%!error<solid.Shape.volume: RelTol must be a positive real scalar no larger than 1e-3.> ...
%! volume (solid.box (1, 1, 1), 'RelTol', 2e-3)
%!error<solid.Shape.volume: RelTol must be a positive real scalar no larger than 1e-3.> ...
%! volume (solid.box (1, 1, 1), 'RelTol', [1e-6, 1e-6])
%!error<solid.Shape.volume: RelTol must be a positive real scalar no larger than 1e-3.> ...
%! volume (solid.box (1, 1, 1), 'RelTol', {1e-6})
%!error<solid.Shape.volume: RelTol must be a positive real scalar no larger than 1e-3.> ...
%! volume (solid.Shape (), 'RelTol', NaN)
%!error<solid.Shape.centroid: Name/Value arguments must come in pairs.> ...
%! centroid (solid.box (1, 1, 1), 'RelTol')
%!error<solid.Shape.centroid: option names must be character vectors.> ...
%! centroid (solid.box (1, 1, 1), 1, 1e-6)
%!error<solid.Shape.centroid: unknown option 'AbsTol'.> ...
%! centroid (solid.box (1, 1, 1), 'AbsTol', 1e-6)
%!error<solid.Shape.centroid: RelTol must be a positive real scalar no larger than 1e-3.> ...
%! centroid (solid.box (1, 1, 1), 'RelTol', 1i)

%!test  # the box of a cylinder is tight
%! assert_equal (bbox (solid.cylinder (4, 12)), [-4, -4, 0, 4, 4, 12], 1e-9);

%!test
%! S = solid.box (10, 20, 30);
%! assert_equal (numsolids (S), 1);
%! assert_equal (numfaces (S), 6);
%! assert_equal (numedges (S), 12);

%!test  # a seam edge closes the curved face
%! assert_equal (numedges (solid.cylinder (4, 12)), 3);

%!test  # every edge but the seam
%! assert_equal (edges (solid.cylinder (4, 12)), [1, 3]);
%! assert_equal (numel (edges (solid.box (10, 20, 30))), 12);

%!test  # the poles of a sphere are no edges
%! assert_equal (edges (solid.sphere (5)), zeros (1, 0));

%!test  # by direction, either way
%! B = solid.box (10, 20, 30);
%! assert_equal (numel (edges (B, 'Direction', [0, 0, 1])), 4);
%! assert_equal (edges (B, 'Direction', [0, 0, -2]), ...
%!               edges (B, 'Direction', [0, 0, 1]));

%!test  # by type and by the axis of a circle
%! C = solid.cylinder (4, 12);
%! assert_equal (edges (C, 'Type', 'circle'), [1, 3]);
%! assert_equal (edges (C, 'Type', {'line', 'bspline'}), zeros (1, 0));
%! assert_equal (edges (C, 'Direction', [0, 0, 1]), [1, 3]);

%!test  # the four edges round the top
%! B = solid.box (10, 20, 30);
%! assert_equal (numel (edges (B, 'Within', [0, 0, 30, 10, 20, 30])), 4);
%! assert_equal (numel (edges (B, 'Within', [0, 0, 30, 10, 20, 30], ...
%!                             'Direction', [1, 0, 0])), 2);

%!test  # faces by outward normal
%! B = solid.box (10, 20, 30);
%! F = faces (B, 'Normal', [0, 0, 1]);
%! assert_equal (numel (F), 1);
%! assert_equal (numel (faces (B)), 6);
%! assert_equal (numel (faces (B, 'Type', 'plane')), 6);
%! assert_equal (numel (faces (B, 'Normal', [1, 1, 0])), 0);

%!test  # faces by type, axis and box
%! C = solid.cylinder (4, 12);
%! assert_equal (numel (faces (C, 'Type', 'cylinder')), 1);
%! assert_equal (faces (C, 'Axis', [0, 0, -1]), faces (C, 'Type', 'cylinder'));
%! assert_equal (numel (faces (C, 'Within', [-4, -4, 12, 4, 4, 12])), 1);
%! S = solid.revolve (geom.Region ([0, 0; 10, 0; 10, 30; 6, 30; 6, 49; ...
%!                                  5, 50; 0, 50]));
%! assert_equal (numel (faces (S, 'Type', {'cylinder', 'cone'})), 3);

%!test  # four parallel edges rounded
%! B = solid.box (10, 20, 30);
%! S = fillet (B, edges (B, 'Direction', [0, 0, 1]), 2);
%! assert_equal (volume (S), 6000 - 4 * (4 - pi) * 30, 1e-9);
%! assert_equal (numfaces (S), 10);
%! assert_equal (isvalid (S), true);

%!test  # a rounded end of a cylinder
%! C = solid.cylinder (4, 12);
%! S = fillet (C, edges (C, 'Within', [-4, -4, 12, 4, 4, 12]), 1);
%! ## The ring removed: the area outside a quarter circle in a unit square,
%! ## carried round at the distance of its centroid from the axis
%! a = 1 - pi / 4;
%! d = 4 - (10 - 3 * pi) / (3 * (4 - pi));
%! assert_equal (volume (S), 192 * pi - a * 2 * pi * d, 1e-9);
%! assert_equal (bbox (S), [-4, -4, 0, 4, 4, 12], 1e-6);
%! assert_equal (numfaces (S), 4);
%! assert_equal (isvalid (S), true);

%!test  # four parallel edges bevelled
%! B = solid.box (10, 20, 30);
%! S = chamfer (B, edges (B, 'Direction', [0, 0, 1]), 2);
%! assert_equal (volume (S), 6000 - 4 * 2 * 30, 1e-9);
%! assert_equal (numfaces (S), 10);
%! assert_equal (isvalid (S), true);

%!test  # the edges round a face
%! B = solid.box (10, 20, 30);
%! F = faces (B, 'Normal', [0, 0, 1]);
%! assert_equal (numel (edges (B, 'Face', F)), 4);
%! top = edges (B, 'Within', [0, 0, 30, 10, 20, 30]);
%! assert_equal (edges (B, 'Face', F), top);
%! S = fillet (B, edges (B, 'Face', F), 2);
%! assert_equal (isvalid (S), true);
%! assert_equal (numfaces (S), 10);

%!test  # two distances, D1 along the face given
%! B = solid.box (10, 20, 30);
%! F = faces (B, 'Normal', [0, 0, 1]);
%! E = edges (B, 'Face', F, 'Direction', [1, 0, 0]);
%! S = chamfer (B, E, [2, 5], F);
%! assert_equal (volume (S), 6000 - 2 * (2 * 5 / 2) * 10, 1e-9);
%! ## 2 along the top face and 5 down the side: a normal along [0, -5, 2]
%! assert_equal (numel (faces (S, 'Normal', [0, -5, 2])), 1);
%! assert_equal (numel (faces (S, 'Normal', [0, -2, 5])), 0);
%! assert_equal (isvalid (S), true);

%!test  # a distance along the face and an angle
%! B = solid.box (10, 20, 30);
%! F = faces (B, 'Normal', [0, 0, 1]);
%! E = edges (B, 'Face', F, 'Direction', [1, 0, 0]);
%! S = chamfer (B, E, 2, F, 'Angle', 30);
%! assert_equal (volume (S), 6000 - 2 * (2 * 2 * tand (30) / 2) * 10, 1e-9);
%! ## The chamfer face meets the top at 30 degrees
%! assert_equal (numel (faces (S, 'Normal', [0, -sind(30), cosd(30)])), 1);
%! assert_equal (isvalid (S), true);

%!test  # an edge not on the face is refused
%! B = solid.box (10, 20, 30);
%! F = faces (B, 'Normal', [0, 0, 1]);
%! E = edges (B, 'Within', [0, 0, 0, 10, 20, 0]);
%! msg = '';
%! try
%!   chamfer (B, E, [2, 5], F);
%! catch err
%!   msg = err.message;
%! end_try_catch
%! assert_equal (msg, strcat ("solid.Shape.chamfer: every edge in E must", ...
%!                           " bound the face F."));

%!test  # an open box
%! B = solid.box (10, 20, 30);
%! S = shell (B, faces (B, 'Normal', [0, 0, 1]), 1);
%! assert_equal (volume (S), 6000 - 8 * 18 * 29, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 30], 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a closed shell round a cavity
%! B = solid.box (10, 20, 30);
%! assert_equal (volume (shell (B, [], 1)), 6000 - 8 * 18 * 28, 1e-9);

%!test  # walls grown outwards, open and closed
%! B = solid.box (10, 20, 30);
%! S = shell (B, faces (B, 'Normal', [0, 0, 1]), 1, 'Outward', true);
%! assert_equal (volume (S), 12 * 22 * 31 - 6000, 1e-9);
%! assert_equal (bbox (S), [-1, -1, -1, 11, 21, 30], 1e-9);
%! S = shell (B, [], 1, 'Outward', true);
%! assert_equal (volume (S), 12 * 22 * 32 - 6000, 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a floor of its own thickness
%! B = solid.box (10, 20, 30);
%! top = faces (B, 'Normal', [0, 0, 1]);
%! bot = faces (B, 'Normal', [0, 0, -1]);
%! S = shell (B, top, 1, 'Thickness', {bot, 4});
%! assert_equal (volume (S), 6000 - 8 * 18 * 26, 1e-9);
%! S = shell (B, top, 1, 'Outward', true, 'Thickness', {bot, 4});
%! assert_equal (volume (S), 12 * 22 * 34 - 6000, 1e-9);
%! assert_equal (bbox (S), [-1, -1, -4, 11, 21, 30], 1e-9);
%! S = shell (B, [], 1, 'Thickness', {bot, 3, top, 2});
%! assert_equal (volume (S), 6000 - 8 * 18 * 25, 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a cup
%! C = solid.cylinder (4, 12);
%! S = shell (C, faces (C, 'Normal', [0, 0, 1]), 1);
%! assert_equal (volume (S), (192 - 99) * pi, 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # through holes, several at once
%! S = hole (solid.box (80, 40, 12), [20, 20, 12; 60, 20, 12], 8, Inf);
%! assert_equal (volume (S), 38400 - 2 * 16 * pi * 12, 1e-9);
%! assert_equal (numfaces (S), 8);
%! assert_equal (isvalid (S), true);

%!test  # a blind hole, flat and with a drill tip
%! B = solid.box (80, 40, 12);
%! S = hole (B, [20, 20, 12], 8, 5);
%! assert_equal (volume (S), 38400 - 16 * pi * 5, 1e-9);
%! S = hole (B, [20, 20, 12], 8, 5, 'Tip', 118);
%! assert_equal (volume (S), 38400 - 16 * pi * (5 + 4 / tand (59) / 3), 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # into a sloping face, clean all round
%! R = geom.Region ([0, 0; 80, 0; 80, 20; 0, 40]);
%! R.UCS = geom.UCS ([0, -1, 0], [0, 40, 0]);
%! B = solid.extrude (R, 40);
%! S = hole (B, [20, 20, 35], 8, Inf);
%! assert_equal (volume (B) - volume (S), 16 * pi * 35, -1e-8);
%! T = hole (B, [20, 20, 35], 8, 10);
%! assert_equal (volume (B) - volume (T), 16 * pi * 10, -1e-8);
%! assert_equal (isvalid (T), true);

%!test  # counterbored
%! S = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf, ...
%!           'Counterbore', [14, 4]);
%! assert_equal (volume (S), 38400 - pi * (49 * 4 + 16 * 8), 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # countersunk at 90 degrees
%! S = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf, ...
%!           'Countersink', 16);
%! assert_equal (volume (S), 38400 - pi * (4 / 3 * (64 + 32 + 16) + 16 * 8), ...
%!               1e-9);
%! assert_equal (isvalid (S), true);

%!test  # tapping size for M6, drilled from the side
%! S = hole (solid.box (80, 40, 12), [0, 20, 6], 'M6', Inf, ...
%!           'Direction', [1, 0, 0]);
%! assert_equal (volume (S), 38400 - 6.25 * pi * 80, 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # straight up from underneath
%! S = hole (solid.box (80, 40, 12), [20, 20, 0], 'M2.5', 3, ...
%!           'Direction', [0, 0, 1]);
%! assert_equal (volume (S), 38400 - 1.025 ^ 2 * pi * 3, 1e-9);

%!test  # drilling the empty shape
%! assert_equal (isempty (hole (solid.Shape (), [0, 0, 0], 5, Inf)), true);

%!test  # a rectangle 4 deep in the top of a plate
%! R = geom.Region ([30, 15; 50, 15; 50, 25; 30, 25]);
%! R.UCS = geom.UCS ([0, 0, 1], [0, 0, 12]);
%! S = pocket (solid.box (80, 40, 12), R, 4);
%! assert_equal (volume (S), 38400 - 20 * 10 * 4, 1e-9);
%! assert_equal (numfaces (S), 11);
%! assert_equal (isvalid (S), true);

%!test  # right through, and an island left standing
%! R = geom.Region ([30, 15; 50, 15; 50, 25; 30, 25], ...
%!                  {[38, 18; 42, 18; 42, 22; 38, 22]});
%! R.UCS = geom.UCS ([0, 0, 1], [0, 0, 12]);
%! S = pocket (solid.box (80, 40, 12), R, Inf);
%! assert_equal (volume (S), 38400 - (200 - 16) * 12, 1e-9);
%! assert_equal (numsolids (S), 2);
%! T = pocket (solid.box (80, 40, 12), R, 4);
%! assert_equal (volume (T), 38400 - (200 - 16) * 4, 1e-9);
%! assert_equal (numsolids (T), 1);

%!test  # tapered walls, a prismatoid
%! R = geom.Region ([30, 15; 50, 15; 50, 25; 30, 25]);
%! R.UCS = geom.UCS ([0, 0, 1], [0, 0, 12]);
%! S = pocket (solid.box (80, 40, 12), R, 4, 'Taper', 10);
%! d = 4 * tand (10);
%! A2 = (20 - 2 * d) * (10 - 2 * d);
%! Am = (20 - d) * (10 - d);
%! assert_equal (volume (S), 38400 - 4 / 6 * (200 + A2 + 4 * Am), 1e-9);
%! assert_equal (isvalid (S), true);

%!test  # a smooth pocket, a closed spline
%! R = geom.Region (geom.Spline ([20, 10; 50, 8; 60, 25; 35, 32; 18, 25], ...
%!                               'Closed', true));
%! R.UCS = geom.UCS ([0, 0, 1], [0, 0, 12]);
%! S = pocket (solid.box (80, 40, 12), R, 4);
%! assert_equal (volume (S), 38400 - 4 * __area__ (R.Outline), -1e-9);
%! assert_equal (isvalid (S), true);


%!testif ; ! isempty (getenv ('DISPLAY'))
%! ## show: each variable has a viewer of its own, titled with its name, and
%! ## shapes without a name share one
%! old = getappdata (0, 'drafting_model_show');
%! VA = model.Viewer ('Hidden', true);
%! VB = model.Viewer ('Hidden', true);
%! VU = model.Viewer ('Hidden', true);
%! setappdata (0, 'drafting_model_show', struct ('v_part_a', VA.Id, ...
%!                                               'v_part_b', VB.Id, ...
%!                                               'unnamed', VU.Id));
%! unwind_protect
%!   part_a = solid.box (10, 20, 30);
%!   part_b = solid.cylinder (4, 12);
%!   W = show (part_a);
%!   assert_equal (W.Id, VA.Id);
%!   show (part_b);
%!   show (solid.sphere (2));
%!   assert_equal (volume (VA.Shape), 6000, 1e-9);
%!   assert_equal (volume (VB.Shape), 192 * pi, 1e-9);
%!   assert_equal (volume (VU.Shape), 32 / 3 * pi, 1e-9);
%!   assert_equal (VA.__title__ (), 'part_a (drafting)');
%!   assert_equal (VB.__title__ (), 'part_b (drafting)');
%!   assert_equal (VU.Name, 'S');
%!   assert_equal (VU.__title__ (), 'drafting');
%!   ## Showing a variable again redraws its own window
%!   part_a = solid.box (10, 20, 40);
%!   show (part_a);
%!   assert_equal (volume (VA.Shape), 8000, 1e-9);
%!   assert_equal (volume (VB.Shape), 192 * pi, 1e-9);
%! unwind_protect_cleanup
%!   close (VA);
%!   close (VB);
%!   close (VU);
%!   setappdata (0, 'drafting_model_show', old);
%! end_unwind_protect
%!test  # tessellate: a box is twelve triangles
%! M = tessellate (solid.box (10, 20, 30));
%! assert_equal (numvertices (M), 8);
%! assert_equal (numfaces (M), 12);
%! assert_equal (isclosed (M), true);
%! assert_equal (volume (M), 6000, -1e-12);

%!test  # tessellate: corners on the surface
%! M = tessellate (solid.cylinder (4, 12), 0.05);
%! r = hypot (M.Vertices(:,1), M.Vertices(:,2));
%! z = M.Vertices(:,3);
%! assert_equal (all (abs (r - 4) < 1e-9 | ((z == 0 | z == 12) & r < 4)), ...
%!               true);

%!test  # tessellate: side facets within TOL
%! M = tessellate (solid.cylinder (4, 12), 0.05);
%! z = M.Vertices(:,3);
%! F = M.Faces(any (z(M.Faces) != z(M.Faces(:,1)), 2),:);
%! E = [F(:,[1, 2]); F(:,[2, 3]); F(:,[3, 1])];
%! m = (M.Vertices(E(:,1),:) + M.Vertices(E(:,2),:)) / 2;
%! assert_equal (min (hypot (m(:,1), m(:,2))) >= 4 - 0.05 - 1e-9, true);

%!test  # tessellate: a finer TOL, more triangles
%! S = solid.sphere (20);
%! assert_equal (numfaces (tessellate (S, 0.5)) < ...
%!               numfaces (tessellate (S, 0.05)), true);

%!test  # tessellate: a mirrored part turned out
%! M = tessellate (mirror (solid.cone (5, 2, 8), [1, 0, 0]));
%! V = M.Vertices;
%! F = M.Faces;
%! assert_equal (isclosed (M), true);
%! assert_equal (dot (V(F(:,1),:), cross (V(F(:,2),:), V(F(:,3),:), 2), ...
%!                    2)' * ones (rows (F), 1) > 0, true);

%!test  # tessellate: each triangle its colour
%! B = solid.box (1, 1, 1);
%! U = union (B, translate (B, [5, 0, 0]));
%! U.Colour = [1, 0, 0; NaN, NaN, NaN];
%! M = tessellate (U);
%! assert_equal (sortrows (unique (M.FaceColour, 'rows')), ...
%!               [0.72, 0.74, 0.78; 1, 0, 0]);
%! assert_equal (nnz (M.FaceColour(:,1) == 1), 12);

%!test  # tessellate: the empty shape gives the empty mesh
%! assert_equal (isempty (tessellate (solid.Shape ())), true);

## The vertices of a binary STL file, three rows per facet
%!function V = stlvertices (f)
%!  fid = fopen (f, 'r', 'ieee-le');
%!  fread (fid, 80, 'uint8');
%!  n = fread (fid, 1, 'uint32');
%!  B = fread (fid, [50, n], 'uint8=>uint8');
%!  fclose (fid);
%!  V = double (reshape (typecast (reshape (B(13:48,:), [], 1), 'single'), ...
%!                       3, [])');
%!endfunction

%!test  # STEP keeps the exact surfaces
%! f = [tempname(), '.step'];
%! unwind_protect
%!   write (solid.cylinder (4, 12), f);
%!   txt = fileread (f);
%!   assert_equal (isempty (strfind (txt, 'CYLINDRICAL_SURFACE')), false);
%!   assert_equal (isempty (strfind (txt, "'GNU Octave drafting package'")), ...
%!                 false);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!test  # STEP carries a solid's colour
%! f = [tempname(), '.step'];
%! S = solid.box (1, 2, 3);
%! S.Colour = [0.2, 0.4, 0.6];
%! unwind_protect
%!   write (S, f);
%!   assert_equal (isempty (strfind (fileread (f), 'COLOUR_RGB')), false);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!test  # the product is named after the file
%! f = [tempname(), '.step'];
%! [~, base] = fileparts (f);
%! unwind_protect
%!   write (solid.box (1, 2, 3), f);
%!   txt = fileread (f);
%!   assert_equal (isempty (strfind (txt, ["PRODUCT('", base])), false);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!test  # STL: a box is twelve triangles
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   write (solid.box (10, 20, 30), f);
%!   V = stlvertices (f);
%!   assert_equal (rows (V), 36);
%!   assert_equal (min (V), [0, 0, 0]);
%!   assert_equal (max (V), [10, 20, 30]);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!test  # facets stay within the tolerance
%! f = [tempname(), '.stl'];
%! unwind_protect
%!   write (solid.cylinder (4, 12), f, 'Tolerance', 0.05);
%!   V = stlvertices (f);
%!   assert_equal (max (abs (hypot (V(:,1), V(:,2)) - 4)) < 1e-5, true);
%!   ## Gap at the midpoint of every edge of a facet on the curved side; the
%!   ## flat ends are left out, their facets having no curve to follow
%!   A = V(1:3:end,:);
%!   B = V(2:3:end,:);
%!   C = V(3:3:end,:);
%!   side = ! (A(:,3) == B(:,3) & B(:,3) == C(:,3));
%!   M = ([A(side,1:2); B(side,1:2); C(side,1:2)] ...
%!        + [B(side,1:2); C(side,1:2); A(side,1:2)]) / 2;
%!   gap = 4 - hypot (M(:,1), M(:,2));
%!   assert_equal (max (gap) <= 0.05 + 1e-5, true);
%!   assert_equal (max (gap) > 0.01, true);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!test  # a finer tolerance gives more facets
%! f1 = [tempname(), '.stl'];
%! f2 = [tempname(), '.stl'];
%! unwind_protect
%!   write (solid.sphere (20), f1, 'Tolerance', 0.5);
%!   write (solid.sphere (20), f2, 'Tolerance', 0.01);
%!   assert_equal (rows (stlvertices (f2)) > rows (stlvertices (f1)), true);
%! unwind_protect_cleanup
%!   [~] = unlink (f1);
%!   [~] = unlink (f2);
%! end_unwind_protect

%!test  # OBJ: the mesh of the solid, closed
%! f = [tempname(), '.obj'];
%! unwind_protect
%!   write (solid.box (10, 20, 30), f);
%!   M = polymesh.read (f);
%!   assert_equal (isclosed (M), true);
%!   assert_equal (volume (M), 6000, -1e-12);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!test  # PLY: the mesh of the solid, closed
%! f = [tempname(), '.ply'];
%! unwind_protect
%!   write (solid.box (10, 20, 30), f);
%!   M = polymesh.read (f);
%!   assert_equal (isclosed (M), true);
%!   assert_equal (volume (M), 6000, -1e-12);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!test  # PLY: the triangles in the solid's colour
%! f = [tempname(), '.ply'];
%! S = solid.box (10, 20, 30);
%! S.Colour = [0.2, 0.4, 0.6];
%! unwind_protect
%!   write (S, f);
%!   M = polymesh.read (f);
%!   assert_equal (M.FaceColour, repmat ([0.2, 0.4, 0.6], 12, 1), 1e-9);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%! end_unwind_protect

%!testif ; ! isempty (file_in_path (getenv ('PATH'), 'unzip')) || ! isempty (file_in_path (getenv ('PATH'), 'unzip.exe'))
%! ## 3MF: the solid's mesh in its colour
%! f = [tempname(), '.3mf'];
%! d = tempname ();
%! S = solid.box (10, 20, 30);
%! S.Colour = [0.2, 0.4, 0.6];
%! unwind_protect
%!   write (S, f);
%!   unzip (f, d);
%!   t = fileread (fullfile (d, '3D', '3dmodel.model'));
%!   assert_equal (numel (strfind (t, '<triangle ')), 12);
%!   assert_equal (! isempty (strfind (t, 'displaycolor="#336699"')), true);
%! unwind_protect_cleanup
%!   [~] = unlink (f);
%!   confirm_recursive_rmdir (false, 'local');
%!   rmdir (d, 's');
%! end_unwind_protect

%!error<solid.Shape.write: invalid number of input arguments.> ...
%! write (solid.Shape ())
%!error<solid.Shape.write: FILE must be a non-empty character vector.> ...
%! write (solid.Shape (), '')
%!error<solid.Shape.write: Name/Value arguments must come in pairs.> ...
%! write (solid.Shape (), 'a.stl', 'Tolerance')
%!error<solid.Shape.write: unknown option 'Angle'.> ...
%! write (solid.Shape (), 'a.stl', 'Angle', 5)
%!error<solid.Shape.write: option names must be character vectors.> ...
%! write (solid.Shape (), 'a.stl', 1, 5)
%!test  # option names ignore case
%! f1 = [tempname(), '.stl'];
%! f2 = [tempname(), '.stl'];
%! unwind_protect
%!   write (solid.sphere (5), f1, 'tolerance', 0.1);
%!   write (solid.sphere (5), f2, 'Tolerance', 0.1);
%!   assert_equal (fileread (f1), fileread (f2));
%! unwind_protect_cleanup
%!   [~] = unlink (f1);
%!   [~] = unlink (f2);
%! end_unwind_protect
%!error<solid.Shape.write: FILE must end in .step, .stl, .obj, .ply or .3mf.> ...
%! write (solid.Shape (), 'a.dxf')
%!error<solid.Shape.write: FILE must end in .step, .stl, .obj, .ply or .3mf.> ...
%! write (solid.Shape (), 'a.stp')
%!error<solid.Shape.write: Tolerance applies to meshes only.> ...
%! write (solid.Shape (), 'a.step', 'Tolerance', 0.1)
%!error<solid.Shape.write: Tolerance must be a positive and finite real scalar.> ...
%! write (solid.Shape (), 'a.stl', 'Tolerance', 0)
%!error<solid.Shape.write: folder 'no_such_folder_9f2c' does not exist.> ...
%! write (solid.Shape (), fullfile ('no_such_folder_9f2c', 'a.stl'))
%!error<solid.Shape.write: S is empty, so there is nothing to write.> ...
%! write (solid.Shape (), 'a.stl')

%!test  # Colour: one row colours every solid
%! B = solid.box (1, 1, 1);
%! U = union (B, translate (B, [5, 0, 0]));
%! U.Colour = [1, 0.5, 0];
%! assert_equal (U.Colour, [1, 0.5, 0; 1, 0.5, 0]);

%!test  # Colour: a NaN row leaves a solid bare
%! B = solid.box (1, 1, 1);
%! U = union (B, translate (B, [5, 0, 0]));
%! U.Colour = [NaN, NaN, NaN; 0, 0, 1];
%! assert_equal (U.Colour, [NaN, NaN, NaN; 0, 0, 1]);
%! U.Colour = [NaN, NaN, NaN];
%! assert_equal (U.Colour, []);

%!test  # Colour: overlapping, the first operand's
%! A = solid.box (10, 10, 10);
%! A.Colour = [1, 0, 0];
%! B = translate (solid.box (10, 10, 10), [5, 5, 5]);
%! B.Colour = [0, 0, 1];
%! assert_equal (union (A, B).Colour, [1, 0, 0]);
%! assert_equal (union (B, A).Colour, [0, 0, 1]);

%!test  # Colour: parts apart keep their own
%! A = solid.box (10, 10, 10);
%! A.Colour = [1, 0, 0];
%! B = translate (solid.box (10, 10, 10), [30, 0, 0]);
%! B.Colour = [0, 0, 1];
%! assert_equal (sortrows (union (A, B).Colour), [0, 0, 1; 1, 0, 0]);

%!test  # Colour: the first coloured operand's
%! A = solid.box (10, 10, 10);
%! B = translate (solid.box (10, 10, 10), [5, 5, 5]);
%! B.Colour = [0, 0, 1];
%! assert_equal (union (A, B).Colour, [0, 0, 1]);

%!test  # Colour: a tool's never colours the part
%! A = solid.box (10, 10, 10);
%! B = translate (solid.box (10, 10, 10), [5, 5, 5]);
%! B.Colour = [0, 0, 1];
%! assert_equal (subtract (A, B).Colour, []);

%!test  # Colour: subtract keeps the part's
%! A = solid.box (10, 10, 10);
%! A.Colour = [1, 0, 0];
%! B = translate (solid.box (10, 10, 10), [5, 5, 5]);
%! B.Colour = [0, 0, 1];
%! assert_equal (subtract (A, B).Colour, [1, 0, 0]);

%!test  # Colour: intersect, the first operand's
%! A = solid.box (10, 10, 10);
%! A.Colour = [1, 0, 0];
%! B = translate (solid.box (10, 10, 10), [5, 5, 5]);
%! B.Colour = [0, 0, 1];
%! assert_equal (intersect (B, A).Colour, [0, 0, 1]);

%!test  # Colour: a fillet keeps it
%! A = solid.box (10, 10, 10);
%! A.Colour = [0, 1, 0];
%! F = fillet (A, edges (A, 'Direction', [0, 0, 1]), 1);
%! assert_equal (F.Colour, [0, 1, 0]);

%!test  # Colour: a shell keeps it
%! A = solid.box (10, 10, 10);
%! A.Colour = [0, 1, 0];
%! H = shell (A, faces (A, 'Normal', [0, 0, 1]), 1);
%! assert_equal (H.Colour, [0, 1, 0]);

%!test  # Colour: copies keep it
%! A = solid.box (10, 10, 10);
%! A.Colour = [0, 1, 0];
%! assert_equal (rectarray (A, [3, 1, 1], [20, 0, 0]).Colour, ...
%!               repmat ([0, 1, 0], 3, 1));

%!test  # Colour: transforms keep it
%! S = solid.box (1, 2, 3);
%! S.Colour = [0.2, 0.4, 0.6];
%! assert_equal (translate (S, [1, 2, 3]).Colour, [0.2, 0.4, 0.6]);
%! assert_equal (rotate (S, 30, [0, 0, 1]).Colour, [0.2, 0.4, 0.6]);
%! assert_equal (mirror (S, [1, 0, 0]).Colour, [0.2, 0.4, 0.6]);
%! assert_equal (scale (S, 2).Colour, [0.2, 0.4, 0.6]);

%!error<solid.Shape.pocket: Taper cannot be applied to a region with splines.> ...
%! R = geom.Region (geom.Spline ([20, 10; 50, 8; 35, 32], 'Closed', true));
%! pocket (solid.box (80, 40, 12), R, 4, 'Taper', 5);

%!test  # in a sloping face, clean all round
%! W = geom.Region ([0, 0; 80, 0; 80, 20; 0, 40]);
%! W.UCS = geom.UCS ([0, -1, 0], [0, 40, 0]);
%! B = solid.extrude (W, 40);
%! U = geom.UCS ([20, 0, 80], [40, 20, 30], [80, 20, 20]);
%! R = geom.Region ([-10, -5; 10, -5; 10, 5; -10, 5]);
%! R.UCS = U;
%! S = pocket (B, R, 3);
%! assert_equal (volume (B) - volume (S), 200 * 3, -1e-9);
%! assert_equal (isvalid (S), true);

%!test  # pocketing the empty shape
%! R = geom.Region ([0, 0; 1, 0; 1, 1]);
%! assert_equal (isempty (pocket (solid.Shape (), R, 1)), true);

%!error<solid.Shape: DATA must be a uint8 row vector.> solid.Shape ('abc')
%!error<solid.Shape: DATA must be a uint8 row vector.> ...
%! solid.Shape (uint8 ([1; 2]))
%!error<solid.Shape: DATA is not an Open CASCADE shape.> ...
%! solid.Shape (uint8 ([1, 2, 3]))
%!error<solid.Shape: DATA is not an Open CASCADE shape.> ...
%! solid.Shape (uint8 (sprintf ("\nOpen CASCADE Topology X, (c)")))
%!error<solid.Shape.union: every operand must be a solid.Shape object.> ...
%! union (solid.Shape (), 1)
%!error<solid.Shape.union: every operand must be a solid.Shape object.> ...
%! union (1, solid.Shape ())
%!error<solid.Shape.union: every operand must be a solid.Shape object.> ...
%! union (solid.Shape (), [solid.Shape(), solid.Shape()])
%!error<solid.Shape.subtract: every operand must be a solid.Shape object.> ...
%! subtract (solid.Shape (), solid.Shape (), 'a')
%!error<solid.Shape.intersect: every operand must be a solid.Shape object.> ...
%! intersect (solid.Shape (), true)
%!error<solid.Shape.translate: invalid number of input arguments.> ...
%! translate (solid.Shape ())
%!error<solid.Shape.translate: V must be a real 3-element vector of finite values.> ...
%! translate (solid.Shape (), [1, 2])
%!error<solid.Shape.translate: V must be a real 3-element vector of finite values.> ...
%! translate (solid.Shape (), [1, NaN, 2])
%!error<solid.Shape.translate: V must be a real 3-element vector of finite values.> ...
%! translate (solid.Shape (), [1, 2, 3i])
%!error<solid.Shape.translate: V must be a real 3-element vector of finite values.> ...
%! translate (solid.Shape (), 'abc')
%!error<solid.Shape.rotate: invalid number of input arguments.> ...
%! rotate (solid.Shape (), 90)
%!error<solid.Shape.rotate: ANGLE must be a finite real scalar.> ...
%! rotate (solid.Shape (), Inf, [0, 0, 1])
%!error<solid.Shape.rotate: ANGLE must be a finite real scalar.> ...
%! rotate (solid.Shape (), [90, 180], [0, 0, 1])
%!error<solid.Shape.rotate: AXIS must be a real 3-element vector of finite values.> ...
%! rotate (solid.Shape (), 90, [0, 1])
%!error<solid.Shape.rotate: AXIS must not be the zero vector.> ...
%! rotate (solid.Shape (), 90, [0, 0, 0])
%!error<solid.Shape.rotate: P must be a real 3-element vector of finite values.> ...
%! rotate (solid.Shape (), 90, [0, 0, 1], [0, 0])
%!error<solid.Shape.mirror: invalid number of input arguments.> ...
%! mirror (solid.Shape ())
%!error<solid.Shape.mirror: N must be a real 3-element vector of finite values.> ...
%! mirror (solid.Shape (), [1, 0])
%!error<solid.Shape.mirror: N must not be the zero vector.> ...
%! mirror (solid.Shape (), [0, 0, 0])
%!error<solid.Shape.mirror: P must be a real 3-element vector of finite values.> ...
%! mirror (solid.Shape (), [1, 0, 0], [Inf, 0, 0])
%!error<solid.Shape.scale: invalid number of input arguments.> ...
%! scale (solid.Shape ())
%!error<solid.Shape.scale: F must be a positive and finite real scalar.> ...
%! scale (solid.Shape (), 0)
%!error<solid.Shape.scale: F must be a positive and finite real scalar.> ...
%! scale (solid.Shape (), -2)
%!error<solid.Shape.scale: P must be a real 3-element vector of finite values.> ...
%! scale (solid.Shape (), 2, [1, 2])
%!error<solid.Shape.edges: Name/Value arguments must come in pairs.> ...
%! edges (solid.Shape (), 'Type')
%!error<solid.Shape.edges: unknown option 'Normal'.> ...
%! edges (solid.Shape (), 'Normal', [0, 0, 1])
%!error<solid.Shape.edges: option names must be character vectors.> ...
%! edges (solid.Shape (), 1, [0, 0, 1])
%!test  # option names ignore case
%! S = solid.cylinder (1, 2);
%! assert_equal (edges (S, 'type', 'circle'), edges (S, 'Type', 'circle'));
%!error<solid.Shape.edges: Type must name a kind of curve: line, circle, ellipse, bspline, other.> ...
%! edges (solid.Shape (), 'Type', 'arc')
%!error<solid.Shape.edges: Type must name a kind of curve: line, circle, ellipse, bspline, other.> ...
%! edges (solid.Shape (), 'Type', {'line', 1})
%!error<solid.Shape.edges: Direction must not be the zero vector.> ...
%! edges (solid.Shape (), 'Direction', [0, 0, 0])
%!error<solid.Shape.edges: Within must be a box \[xmin, ymin, zmin, xmax, ymax, zmax\] with each minimum no greater than its maximum.> ...
%! edges (solid.Shape (), 'Within', [0, 0, 0, 1, 1])
%!error<solid.Shape.edges: Within must be a box \[xmin, ymin, zmin, xmax, ymax, zmax\] with each minimum no greater than its maximum.> ...
%! edges (solid.Shape (), 'Within', [0, 0, 2, 1, 1, 1])
%!error<solid.Shape.faces: unknown option 'Direction'.> ...
%! faces (solid.Shape (), 'Direction', [0, 0, 1])
%!error<solid.Shape.faces: option names must be character vectors.> ...
%! faces (solid.Shape (), 1, [0, 0, 1])
%!error<solid.Shape.faces: Type must name a kind of surface: plane, cylinder, cone, sphere, torus, revolution, extrusion, bspline, other.> ...
%! faces (solid.Shape (), 'Type', 'line')
%!error<solid.Shape.faces: Normal must be a real 3-element vector of finite values.> ...
%! faces (solid.Shape (), 'Normal', [0, 1])
%!error<solid.Shape.faces: Axis must not be the zero vector.> ...
%! faces (solid.Shape (), 'Axis', [0, 0, 0])
%!error<solid.Shape.faces: Within must be a box \[xmin, ymin, zmin, xmax, ymax, zmax\] with each minimum no greater than its maximum.> ...
%! faces (solid.Shape (), 'Within', 'abc')
%!error<solid.Shape.fillet: invalid number of input arguments.> ...
%! fillet (solid.Shape (), 1)
%!error<solid.Shape.fillet: E must be a vector of edge indices of S.> ...
%! fillet (solid.Shape (), 1, 2)
%!error<solid.Shape.fillet: E must be a vector of edge indices of S.> ...
%! fillet (solid.Shape (), [], 2)
%!error<solid.Shape.chamfer: invalid number of input arguments.> ...
%! chamfer (solid.Shape ())
%!error<solid.Shape.chamfer: E must be a vector of edge indices of S.> ...
%! chamfer (solid.Shape (), 0.5, 2)
%!error<solid.Shape.chamfer: D must be one positive finite distance, or two with a face F.> ...
%! chamfer (solid.Shape (), 1, [1, 2, 3])
%!error<solid.Shape.chamfer: D must be one positive finite distance, or two with a face F.> ...
%! chamfer (solid.Shape (), 1, 0)
%!error<solid.Shape.chamfer: two distances need the face F of D1.> ...
%! chamfer (solid.Shape (), 1, [1, 2])
%!error<solid.Shape.chamfer: a face F goes with two distances, or with an angle.> ...
%! chamfer (solid.Shape (), 1, 1, 1)
%!error<solid.Shape.chamfer: Angle must be in the range \(0, 90\) degrees.> ...
%! chamfer (solid.Shape (), 1, 1, 1, 'Angle', 90)
%!error<solid.Shape.chamfer: an angle goes with one distance D.> ...
%! chamfer (solid.Shape (), 1, [1, 2], 1, 'Angle', 30)
%!error<solid.Shape.chamfer: an angle needs the face F of D.> ...
%! chamfer (solid.Shape (), 1, 1, 'Angle', 30)
%!error<solid.Shape.chamfer: unknown option 'Slope'.> ...
%! chamfer (solid.Shape (), 1, 1, 1, 'Slope', 30)
%!error<solid.Shape.chamfer: option names must be character vectors.> ...
%! chamfer (solid.Shape (), 1, 1, 1, 1, 30)
%!error<solid.Shape.chamfer: F must be a single face index of S.> ...
%! chamfer (solid.Shape (), 1, [1, 2], [1, 2])
%!error<solid.Shape.edges: Face must be a vector of face indices of S.> ...
%! edges (solid.Shape (), 'Face', 1)
%!error<solid.Shape.shell: invalid number of input arguments.> ...
%! shell (solid.Shape (), [])
%!error<solid.Shape.shell: Name/Value arguments must come in pairs.> ...
%! shell (solid.Shape (), [], 1, 'Outward')
%!error<solid.Shape.shell: unknown option 'Inward'.> ...
%! shell (solid.Shape (), [], 1, 'Inward', true)
%!error<solid.Shape.shell: option names must be character vectors.> ...
%! shell (solid.Shape (), [], 1, 1, true)
%!error<solid.Shape.shell: Outward must be a logical scalar.> ...
%! shell (solid.Shape (), [], 1, 'Outward', 2)
%!error<solid.Shape.shell: Thickness must be a cell array of faces and thicknesses, in pairs.> ...
%! shell (solid.Shape (), [], 1, 'Thickness', {1})
%!error<solid.Shape.shell: Thickness must be a cell array of faces and thicknesses, in pairs.> ...
%! shell (solid.Shape (), [], 1, 'Thickness', [1, 2])
%!error<solid.Shape.shell: Thickness must give each set of faces as a vector of face indices.> ...
%! shell (solid.Shape (), [], 1, 'Thickness', {1.5, 2})
%!error<solid.Shape.shell: Thickness must give each thickness as a positive and finite real scalar.> ...
%! shell (solid.Shape (), [], 1, 'Thickness', {1, 0})
%!error<solid.Shape.shell: Thickness gives a face two thicknesses.> ...
%! shell (solid.Shape (), [], 1, 'Thickness', {[1, 2], 3, 2, 4})
%!error<solid.Shape.shell: a face cannot be both opened and given a thickness.> ...
%! shell (solid.Shape (), [1, 2], 1, 'Thickness', {2, 4})
%!error<solid.Shape.shell: Thickness must be a vector of face indices of S.>
%! B = solid.Shape ();
%! shell (B, [], 1, 'Thickness', {1, 4})
%!error<solid.Shape.shell: F must be a vector of face indices of S.> ...
%! shell (solid.Shape (), 1, 1)
%!error<solid.Shape.shell: T must be a positive and finite real scalar.> ...
%! shell (solid.Shape (), [], 0)
%!error<solid.Shape.shell: S is empty, so there is nothing to hollow.> ...
%! shell (solid.Shape (), [], 1)
%!error<solid.Shape.hole: invalid number of input arguments.> ...
%! hole (solid.Shape (), [0, 0, 0], 5)
%!error<solid.Shape.hole: P must be an M-by-3 real matrix of finite values.> ...
%! hole (solid.Shape (), [0, 0], 5, 1)
%!error<solid.Shape.hole: P must be an M-by-3 real matrix of finite values.> ...
%! hole (solid.Shape (), [0, 0, NaN], 5, 1)
%!error<solid.Shape.hole: D must be a positive and finite real scalar or an ISO metric coarse thread such as 'M6'.> ...
%! hole (solid.Shape (), [0, 0, 0], -5, 1)
%!error<solid.Shape.hole: D must be a positive and finite real scalar or an ISO metric coarse thread such as 'M6'.> ...
%! hole (solid.Shape (), [0, 0, 0], 'M7', 1)
%!error<solid.Shape.hole: D must be a positive and finite real scalar or an ISO metric coarse thread such as 'M6'.> ...
%! hole (solid.Shape (), [0, 0, 0], 'm6', 1)
%!error<solid.Shape.hole: DEPTH must be positive, or Inf for a through hole.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 0)
%!error<solid.Shape.hole: DEPTH must be positive, or Inf for a through hole.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, NaN)
%!error<solid.Shape.hole: unknown option 'Depth'.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 1, 'Depth', 2)
%!error<solid.Shape.hole: option names must be character vectors.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 1, 1, 2)
%!error<solid.Shape.hole: Direction must not be the zero vector.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 1, 'Direction', [0, 0, 0])
%!error<solid.Shape.hole: Counterbore must be \[CD, CDEPTH\], wider than D and shallower than DEPTH.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 10, 'Counterbore', [5, 2])
%!error<solid.Shape.hole: Counterbore must be \[CD, CDEPTH\], wider than D and shallower than DEPTH.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 10, 'Counterbore', [8, 10])
%!error<solid.Shape.hole: Countersink must be CD or \[CD, ANGLE\], wider than D, with ANGLE in the range \(0, 180\), and shallower than DEPTH.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 10, 'Countersink', 4)
%!error<solid.Shape.hole: Countersink must be CD or \[CD, ANGLE\], wider than D, with ANGLE in the range \(0, 180\), and shallower than DEPTH.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 10, 'Countersink', [10, 180])
%!error<solid.Shape.hole: Countersink must be CD or \[CD, ANGLE\], wider than D, with ANGLE in the range \(0, 180\), and shallower than DEPTH.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 2, 'Countersink', 10)
%!error<solid.Shape.hole: Counterbore and Countersink cannot both be given.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 10, 'Counterbore', [8, 2], ...
%!       'Countersink', 8)
%!error<solid.Shape.hole: Tip must be an angle in the range \(0, 180\).> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 10, 'Tip', 0)
%!error<solid.Shape.hole: Tip applies to blind holes only.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, Inf, 'Tip', 118)
%!error<solid.Shape.pocket: invalid number of input arguments.> ...
%! pocket (solid.Shape (), geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<solid.Shape.pocket: R must be a geom.Region object.> ...
%! pocket (solid.Shape (), [0, 0; 1, 0; 1, 1], 1)
%!error<solid.Shape.pocket: DEPTH must be positive, or Inf for a pocket right through.> ...
%! pocket (solid.Shape (), geom.Region ([0, 0; 1, 0; 1, 1]), 0)
%!error<solid.Shape.pocket: DEPTH must be positive, or Inf for a pocket right through.> ...
%! pocket (solid.Shape (), geom.Region ([0, 0; 1, 0; 1, 1]), NaN)
%!error<solid.Shape.pocket: Name/Value arguments must come in pairs.> ...
%! pocket (solid.Shape (), geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Taper')
%!error<solid.Shape.pocket: unknown option 'Draft'.> ...
%! pocket (solid.Shape (), geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Draft', 2)
%!error<solid.Shape.pocket: option names must be character vectors.> ...
%! pocket (solid.Shape (), geom.Region ([0, 0; 1, 0; 1, 1]), 1, 1, 2)
%!error<solid.Shape.pocket: Taper must be an angle in the range \(-90, 90\) degrees.> ...
%! pocket (solid.Shape (), geom.Region ([0, 0; 1, 0; 1, 1]), 1, 'Taper', 90)

%!test  # a box cut through the middle
%! U = geom.UCS ([0, 0, 1], [0, 0, 15]);
%! R = section (solid.box (10, 20, 30), U);
%! assert_equal (numel (R), 1);
%! assert_equal (R{1}.UCS, U);
%! assert_equal (__area__ (R{1}.Outline), 200, 1e-9);

%!test  # a face in the plane is the cut
%! R = section (solid.box (10, 20, 30), geom.UCS ([0, 0, 1], [0, 0, 0]));
%! assert_equal (__area__ (R{1}.Outline), 200, 1e-9);
%! R = section (solid.box (10, 20, 30), geom.UCS ([0, 0, 1], [0, 0, 30]));
%! assert_equal (numel (R), 1);

%!test  # a face in the plane and a cut, one piece
%! S = solid.extrude (geom.Region ([0, 0; 30, 0; 30, 5; 5, 5; 5, 20; ...
%!                                  0, 20]), 10);
%! R = section (S, geom.UCS ([0, 1, 0], [0, 5, 0]));
%! assert_equal (numel (R), 1);
%! assert_equal (abs (__area__ (R{1}.Outline)), 300, 1e-9);

%!test  # missed, or touched along an edge
%! S = solid.box (10, 20, 30);
%! assert_equal (section (S, geom.UCS ([0, 0, 1], [0, 0, 31])), cell (1, 0));
%! assert_equal (section (S, geom.UCS ([1, 1, 0], [0, 0, 0])), cell (1, 0));
%! assert_equal (section (solid.Shape (), geom.UCS ()), cell (1, 0));

%!test  # a bore: two half arcs, made again
%! S = solid.extrude (geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                                 {[20, 20, 1; 40, 20, 1]}), 8);
%! R = section (S, geom.UCS ([0, 0, 1], [0, 0, 4]));
%! H = R{1}.Holes{1};
%! assert_equal (rows (H.Vertices), 2);
%! assert_equal (all (! isnan (H.Midpoints(:,1))), true);
%! assert_equal (volume (solid.extrude (R{1}, 2)), 2 * (2400 - 100 * pi), ...
%!               -1e-9);

%!test  # a cylinder cut at a slant, an ellipse
%! R = section (solid.cylinder (5, 40), ...
%!              geom.UCS ([0, sind(30), cosd(30)], [0, 0, 20]));
%! SP = R{1}.Outline.Splines{1};
%! assert_equal (SP.Closed, true);
%! assert_equal (any (SP.Weights != 1), true);
%! assert_equal (__area__ (R{1}.Outline), 25 * pi / cosd (30), -1e-12);

%!test  # separate pieces, largest first
%! S = solid.extrude (geom.Region ([0, 0; 30, 0; 30, 20; 25, 20; 25, 5; ...
%!                                  10, 5; 10, 20; 0, 20]), 10);
%! R = section (S, geom.UCS ([0, 1, 0], [0, 10, 0]));
%! assert_equal (numel (R), 2);
%! assert_equal (abs ([__area__(R{1}.Outline), __area__(R{2}.Outline)]), ...
%!               [100, 50], 1e-9);

%!test  # a torus, across and through its axis
%! S = solid.torus (10, 2);
%! R = section (S, geom.UCS ([0, 0, 1], [0, 0, 0]));
%! assert_equal (__area__ (R{1}.Outline) + __area__ (R{1}.Holes{1}), ...
%!               80 * pi, 1e-9);
%! assert_equal (numel (section (S, geom.UCS ([0, 1, 0], [0, 0, 0]))), 2);

%!test  # a spline outline made again from its cut
%! H = geom.Spline ([20, 15; 35, 12; 40, 25; 28, 35; 18, 28], 'Closed', true);
%! Q = geom.Region ([0, 0; 80, 0; 80, 50; 0, 50], {H});
%! R = section (solid.extrude (Q, 6), geom.UCS ([0, 0, 1], [0, 0, 3]));
%! assert_equal (__area__ (R{1}.Holes{1}), __area__ (Q.Holes{1}), -1e-9);

%!error<solid.Shape.section: invalid number of input arguments.> ...
%! section (solid.Shape ())
%!error<solid.Shape.section: U must be a geom.UCS object.> ...
%! section (solid.Shape (), [0, 0, 1])

%!test  # a bore seen along its axis is a hole
%! S = subtract (solid.box (80, 40, 12), ...
%!               translate (solid.cylinder (4, 12), [20, 20, 0]));
%! R = projection (S, geom.UCS ());
%! assert_equal (numel (R), 1);
%! assert_equal (abs (__area__ (R{1}.Outline)), 3200, 1e-9);
%! assert_equal (numel (R{1}.Holes), 1);
%! assert_equal (abs (__area__ (R{1}.Holes{1})), 16 * pi, 1e-9);

%!test  # a bore seen from the side is not there
%! S = subtract (solid.box (80, 40, 12), ...
%!               translate (solid.cylinder (4, 12), [20, 20, 0]));
%! R = projection (S, geom.UCS ([0, -1, 0], [0, 0, 0]));
%! assert_equal (numel (R{1}.Holes), 0);
%! assert_equal (abs (__area__ (R{1}.Outline)), 960, 1e-9);

%!test  # a circle seen edge on is one straight side
%! R = projection (solid.cylinder (5, 10), geom.UCS ([0, -1, 0], [0, 0, 0]));
%! assert_equal (sortrows (R{1}.Outline.Vertices(:,1:2)), ...
%!               [-5, 0; -5, 10; 5, 0; 5, 10], 1e-9);

%!test  # pieces along one line are one side
%! S = union (solid.cylinder (10, 5), ...
%!            translate (solid.cylinder (5, 10), [0, 0, 5]));
%! R = projection (S, geom.UCS ([0, -1, 0], [0, 0, 0]));
%! assert_equal (rows (R{1}.Outline.Vertices), 8);
%! assert_equal (abs (__area__ (R{1}.Outline)), 200, 1e-9);

%!test  # the xy plane by default
%! R = projection (solid.box (10, 20, 30));
%! assert_equal (R{1}.UCS, geom.UCS ());
%! assert_equal (abs (__area__ (R{1}.Outline)), 200, 1e-9);

%!test  # the regions lie in the plane of U
%! U = geom.UCS ([0, 0, 1], [0, 0, -5]);
%! R = projection (solid.box (10, 20, 30), U);
%! assert_equal (R{1}.UCS, U);

%!test  # a sphere's outline is its great circle
%! R = projection (solid.sphere (5), geom.UCS ([1, 2, 3], [0, 0, 0]));
%! assert_equal (abs (__area__ (R{1}.Outline)), 25 * pi, 1e-9);

%!test  # a cylinder at a slant, ellipses and lines
%! S = rotate (solid.cylinder (5, 20), 30, [1, 0, 0]);
%! R = projection (S);
%! assert_equal (abs (__area__ (R{1}.Outline)), ...
%!               25 * pi * cosd (30) + 200 * sind (30), 1e-9);

%!test  # a torus seen edge on
%! R = projection (solid.torus (20, 5), geom.UCS ([0, 1, 0], [0, 0, 0]));
%! assert_equal (abs (__area__ (R{1}.Outline)), 400 + 25 * pi, 1e-4);

%!test  # a coil seen along its axis is a ring
%! S = solid.helix (geom.Region ([10, -1; 12, -1; 12, 1; 10, 1]), 5, 3);
%! R = projection (S, geom.UCS ([0, 1, 0], [0, 0, 0]));
%! assert_equal (abs (__area__ (R{1}.Outline)) ...
%!               - abs (__area__ (R{1}.Holes{1})), 44 * pi, 1e-3);

%!test  # a piece in a hole is a piece of its own
%! S = union (subtract (solid.cylinder (10, 5), solid.cylinder (6, 5)), ...
%!            translate (solid.cylinder (3, 5), [0, 0, 10]));
%! R = projection (S);
%! assert_equal (numel (R), 2);
%! assert_equal (abs (__area__ (R{2}.Outline)), 9 * pi, 1e-9);

%!test  # what overlaps is covered once
%! S = union (solid.box (10, 10, 2), ...
%!            translate (solid.box (30, 4, 2), [0, 3, 8]));
%! R = projection (S);
%! assert_equal (abs (__area__ (R{1}.Outline)), 180, 1e-9);

%!test  # solids apart are pieces apart
%! B = solid.box (5, 5, 5);
%! assert_equal (numel (projection (union (B, translate (B, [10, 0, 0])))), 2);

%!test  # the empty shape
%! assert_equal (projection (solid.Shape ()), cell (1, 0));

%!error<solid.Shape.projection: U must be a geom.UCS object.> ...
%! projection (solid.Shape (), [0, 0, 1])

%!test  # boxes: exact, in whole faces
%! A = solid.box (10, 10, 10);
%! H = hull (A, translate (A, [20, 0, 0]));
%! assert_equal (volume (H), 3000, -1e-12);
%! assert_equal (numfaces (H), 6);
%! assert_equal (isvalid (H), true);
%! B = subtract (A, translate (solid.cylinder (2, 10), [5, 5, 0]));
%! assert_equal (volume (hull (B)), 1000, -1e-12);

%!test  # a box and a point, a pyramid on it
%! H = hull (solid.box (10, 10, 10), [5, 5, 20]);
%! assert_equal (volume (H), 1000 + 1000 / 3, -1e-12);
%! H = hull (solid.Shape (), [0, 0, 0; 6, 0, 0; 0, 6, 0; 0, 0, 6]);
%! assert_equal (volume (H), 36, -1e-12);
%! assert_equal (isempty (hull (solid.Shape (), zeros (0, 3))), true);

%!test  # a slot: inside the exact hull, within TOL
%! C = solid.cylinder (5, 4);
%! H = hull (C, translate (C, [20, 0, 0]));
%! V = (25 * pi + 200) * 4;
%! assert_equal (volume (H) <= V, true);
%! assert_equal (volume (H) >= V - 0.01 * area (H), true);
%! G = hull (C, translate (C, [20, 0, 0]), 'Tolerance', 0.5);
%! assert_equal (volume (G) >= V - 0.5 * area (G), true);
%! assert_equal (volume (G) < volume (H), true);

%!error<solid.Shape.hull: Name/Value arguments must come in pairs.> ...
%! hull (solid.Shape (), 'Tolerance')
%!error<solid.Shape.hull: unknown option 'Angle'.> ...
%! hull (solid.Shape (), 'Angle', 1)
%!error<solid.Shape.hull: option names must be character vectors.> ...
%! hull (solid.Shape (), 'Tolerance', 0.1, 1, 1)
%!test  # option names ignore case
%! S = solid.sphere (1);
%! assert_equal (isequal (hull (S, 'tolerance', 0.1), ...
%!                       hull (S, 'Tolerance', 0.1)), true);
%!error<solid.Shape.hull: Tolerance must be a positive and finite real scalar.> ...
%! hull (solid.Shape (), 'Tolerance', 0)
%!error<solid.Shape.hull: every operand must be a solid.Shape object or an N-by-3 matrix of points.> ...
%! hull (solid.Shape (), [0, 0])
%!error<solid.Shape.hull: the hull is flat and encloses no volume.> ...
%! hull (solid.Shape (), [0, 0, 0; 1, 0, 0; 0, 1, 0])
%!error<solid.Shape.hull: the hull is flat and encloses no volume.> ...
%! hull (solid.Shape (), [0, 0, 0; 1, 0, 0; 0, 1, 0; 1, 1, 0])

%!test  # resized evenly, the least corner kept
%! B = resize (translate (solid.box (10, 20, 5), [1, 2, 3]), [0, 40, 0]);
%! assert_equal (bbox (B), [1, 2, 3, 21, 42, 13], 1e-12);
%! C = resize (solid.cylinder (5, 10), [40, 40, 40]);
%! assert_equal (numel (faces (C, 'Type', 'cylinder')), 1);
%! assert_equal (volume (C), 16000 * pi, -1e-12);
%! assert_equal (isempty (resize (solid.Shape (), [1, 1, 1])), true);

%!test  # resized unevenly: planes stay planes
%! C = resize (solid.cylinder (5, 10), [20, 0, 0], 'Uniform', false);
%! assert_equal (volume (C), 500 * pi, -1e-9);
%! assert_equal (isvalid (C), true);
%! assert_equal (numel (faces (C, 'Type', 'plane')), 2);
%! assert_equal (numel (faces (C, 'Type', 'bspline')), 1);
%! assert_equal (numel (faces (C, 'Normal', [0, 0, 1])), 1);
%! B = resize (subtract (solid.box (10, 10, 10), solid.cylinder (3, 10)), ...
%!             [20, 10, 0], 'Uniform', false);
%! assert_equal (volume (B), 2000 - 45 * pi, -1e-9);
%! assert_equal (isvalid (B), true);

%!test  # copies apart side by side, others fused
%! A = solid.box (1, 1, 1);
%! K = copy (A, [0, 0, 0; 3, 0, 0; 0.5, 0, 0]);
%! assert_equal ([numsolids(K), volume(K)], [2, 2.5], 1e-12);
%! K = copy (A, [5, 5, 5]);
%! assert_equal (bbox (K), [5, 5, 5, 6, 6, 6], 1e-12);
%! assert_equal (isempty (copy (solid.Shape (), [0, 0, 0; 1, 0, 0])), true);

%!test  # a rectangular array of holes cut
%! H = rectarray (translate (solid.cylinder (2, 5), [10, 10, 0]), ...
%!                [6, 4, 1], [10, 10, 0]);
%! assert_equal (numsolids (H), 24);
%! P = subtract (solid.box (70, 50, 5), H);
%! assert_equal (volume (P), 17500 - 480 * pi, -1e-12);
%! assert_equal (bbox (rectarray (solid.box (1, 1, 1), [1, 1, 3], ...
%!                               [0, 0, -2])), [0, 0, -4, 1, 1, 1], 1e-12);

%!test  # a bolt circle, and a ring of blades fused
%! F = polararray (translate (solid.cylinder (3, 8), [20, 0, 0]), 6, 360);
%! assert_equal (numsolids (F), 6);
%! C = centroid (F);
%! assert_equal (C, [0, 0, 4], 1e-9);
%! W = polararray (solid.box (10, 2, 2), 8, 360);
%! assert_equal ([numsolids(W), isvalid(W)], [1, true]);
%! Z = polararray (translate (solid.box (10, 2, 2), [15, -1, 0]), 2, 90);
%! assert_equal (bbox (Z), [-1, -1, 0, 25, 25, 2], 1e-12);

%!test  # about another axis; copies kept facing
%! Z = polararray (translate (solid.box (2, 2, 2), [10, -1, -1]), 2, 180, ...
%!                 [0, 1, 0], [0, 0, 0]);
%! assert_equal (bbox (Z), [-12, -1, -1, 12, 1, 1], 1e-12);
%! G = polararray (translate (solid.box (10, 2, 2), [15, -1, 0]), 2, 90, ...
%!                 [0, 0, 1], [0, 0, 0], 'Rotate', false);
%! assert_equal (bbox (G), [-5, -1, 0, 25, 21, 2], 1e-12);

%!error<solid.Shape.resize: invalid number of input arguments.> ...
%! resize (solid.Shape ())
%!error<solid.Shape.resize: SZ must be a 3-element vector of nonnegative finite sizes, not all zero.> ...
%! resize (solid.Shape (), [0, 0, 0])
%!error<solid.Shape.resize: SZ must be a 3-element vector of nonnegative finite sizes, not all zero.> ...
%! resize (solid.Shape (), [1, 1])
%!error<solid.Shape.resize: unknown option 'Even'.> ...
%! resize (solid.Shape (), [1, 1, 1], 'Even', true)
%!error<solid.Shape.resize: option names must be character vectors.> ...
%! resize (solid.Shape (), [1, 1, 1], 1, true)
%!test  # option names ignore case
%! S = solid.box (1, 2, 3);
%! assert_equal (isequal (resize (S, [2, 2, 2], 'uniform', false), ...
%!                       resize (S, [2, 2, 2], 'Uniform', false)), true);
%!error<solid.Shape.resize: Uniform must be true or false.> ...
%! resize (solid.Shape (), [1, 1, 1], 'Uniform', 'yes')
%!error<solid.Shape.copy: invalid number of input arguments.> ...
%! copy (solid.Shape ())
%!error<solid.Shape.copy: D must be an N-by-3 real matrix of finite offsets.> ...
%! copy (solid.Shape (), [1, 2])
%!error<solid.Shape.rectarray: invalid number of input arguments.> ...
%! rectarray (solid.Shape (), [2, 2, 1])
%!error<solid.Shape.rectarray: COUNT must be a 3-element vector of positive integers.> ...
%! rectarray (solid.Shape (), [2, 2], [1, 1, 1])
%!error<solid.Shape.rectarray: SPACING must be a real 3-element vector of finite values.> ...
%! rectarray (solid.Shape (), [2, 2, 1], [1, 1])
%!error<solid.Shape.rectarray: SPACING must be nonzero where COUNT is more than one.> ...
%! rectarray (solid.Shape (), [2, 2, 1], [1, 0, 0])
%!error<solid.Shape.polararray: invalid number of input arguments.> ...
%! polararray (solid.Shape (), 3)
%!error<solid.Shape.polararray: N must be a positive integer.> ...
%! polararray (solid.Shape (), -1, 90)
%!error<solid.Shape.polararray: ANGLE must be a nonzero real scalar of at most 360 degrees.> ...
%! polararray (solid.Shape (), 3, 0)
%!error<solid.Shape.polararray: AXIS must not be the zero vector.> ...
%! polararray (solid.Shape (), 3, 90, [0, 0, 0])
%!error<solid.Shape.polararray: P must be a real 3-element vector of finite values.> ...
%! polararray (solid.Shape (), 3, 90, [0, 0, 1], [0, 0])
%!error<solid.Shape.polararray: Rotate must be true or false.> ...
%! polararray (solid.Shape (), 3, 90, 'Rotate', 2)
%!error<solid.Shape.polararray: unknown option 'Turn'.> ...
%! polararray (solid.Shape (), 3, 90, 'Turn', true)
%!error<solid.Shape.polararray: option names must be character vectors.> ...
%! polararray (solid.Shape (), 3, 90, [0, 0, 1], [0, 0, 0], 1, true)
%!error<solid.Shape.tessellate: TOL must be a positive and finite real scalar.> ...
%! tessellate (solid.Shape (), 0)
%!error<solid.Shape: Colour must be empty or a 1-by-3 or N-by-3 matrix of values from 0 to 1, N the number of solids, a row of NaN for no colour.>
%! S = solid.Shape ();
%! S.Colour = [1, 0, 0];
%!error<solid.Shape: Colour must be empty or a 1-by-3 or N-by-3 matrix of values from 0 to 1, N the number of solids, a row of NaN for no colour.>
%! S = solid.box (1, 1, 1);
%! S.Colour = [1.5, 0, 0];
%!error<solid.Shape: Colour must be empty or a 1-by-3 or N-by-3 matrix of values from 0 to 1, N the number of solids, a row of NaN for no colour.>
%! S = solid.box (1, 1, 1);
%! S.Colour = [1, 0, 0; 0, 1, 0];
%!error<solid.Shape: Colour must be empty or a 1-by-3 or N-by-3 matrix of values from 0 to 1, N the number of solids, a row of NaN for no colour.>
%! S = solid.box (1, 1, 1);
%! S.Colour = 'red';
