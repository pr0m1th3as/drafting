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

## -*- texinfo -*-
## @deftypefn  {drafting} {@var{S} =} solid.Shape ()
## @deftypefnx {drafting} {@var{S} =} solid.Shape (@var{DATA})
##
## A solid in millimetres, modelled through Open CASCADE.
##
## @code{solid.Shape} holds the exact boundary of one or more solids: every
## face a plane, cylinder, cone, sphere, torus or spline surface, every edge a
## line, circle or curve, with nothing approximated by facets.  It is what the
## functions of the @code{solid} namespace create, what the boolean operators
## combine, and what @code{solid.write} saves as STEP for exchange or STL for
## printing.
##
## @code{@var{S} = solid.Shape ()} returns the empty shape, which holds
## nothing.  Shapes are made by @code{solid.box}, @code{solid.cylinder},
## @code{solid.cone}, @code{solid.sphere} and @code{solid.torus}, from
## profiles by @code{solid.extrude}, @code{solid.revolve} and
## @code{solid.loft}, and from files by @code{solid.read}, and combined by
## three methods, each taking any number of shapes:
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
## hole = translate (solid.cylinder (4, 12), [20, 20, 0]);
## part = subtract (plate, hole);
## volume (part)
## @result{} 3.7797e+04
## @end group
## @end example
##
## The class is a @emph{value} class.  Every operation returns a new shape and
## leaves its operands unchanged, and a copy is independent of the original.
## The empty shape adds nothing to a union and empties an intersection, and a
## boolean whose result holds no material, such as the intersection of two
## solids that do not meet, returns it.
##
## A shape is saved and loaded with @code{save} and @code{load} like any
## other value.
##
## @code{@var{S} = solid.Shape (@var{DATA})} wraps @var{DATA}, the bytes of a
## shape in Open CASCADE's binary format.  This is how the functions of the
## @code{solid} namespace return what Open CASCADE computed, and it is not for
## direct use: bytes that do not begin with that format's signature are
## refused.
##
## The @code{solid} namespace needs Open CASCADE, which the package uses where
## it is found when the package is built.  On a build without it, the empty
## shape can still be made, but every function and method that needs the
## library raises an error saying so.
##
## @seealso{solid.box, solid.read, solid.write}
## @end deftypefn

classdef Shape

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
    errmsg = sprintf ("%s must be a real 3-element vector of finite values.", ...
                      name);
  elseif (nonzero && all (V == 0))
    errmsg = sprintf ("%s must not be the zero vector.", name);
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
