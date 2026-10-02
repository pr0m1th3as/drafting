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
  ## operators combine, and what @code{solid.write} saves as STEP for exchange
  ## or STL for printing.
  ##
  ## Shapes are made by @code{solid.box}, @code{solid.cylinder},
  ## @code{solid.cone}, @code{solid.sphere} and @code{solid.torus}, from
  ## regions by @code{solid.extrude}, @code{solid.revolve}, @code{solid.loft},
  ## @code{solid.sweep} and @code{solid.helix}, and from files by
  ## @code{solid.read}, and combined by three methods, each taking any number
  ## of shapes:
  ##
  ## @multitable @columnfractions 0.25 0.75
  ## @headitem Method @tab Result
  ## @item @code{union} @tab the material of any of them
  ## @item @code{subtract} @tab the material of the first that is in none of
  ## the others
  ## @item @code{intersect} @tab the material common to all of them
  ## @end multitable
  ##
  ## @example
  ## @group
  ## plate = solid.box (80, 40, 12);
  ## bore = translate (solid.cylinder (4, 12), [20, 20, 0]);
  ## part = subtract (plate, bore);
  ## volume (part)
  ## @result{} 3.7797e+04
  ## @end group
  ## @end example
  ##
  ## Features are worked on a shape by methods: @code{hole} drills plain,
  ## counterbored, countersunk and tapping holes, @code{fillet} and
  ## @code{chamfer} round or bevel edges, and @code{shell} hollows the shape.
  ## The edges and faces they act on are chosen by @code{edges} and
  ## @code{faces}, by the kind of curve or surface, by direction and by
  ## position.
  ##
  ## The class is a @emph{value} class.  Every operation returns a new shape
  ## and leaves its operands unchanged, and a copy is independent of the
  ## original.  The empty shape adds nothing to a union and empties an
  ## intersection, and a boolean whose result holds no material, such as the
  ## intersection of two solids that do not meet, returns it.  A shape is
  ## saved and loaded with @code{save} and @code{load} like any other value.
  ##
  ## The @code{solid} namespace needs Open CASCADE, which the package uses
  ## where it is found when the package is built.  On a build without it, the
  ## empty shape can still be made, but every function and method that needs
  ## the library raises an error saying so.
  ##
  ## @seealso{solid.box, solid.read, solid.write, solid.show}
  ## @end deftp

  properties (SetAccess = private, Hidden)

    Data = uint8 ([]);

  endproperties

  methods (Hidden)

    function disp (this)

      if (isempty (this.Data))
        printf ("  solid.Shape: empty\n");
      elseif (! isempty (solid.__checkocct__ ()))
        printf ("  solid.Shape: Open CASCADE not available\n");
      else
        printf ("  solid.Shape: %d solid(s), %d faces, %d edges\n", ...
                numsolids (this), numfaces (this), numedges (this));
      endif

    endfunction

  endmethods

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
      if (! isempty (DATA) && (numel (DATA) < numel (sig) ...
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
        C = solid.Shape (occt ('solid.Shape.union', 'fuse', data{:}));
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
        C = solid.Shape (occt ('solid.Shape.subtract', 'cut', C.Data, ...
                               data{:}));
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
        C = solid.Shape (occt ('solid.Shape.intersect', 'common', data{:}));
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{S} =} translate (@var{S}, @var{V})
    ##
    ## Move a shape by the vector @var{V}.
    ##
    ## @var{V} is a 3-element vector in millimetres.
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
    ## @seealso{solid.Shape.translate, solid.Shape.mirror, solid.Shape.scale}
    ## @end deftypefn
    function this = rotate (this, ANGLE, AXIS, P = [0, 0, 0])

      ## Input validation
      if (nargin < 3 || nargin > 4)
        error ("solid.Shape.rotate: invalid number of input arguments.");
      endif
      if (! isnumeric (ANGLE) || ! isreal (ANGLE) || ! isscalar (ANGLE) ...
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
    ## @seealso{solid.Shape.translate, solid.Shape.rotate, solid.Shape.mirror}
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

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{V} =} volume (@var{S})
    ##
    ## The volume of a shape in cubic millimetres.
    ##
    ## The volume is computed from the exact surfaces, not from facets.  The
    ## empty shape has volume zero.
    ##
    ## @seealso{solid.Shape.area, solid.Shape.centroid}
    ## @end deftypefn
    function V = volume (this)

      if (isempty (this.Data))
        V = 0;
      else
        V = occt ('solid.Shape.volume', 'volume', this.Data);
      endif

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{A} =} area (@var{S})
    ##
    ## The surface area of a shape in square millimetres.
    ##
    ## The area is the sum over every face, computed from the exact surfaces.
    ## The empty shape has area zero.
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
    ## @deftypefn {solid.Shape} {@var{C} =} centroid (@var{S})
    ##
    ## The centre of volume of a shape, as a 1-by-3 vector in millimetres.
    ##
    ## For a part of uniform density this is its centre of mass.  The empty
    ## shape has no centroid and returns an empty @var{C}, and a shape that
    ## encloses no volume returns @code{NaN} in every coordinate.
    ##
    ## @seealso{solid.Shape.volume, solid.Shape.bbox}
    ## @end deftypefn
    function C = centroid (this)

      if (isempty (this.Data))
        C = [];
      else
        C = occt ('solid.Shape.centroid', 'centroid', this.Data);
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
    ## @seealso{solid.Shape.numsolids, solid.Shape.numfaces}
    ## @end deftypefn
    function N = numedges (this)

      N = topology (this, 'edge', 'solid.Shape.numedges');

    endfunction

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
                                                 'Within', []));
      if (isempty (errmsg))
        [errmsg, opt.Type] = checktype (opt.Type, kinds, 'curve');
      endif
      if (isempty (errmsg) && ! isempty (opt.Direction))
        errmsg = checkvec (opt.Direction, 'Direction', true);
      endif
      if (isempty (errmsg))
        errmsg = checkbox (opt.Within);
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.edges: %s", errmsg);
      endif

      E = zeros (1, 0);
      if (isempty (this.Data))
        return;
      endif
      info = occt ('solid.Shape.edges', 'edges', this.Data);
      [type, dir, box, seam] = info{:};
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
    ## A radius too large for the faces beside an edge cannot be built and
    ## raises an error, as does an edge that cannot be rounded at all.
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

      this.Data = occt ('solid.Shape.fillet', 'fillet', this.Data, ...
                        unique (double (E)), double (R));

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{S} =} chamfer (@var{S}, @var{E}, @var{D})
    ##
    ## Bevel edges of a shape at 45 degrees.
    ##
    ## @code{@var{S} = chamfer (@var{S}, @var{E}, @var{D})} cuts the edges of
    ## @var{S} indexed by @var{E}, as @code{solid.Shape.edges} returns them,
    ## back by @var{D} millimetres on both faces, so a chamfer on a square
    ## corner is the 45 degree bevel a drawing calls @code{@var{D} x 45}.
    ##
    ## A chamfer too large for the faces beside an edge cannot be built and
    ## raises an error, as does an edge that cannot be chamfered at all.
    ##
    ## @seealso{solid.Shape.edges, solid.Shape.fillet}
    ## @end deftypefn
    function this = chamfer (this, E, D)

      ## Input validation
      if (nargin != 3)
        error ("solid.Shape.chamfer: invalid number of input arguments.");
      endif
      errmsg = checkindex (E, numedges (this), 'E', 'edge', false);
      if (isempty (errmsg))
        errmsg = solid.__checkpos__ (D, 'D');
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.chamfer: %s", errmsg);
      endif

      this.Data = occt ('solid.Shape.chamfer', 'chamfer', this.Data, ...
                        unique (double (E)), double (D));

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {solid.Shape} {@var{S} =} shell (@var{S}, @var{F}, @var{T})
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
    function this = shell (this, F, T)

      ## Input validation
      if (nargin != 3)
        error ("solid.Shape.shell: invalid number of input arguments.");
      endif
      errmsg = checkindex (F, numfaces (this), 'F', 'face', true);
      if (isempty (errmsg))
        errmsg = solid.__checkpos__ (T, 'T');
      endif
      if (isempty (errmsg) && isempty (this.Data))
        errmsg = "S is empty, so there is nothing to hollow.";
      endif
      if (! isempty (errmsg))
        error ("solid.Shape.shell: %s", errmsg);
      endif

      this.Data = occt ('solid.Shape.shell', 'shell', this.Data, ...
                        unique (double (F)), double (T));

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
    ## The point is where the hole enters the material, normally on a face of
    ## the part.  All the holes are cut in one operation.
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
      if (! isnumeric (P) || ! isreal (P) || ! ismatrix (P) ...
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
      if (! isnumeric (DEPTH) || ! isreal (DEPTH) || ! isscalar (DEPTH) ...
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
      if (! isempty (cb) && (! isnumeric (cb) || ! isreal (cb) ...
                             || numel (cb) != 2 || ! all (isfinite (cb)) ...
                             || ! (cb(1) > D) || ! (cb(2) > 0) ...
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
        if (! isnumeric (cs) || ! isreal (cs) || numel (cs) != 2 ...
            || ! all (isfinite (cs)) || ! (cs(1) > D) || ! (cs(2) > 0) ...
            || ! (cs(2) < 180) ...
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
        if (! isnumeric (tip) || ! isreal (tip) || ! isscalar (tip) ...
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

      ## A through hole runs past the farthest corner of the part
      if (isinf (DEPTH))
        B = bbox (this);
        [X, Y, Z] = ndgrid (B([1, 4]), B([2, 5]), B([3, 6]));
        C = [X(:), Y(:), Z(:)];
        DEPTH = 0;
        for i = 1:rows (P)
          DEPTH = max (DEPTH, max (sqrt (sum ((C - P(i,:)) .^ 2, 2))));
        endfor
        DEPTH += 1;
      endif

      ## The cutters of one hole, running up the z axis from the origin
      T = {solid.cylinder(D / 2, DEPTH)};
      if (! isempty (cb))
        T{end+1} = solid.cylinder (cb(1) / 2, cb(2));
      endif
      if (! isempty (cs))
        T{end+1} = solid.cone (cs(1) / 2, D / 2, ...
                               (cs(1) - D) / 2 / tand (cs(2) / 2));
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

  endmethods

endclassdef

## Run an Open CASCADE operation on behalf of CALLER, which names any error
function out = occt (caller, cmd, varargin)

  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("%s: %s", caller, errmsg);
  endif
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
  if (! isnumeric (V) || ! isreal (V) || numel (V) != 3 ...
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
  for k = 1:2:numel (args)
    name = args{k};
    if (! ischar (name) || ! isrow (name) || ! any (strcmp (name, known)))
      errmsg = "unknown parameter.";
      return;
    endif
    opt.(name) = args{k+1};
  endfor

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
  if (! isempty (W) && (! isnumeric (W) || ! isreal (W) || numel (W) != 6 ...
                        || ! isvector (W) || any (isnan (W)) ...
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
  if (! isnumeric (I) || ! isreal (I) || ! (isvector (I) || isempty (I)) ...
      || (isempty (I) && ! emptyok) || any (I != fix (I)) || any (I < 1) ...
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

%!testif ; exist ('__occt__') == 3  # the bytes survive a round trip
%! A = solid.box (10, 20, 30);
%! B = solid.Shape (A.Data);
%! assert_equal (volume (B), volume (A));

%!testif ; exist ('__occt__') == 3  # two overlapping blocks
%! A = solid.box (10, 10, 10);
%! C = union (A, translate (A, [5, 0, 0]));
%! assert_equal (volume (C), 1500, 1e-9);
%! assert_equal (numsolids (C), 1);
%! assert_equal (numfaces (C), 6);
%! assert_equal (isvalid (C), true);

%!testif ; exist ('__occt__') == 3  # three blocks in one operation
%! A = solid.box (10, 10, 10);
%! C = union (A, translate (A, [20, 0, 0]), translate (A, [5, 5, 0]));
%! assert_equal (volume (C), 2750, 1e-9);
%! assert_equal (numsolids (C), 2);

%!testif ; exist ('__occt__') == 3  # empty shapes add nothing
%! A = solid.box (10, 10, 10);
%! assert_equal (volume (union (A, solid.Shape ())), 1000, 1e-9);
%! assert_equal (volume (union (solid.Shape (), A)), 1000, 1e-9);
%! assert_equal (volume (union (A)), 1000, 1e-9);
%! assert_equal (isempty (union (solid.Shape (), solid.Shape ())), true);

%!testif ; exist ('__occt__') == 3  # a through hole
%! C = subtract (solid.box (80, 40, 12), ...
%!               translate (solid.cylinder (4, 12), [20, 20, 0]));
%! assert_equal (volume (C), 38400 - 192 * pi, 1e-9);
%! assert_equal (numfaces (C), 7);
%! assert_equal (isvalid (C), true);

%!testif ; exist ('__occt__') == 3  # several holes in one operation
%! h = solid.cylinder (3, 10);
%! C = subtract (solid.box (100, 20, 10), translate (h, [10, 10, 0]), ...
%!               translate (h, [50, 10, 0]), translate (h, [90, 10, 0]));
%! assert_equal (volume (C), 20000 - 3 * 90 * pi, 1e-9);
%! assert_equal (numfaces (C), 9);

%!testif ; exist ('__occt__') == 3  # cutting a bar in two
%! C = subtract (solid.box (100, 10, 10), ...
%!               translate (solid.box (2, 10, 10), [49, 0, 0]));
%! assert_equal (numsolids (C), 2);
%! assert_equal (volume (C), 9800, 1e-9);

%!testif ; exist ('__occt__') == 3  # subtracting empty shapes or nothing
%! A = solid.box (10, 10, 10);
%! assert_equal (volume (subtract (A, solid.Shape ())), 1000, 1e-9);
%! assert_equal (volume (subtract (A)), 1000, 1e-9);
%! assert_equal (isempty (subtract (solid.Shape (), A)), true);

%!testif ; exist ('__occt__') == 3  # two overlapping blocks
%! A = solid.box (10, 10, 10);
%! C = intersect (A, translate (A, [5, 5, 0]));
%! assert_equal (volume (C), 250, 1e-9);
%! assert_equal (bbox (C), [5, 5, 0, 10, 10, 10], 1e-9);

%!testif ; exist ('__occt__') == 3  # common to all three, not to the first
%! A = solid.box (10, 10, 10);
%! C = intersect (A, translate (A, [5, 0, 0]), translate (A, [0, 5, 0]));
%! assert_equal (volume (C), 250, 1e-9);
%! assert_equal (bbox (C), [5, 5, 0, 10, 10, 10], 1e-9);

%!testif ; exist ('__occt__') == 3  # shapes that do not all meet
%! A = solid.box (10, 10, 10);
%! assert_equal (isempty (intersect (A, translate (A, [20, 0, 0]))), true);
%! assert_equal (isempty (intersect (A, translate (A, [5, 0, 0]), ...
%!                                   translate (A, [-8, 0, 0]))), true);
%! assert_equal (isempty (intersect (A, solid.Shape ())), true);
%! assert_equal (volume (intersect (A)), 1000, 1e-9);

%!testif ; exist ('__occt__') == 3  # the operands are left unchanged
%! A = solid.box (10, 10, 10);
%! B = translate (A, [5, 0, 0]);
%! C = subtract (A, B);
%! assert_equal (volume (A), 1000, 1e-9);
%! assert_equal (bbox (B), [5, 0, 0, 15, 10, 10], 1e-9);

%!testif ; exist ('__occt__') == 3
%! S = translate (solid.box (10, 20, 30), [1, -2, 3]);
%! assert_equal (bbox (S), [1, -2, 3, 11, 18, 33], 1e-9);

%!testif ; exist ('__occt__') == 3  # a quarter turn about z
%! S = rotate (solid.box (10, 20, 30), 90, [0, 0, 1]);
%! assert_equal (bbox (S), [-20, 0, 0, 0, 10, 30], 1e-9);

%!testif ; exist ('__occt__') == 3  # about an axis through a point
%! S = rotate (solid.box (10, 20, 30), 180, [0, 0, 1], [10, 0, 0]);
%! assert_equal (bbox (S), [10, -20, 0, 20, 0, 30], 1e-9);

%!testif ; exist ('__occt__') == 3  # a reflection keeps volume and validity
%! S = mirror (solid.box (10, 20, 30), [1, 0, 0]);
%! assert_equal (bbox (S), [-10, 0, 0, 0, 20, 30], 1e-9);
%! assert_equal (volume (S), 6000, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # in a plane through a point
%! S = mirror (solid.box (10, 20, 30), [0, 0, 1], [0, 0, 40]);
%! assert_equal (bbox (S), [0, 0, 50, 10, 20, 80], 1e-9);

%!testif ; exist ('__occt__') == 3
%! S = scale (solid.box (10, 20, 30), 2);
%! assert_equal (volume (S), 48000, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 20, 40, 60], 1e-9);

%!testif ; exist ('__occt__') == 3  # about a point that stays put
%! S = scale (solid.box (10, 10, 10), 0.5, [10, 10, 10]);
%! assert_equal (bbox (S), [5, 5, 5, 10, 10, 10], 1e-9);

%!testif ; exist ('__occt__') == 3
%! S = solid.box (10, 20, 30);
%! assert_equal (area (S), 2200, 1e-9);
%! assert_equal (centroid (S), [5, 10, 15], 1e-9);
%! [B, L] = bbox (S);
%! assert_equal (B, [0, 0, 0, 10, 20, 30], 1e-9);
%! assert_equal (L, [10, 20, 30], 1e-9);

%!testif ; exist ('__occt__') == 3  # the box of a cylinder is tight
%! assert_equal (bbox (solid.cylinder (4, 12)), [-4, -4, 0, 4, 4, 12], 1e-9);

%!testif ; exist ('__occt__') == 3
%! S = solid.box (10, 20, 30);
%! assert_equal (numsolids (S), 1);
%! assert_equal (numfaces (S), 6);
%! assert_equal (numedges (S), 12);

%!testif ; exist ('__occt__') == 3  # a seam edge closes the curved face
%! assert_equal (numedges (solid.cylinder (4, 12)), 3);

%!testif ; exist ('__occt__') == 3  # every edge but the seam
%! assert_equal (edges (solid.cylinder (4, 12)), [1, 3]);
%! assert_equal (numel (edges (solid.box (10, 20, 30))), 12);

%!testif ; exist ('__occt__') == 3  # the poles of a sphere are no edges
%! assert_equal (edges (solid.sphere (5)), zeros (1, 0));

%!testif ; exist ('__occt__') == 3  # by direction, either way
%! B = solid.box (10, 20, 30);
%! assert_equal (numel (edges (B, 'Direction', [0, 0, 1])), 4);
%! assert_equal (edges (B, 'Direction', [0, 0, -2]), ...
%!               edges (B, 'Direction', [0, 0, 1]));

%!testif ; exist ('__occt__') == 3  # by type and by the axis of a circle
%! C = solid.cylinder (4, 12);
%! assert_equal (edges (C, 'Type', 'circle'), [1, 3]);
%! assert_equal (edges (C, 'Type', {'line', 'bspline'}), zeros (1, 0));
%! assert_equal (edges (C, 'Direction', [0, 0, 1]), [1, 3]);

%!testif ; exist ('__occt__') == 3  # the four edges round the top
%! B = solid.box (10, 20, 30);
%! assert_equal (numel (edges (B, 'Within', [0, 0, 30, 10, 20, 30])), 4);
%! assert_equal (numel (edges (B, 'Within', [0, 0, 30, 10, 20, 30], ...
%!                             'Direction', [1, 0, 0])), 2);

%!testif ; exist ('__occt__') == 3  # faces by outward normal
%! B = solid.box (10, 20, 30);
%! F = faces (B, 'Normal', [0, 0, 1]);
%! assert_equal (numel (F), 1);
%! assert_equal (numel (faces (B)), 6);
%! assert_equal (numel (faces (B, 'Type', 'plane')), 6);
%! assert_equal (numel (faces (B, 'Normal', [1, 1, 0])), 0);

%!testif ; exist ('__occt__') == 3  # faces by type, axis and box
%! C = solid.cylinder (4, 12);
%! assert_equal (numel (faces (C, 'Type', 'cylinder')), 1);
%! assert_equal (faces (C, 'Axis', [0, 0, -1]), faces (C, 'Type', 'cylinder'));
%! assert_equal (numel (faces (C, 'Within', [-4, -4, 12, 4, 4, 12])), 1);
%! S = solid.revolve (geom.Region ([0, 0; 10, 0; 10, 30; 6, 30; 6, 49; ...
%!                                  5, 50; 0, 50]));
%! assert_equal (numel (faces (S, 'Type', {'cylinder', 'cone'})), 3);

%!testif ; exist ('__occt__') == 3  # four parallel edges rounded
%! B = solid.box (10, 20, 30);
%! S = fillet (B, edges (B, 'Direction', [0, 0, 1]), 2);
%! assert_equal (volume (S), 6000 - 4 * (4 - pi) * 30, 1e-9);
%! assert_equal (numfaces (S), 10);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a rounded end of a cylinder
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

%!testif ; exist ('__occt__') == 3  # four parallel edges bevelled
%! B = solid.box (10, 20, 30);
%! S = chamfer (B, edges (B, 'Direction', [0, 0, 1]), 2);
%! assert_equal (volume (S), 6000 - 4 * 2 * 30, 1e-9);
%! assert_equal (numfaces (S), 10);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # an open box
%! B = solid.box (10, 20, 30);
%! S = shell (B, faces (B, 'Normal', [0, 0, 1]), 1);
%! assert_equal (volume (S), 6000 - 8 * 18 * 29, 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 20, 30], 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a closed shell round a cavity
%! B = solid.box (10, 20, 30);
%! assert_equal (volume (shell (B, [], 1)), 6000 - 8 * 18 * 28, 1e-9);

%!testif ; exist ('__occt__') == 3  # a cup
%! C = solid.cylinder (4, 12);
%! S = shell (C, faces (C, 'Normal', [0, 0, 1]), 1);
%! assert_equal (volume (S), (192 - 99) * pi, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # through holes, several at once
%! S = hole (solid.box (80, 40, 12), [20, 20, 12; 60, 20, 12], 8, Inf);
%! assert_equal (volume (S), 38400 - 2 * 16 * pi * 12, 1e-9);
%! assert_equal (numfaces (S), 8);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a blind hole, flat and with a drill tip
%! B = solid.box (80, 40, 12);
%! S = hole (B, [20, 20, 12], 8, 5);
%! assert_equal (volume (S), 38400 - 16 * pi * 5, 1e-9);
%! S = hole (B, [20, 20, 12], 8, 5, 'Tip', 118);
%! assert_equal (volume (S), 38400 - 16 * pi * (5 + 4 / tand (59) / 3), 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # counterbored
%! S = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf, ...
%!           'Counterbore', [14, 4]);
%! assert_equal (volume (S), 38400 - pi * (49 * 4 + 16 * 8), 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # countersunk at 90 degrees
%! S = hole (solid.box (80, 40, 12), [20, 20, 12], 8, Inf, ...
%!           'Countersink', 16);
%! assert_equal (volume (S), 38400 - pi * (4 / 3 * (64 + 32 + 16) + 16 * 8), ...
%!               1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # tapping size for M6, drilled from the side
%! S = hole (solid.box (80, 40, 12), [0, 20, 6], 'M6', Inf, ...
%!           'Direction', [1, 0, 0]);
%! assert_equal (volume (S), 38400 - 6.25 * pi * 80, 1e-9);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # straight up from underneath
%! S = hole (solid.box (80, 40, 12), [20, 20, 0], 'M2.5', 3, ...
%!           'Direction', [0, 0, 1]);
%! assert_equal (volume (S), 38400 - 1.025 ^ 2 * pi * 3, 1e-9);

%!test  # drilling the empty shape
%! assert_equal (isempty (hole (solid.Shape (), [0, 0, 0], 5, Inf)), true);

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
%!error<solid.Shape.edges: unknown parameter.> ...
%! edges (solid.Shape (), 'Normal', [0, 0, 1])
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
%!error<solid.Shape.faces: unknown parameter.> ...
%! faces (solid.Shape (), 'Direction', [0, 0, 1])
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
%!error<solid.Shape.shell: invalid number of input arguments.> ...
%! shell (solid.Shape (), [])
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
%!error<solid.Shape.hole: unknown parameter.> ...
%! hole (solid.Shape (), [0, 0, 0], 5, 1, 'Depth', 2)
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
