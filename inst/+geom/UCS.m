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


classdef UCS
  ## -*- texinfo -*-
  ## @deftp {drafting} geom.UCS
  ##
  ## A user coordinate system: an origin, an @math{x} axis and a normal,
  ## defining a plane with coordinates of its own.
  ##
  ## A @code{geom.UCS} is where a @code{geom.Polyline} or a
  ## @code{geom.Region} lies: its vertices are coordinates in the UCS, and a
  ## solid made from a region is made where its UCS puts it.  A region drawn in
  ## the default UCS, the world @math{xy} plane, is laid on the face of a part
  ## by giving it a UCS on that face, which is what a CAD program's user
  ## coordinate system is for.
  ##
  ## It is a coordinate system, not only a plane: two systems on the same
  ## plane with different origins or @math{x} axes place the same outline
  ## differently, and @code{solid.revolve} turns about the @math{y} axis
  ## through the origin.  The @math{y} axis is the normal crossed with the
  ## @math{x} axis, so the axes are right-handed.
  ##
  ## A UCS is made by its constructor, from a normal and points or with the
  ## mouse in a viewer, or by @code{geom.UCS.threepoint} from three points.
  ## It is a value and never changes.
  ##
  ## @seealso{geom.Polyline, geom.Region, solid.Viewer.pickucs}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {geom.UCS} {property} Origin
    ##
    ## Origin
    ##
    ## The origin, a 1-by-3 point in world coordinates.
    ##
    ## @end deftp
    Origin = [0, 0, 0];

    ## -*- texinfo -*-
    ## @deftp {geom.UCS} {property} XAxis
    ##
    ## x axis
    ##
    ## The unit @math{x} axis, a 1-by-3 direction in world coordinates.
    ##
    ## @end deftp
    XAxis = [1, 0, 0];

    ## -*- texinfo -*-
    ## @deftp {geom.UCS} {property} Normal
    ##
    ## Normal
    ##
    ## The unit normal of the plane, its @math{z} axis.
    ##
    ## @end deftp
    Normal = [0, 0, 1];

  endproperties

  properties (Dependent)

    ## -*- texinfo -*-
    ## @deftp {geom.UCS} {property} YAxis
    ##
    ## y axis
    ##
    ## The unit @math{y} axis, the normal crossed with the @math{x} axis.
    ##
    ## @end deftp
    YAxis

  endproperties

  methods (Hidden)

    function disp (this)

      printf ("  geom.UCS: origin %s, x axis %s, normal %s\n", ...
              vecstr (this.Origin), vecstr (this.XAxis), vecstr (this.Normal));

    endfunction

  endmethods

  methods (Static)

    ## -*- texinfo -*-
    ## @deftypefn {geom.UCS} {@var{U} =} geom.UCS.threepoint (@var{P1}, @var{P2}, @var{P3})
    ##
    ## A UCS through three points.
    ##
    ## @code{@var{U} = geom.UCS.threepoint (@var{P1}, @var{P2}, @var{P3})}
    ## returns the UCS whose origin is @var{P1}, whose @math{x} axis runs from
    ## @var{P1} towards @var{P2}, and whose @math{y} axis lies in the plane of
    ## the three points on the side of @var{P3}, as AutoCAD's three-point UCS
    ## is defined.  Each point is a 3-element vector in world coordinates, and
    ## the three must not lie on one line.
    ##
    ## @end deftypefn
    function U = threepoint (P1, P2, P3)

      ## Input validation
      if (nargin != 3)
        error ("geom.UCS.threepoint: invalid number of input arguments.");
      endif
      if (! isvec3 (P1) || ! isvec3 (P2) || ! isvec3 (P3))
        error (strcat ("geom.UCS.threepoint: P1, P2 and P3 must be real", ...
                       " 3-element vectors of finite values."));
      endif
      P1 = double (P1(:)');
      X = double (P2(:)') - P1;
      V = double (P3(:)') - P1;
      N = cross (X, V);
      if (norm (X) == 0 || norm (N) <= 1e-12 * norm (X) * norm (V))
        error ("geom.UCS.threepoint: P1, P2 and P3 must not lie on one line.");
      endif
      U = geom.UCS (N, P1, P2);

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {geom.UCS} {@var{U} =} geom.UCS ()
    ## @deftypefnx {geom.UCS} {@var{U} =} geom.UCS (@var{V})
    ## @deftypefnx {geom.UCS} {@var{U} =} geom.UCS (@var{NORMAL}, @var{ORIGIN})
    ## @deftypefnx {geom.UCS} {@var{U} =} geom.UCS (@var{NORMAL}, @var{ORIGIN}, @var{XPOINT})
    ##
    ## Make a user coordinate system.
    ##
    ## @code{@var{U} = geom.UCS ()} returns the world coordinate system: the
    ## @math{xy} plane, with its origin at the world origin.
    ##
    ## @code{@var{U} = geom.UCS (@var{V})} picks one with the mouse in the
    ## viewer @var{V}, a @code{solid.Viewer} showing a shape; see
    ## @code{solid.Viewer.pickucs}.
    ##
    ## @code{@var{U} = geom.UCS (@var{NORMAL}, @var{ORIGIN}, @var{XPOINT})}
    ## lays the plane square to the direction @var{NORMAL} through the point
    ## @var{ORIGIN}, its origin, with its @math{x} axis pointing from
    ## @var{ORIGIN} towards the point @var{XPOINT}.  @var{XPOINT} need not lie
    ## on the plane: the direction is projected onto it, so any point along an
    ## edge of the part will do.  It must not lie on the normal through
    ## @var{ORIGIN}, which gives no direction in the plane.
    ##
    ## @code{@var{U} = geom.UCS (@var{NORMAL}, @var{ORIGIN})} takes the
    ## @math{x} axis from the normal alone by DXF's arbitrary axis algorithm,
    ## so it means the same here as in a DXF file.  When the normal is within
    ## about a degree of the world @math{z} axis, @math{x} is the world
    ## @math{y} axis crossed with the normal: the world @math{x} axis for a
    ## plane facing up, its reverse for one facing down.  Otherwise @math{x} is
    ## the world @math{z} axis crossed with the normal, which is level and runs
    ## to the right as the plane is seen from the side its normal faces, so
    ## that @math{y} points up the plane.
    ##
    ## Points and directions are 3-element vectors in world coordinates, and
    ## directions need not have unit length.  The @math{y} axis is the normal
    ## crossed with the @math{x} axis.
    ##
    ## @example
    ## @group
    ## ## The front face of a block, facing -y, origin at its lower left
    ## ## corner, x along the bottom edge
    ## U = geom.UCS ([0, -1, 0], [0, 0, 0], [80, 0, 0]);
    ## U.YAxis
    ## @result{} 0   0   1
    ## @end group
    ## @end example
    ##
    ## @end deftypefn
    function this = UCS (varargin)

      if (nargin == 0)
        return;
      endif

      ## Picked with the mouse in a viewer, which knows how
      if (nargin == 1)
        V = varargin{1};
        if (! isobject (V) || ! isscalar (V) || ! ismethod (V, 'pickucs'))
          error (strcat ("geom.UCS: V must be a viewer to pick in, such as", ...
                         " a solid.Viewer."));
        endif
        U = pickucs (V);
        this.Origin = U.Origin;
        this.XAxis = U.XAxis;
        this.Normal = U.Normal;
        return;
      endif

      ## Input validation
      NORMAL = varargin{1};
      ORIGIN = varargin{2};
      if (! isvec3 (NORMAL) || all (NORMAL == 0))
        error (strcat ("geom.UCS: NORMAL must be a nonzero real 3-element", ...
                       " vector of finite values."));
      endif
      if (! isvec3 (ORIGIN))
        error (strcat ("geom.UCS: ORIGIN must be a real 3-element vector", ...
                       " of finite values."));
      endif
      N = double (NORMAL(:)') / norm (NORMAL);
      O = double (ORIGIN(:)');
      if (nargin == 2)
        X = arbitraryaxis (N);
      else
        XPOINT = varargin{3};
        if (! isvec3 (XPOINT))
          error (strcat ("geom.UCS: XPOINT must be a real 3-element vector", ...
                         " of finite values."));
        endif
        D = double (XPOINT(:)') - O;
        X = D - (D * N') * N;
        if (norm (X) <= 1e-12 * max (norm (D), 1))
          error (strcat ("geom.UCS: XPOINT must not lie on the normal", ...
                         " through ORIGIN."));
        endif
        X /= norm (X);
      endif

      ## No negative zeros, which would show when displayed
      X(X == 0) = 0;
      N(N == 0) = 0;
      this.Origin = O;
      this.XAxis = X;
      this.Normal = N;

    endfunction

    function Y = get.YAxis (this)

      Y = cross (this.Normal, this.XAxis);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.UCS} {@var{TF} =} eq (@var{U1}, @var{U2})
    ##
    ## True when two coordinate systems are the same.
    ##
    ## @code{@var{TF} = eq (@var{U1}, @var{U2})}, or @code{@var{U1} ==
    ## @var{U2}}, is true when the two have the same origin, @math{x} axis and
    ## normal, exactly.  Two systems on one plane with different origins or
    ## @math{x} axes are not the same.
    ##
    ## @end deftypefn
    function TF = eq (U1, U2)

      ## Input validation
      if (! isa (U1, 'geom.UCS') || ! isa (U2, 'geom.UCS') ...
          || ! isscalar (U1) || ! isscalar (U2))
        error ("geom.UCS.eq: both operands must be geom.UCS objects.");
      endif

      TF = isequal (U1.Origin, U2.Origin) && isequal (U1.XAxis, U2.XAxis) ...
           && isequal (U1.Normal, U2.Normal);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.UCS} {@var{W} =} toworld (@var{U}, @var{P})
    ##
    ## World coordinates of points given in a UCS.
    ##
    ## @code{@var{W} = toworld (@var{U}, @var{P})} returns, as an
    ## @math{N}-by-3 matrix, the world coordinates of the points whose
    ## coordinates in @var{U} are the rows of @var{P}, an @math{N}-by-2 matrix
    ## of points in the plane or an @math{N}-by-3 matrix with their heights
    ## above it.
    ##
    ## @seealso{geom.UCS.tolocal}
    ## @end deftypefn
    function W = toworld (this, P)

      ## Input validation
      if (nargin != 2)
        error ("geom.UCS.toworld: invalid number of input arguments.");
      endif
      if (! isnumeric (P) || ! isreal (P) || ! ismatrix (P) ...
          || ! any (columns (P) == [2, 3]) || ! all (isfinite (P(:))))
        error (strcat ("geom.UCS.toworld: P must be an N-by-2 or N-by-3", ...
                       " real matrix of finite values."));
      endif
      P = double (P);
      if (columns (P) == 2)
        P(:,3) = 0;
      endif
      W = this.Origin + P(:,1) * this.XAxis + P(:,2) * this.YAxis ...
          + P(:,3) * this.Normal;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.UCS} {@var{P} =} tolocal (@var{U}, @var{W})
    ##
    ## Coordinates in a UCS of points given in world coordinates.
    ##
    ## @code{@var{P} = tolocal (@var{U}, @var{W})} returns, as an
    ## @math{N}-by-3 matrix, the coordinates in @var{U} of the points whose
    ## world coordinates are the rows of the @math{N}-by-3 matrix @var{W}: their
    ## @math{x} and @math{y} in the plane and their height above it.
    ##
    ## @seealso{geom.UCS.toworld}
    ## @end deftypefn
    function P = tolocal (this, W)

      ## Input validation
      if (nargin != 2)
        error ("geom.UCS.tolocal: invalid number of input arguments.");
      endif
      if (! isnumeric (W) || ! isreal (W) || ! ismatrix (W) ...
          || columns (W) != 3 || ! all (isfinite (W(:))))
        error (strcat ("geom.UCS.tolocal: W must be an N-by-3 real", ...
                       " matrix of finite values."));
      endif
      D = double (W) - this.Origin;
      P = [D * this.XAxis', D * this.YAxis', D * this.Normal'];

    endfunction

  endmethods

endclassdef

## True for a real 3-element vector of finite values
function TF = isvec3 (V)

  TF = isnumeric (V) && isreal (V) && isvector (V) && numel (V) == 3 ...
       && all (isfinite (V));

endfunction

## The x axis DXF gives a plane with normal N, its arbitrary axis algorithm
function X = arbitraryaxis (N)

  if (abs (N(1)) < 1 / 64 && abs (N(2)) < 1 / 64)
    X = cross ([0, 1, 0], N);
  else
    X = cross ([0, 0, 1], N);
  endif
  X /= norm (X);

endfunction

## A row vector as "[a, b, c]"
function s = vecstr (v)

  s = sprintf ("[%s]", strjoin (arrayfun (@(x) sprintf ("%g", x), v, ...
                                          'UniformOutput', false), ", "));

endfunction

%!test
%! U = geom.UCS ();
%! assert_equal (U.Origin, [0, 0, 0]);
%! assert_equal (U.XAxis, [1, 0, 0]);
%! assert_equal (U.YAxis, [0, 1, 0]);
%! assert_equal (U.Normal, [0, 0, 1]);

%!test  # a normal alone follows DXF's arbitrary axis algorithm
%! U = geom.UCS ([0, 0, -2], [0, 0, 0]);
%! assert_equal (U.Normal, [0, 0, -1]);
%! assert_equal (U.XAxis, [-1, 0, 0]);
%! assert_equal (U.YAxis, [0, 1, 0]);

%!test  # a sloping plane keeps its x axis level
%! U = geom.UCS ([0, -3, 4], [0, 0, 10]);
%! assert_equal (U.Origin, [0, 0, 10]);
%! assert_equal (U.Normal, [0, -0.6, 0.8], 1e-15);
%! assert_equal (U.XAxis, [1, 0, 0], 1e-15);
%! assert_equal (U.YAxis, [0, 0.8, 0.6], 1e-15);

%!test  # walls: x level and to the right seen from outside, y up
%! U = geom.UCS ([1, 0, 0], [5, 0, 2]);
%! assert_equal ([U.XAxis; U.YAxis], [0, 1, 0; 0, 0, 1]);
%! U = geom.UCS ([0, 1, 0], [0, 0, 0]);
%! assert_equal ([U.XAxis; U.YAxis], [-1, 0, 0; 0, 0, 1]);

%!test  # the x axis towards a point, projected onto the plane
%! U = geom.UCS ([0, -1, 0], [0, 0, 0], [80, -7, 0]);
%! assert_equal ([U.XAxis; U.YAxis], [1, 0, 0; 0, 0, 1]);
%! U = geom.UCS ([0, 0, 1], [10, 10, 0], [10, 0, 5]);
%! assert_equal (U.XAxis, [0, -1, 0]);
%! assert_equal (U.YAxis, [1, 0, 0]);

%!test  # three points: origin, +x, and the +y side
%! U = geom.UCS.threepoint ([1, 1, 0], [5, 1, 0], [3, -7, 0]);
%! assert_equal (U.Origin, [1, 1, 0]);
%! assert_equal (U.XAxis, [1, 0, 0]);
%! assert_equal (U.YAxis, [0, -1, 0]);
%! assert_equal (U.Normal, [0, 0, -1]);

%!test  # three points on a tilted plane
%! U = geom.UCS.threepoint ([0, 0, 0], [0, 3, 4], [1, 0, 0]);
%! assert_equal (U.XAxis, [0, 0.6, 0.8], 1e-15);
%! assert_equal (U.YAxis, [1, 0, 0], 1e-15);

%!test  # world and local coordinates are each other's inverse
%! U = geom.UCS ([1, 1, 1], [10, 20, 30], [11, 19, 30]);
%! P = [0, 0, 0; 1, 2, 0; -3, 4, 5];
%! W = toworld (U, P);
%! assert_equal (W(1,:), [10, 20, 30], 1e-12);
%! assert_equal (tolocal (U, W), P, 1e-12);
%! assert_equal (toworld (U, [1, 2]), W(2,:), 1e-12);

%!test  # the same system, and the same plane with another x axis
%! U = geom.UCS ([0, 0, 1], [0, 0, 5]);
%! assert_equal (U == geom.UCS ([0, 0, 2], [0, 0, 5]), true);
%! assert_equal (U == geom.UCS ([0, 0, 1], [0, 0, 5], [0, 1, 5]), false);

%!error<geom.UCS.eq: both operands must be geom.UCS objects.> ...
%! geom.UCS () == 1

%!error<geom.UCS: V must be a viewer to pick in, such as a solid.Viewer.> ...
%! geom.UCS ([0, 0, 1])
%!error<geom.UCS: V must be a viewer to pick in, such as a solid.Viewer.> ...
%! geom.UCS (geom.UCS ())
%!error<geom.UCS: NORMAL must be a nonzero real 3-element vector of finite values.> ...
%! geom.UCS ([0, 0, 0], [0, 0, 0])
%!error<geom.UCS: NORMAL must be a nonzero real 3-element vector of finite values.> ...
%! geom.UCS ([0, 1], [0, 0, 0])
%!error<geom.UCS: ORIGIN must be a real 3-element vector of finite values.> ...
%! geom.UCS ([0, 0, 1], [0, 0])
%!error<geom.UCS: XPOINT must be a real 3-element vector of finite values.> ...
%! geom.UCS ([0, 0, 1], [0, 0, 0], [NaN, 0, 0])
%!error<geom.UCS: XPOINT must not lie on the normal through ORIGIN.> ...
%! geom.UCS ([0, 0, 1], [1, 1, 0], [1, 1, 5])
%!error<geom.UCS.threepoint: invalid number of input arguments.> ...
%! geom.UCS.threepoint ([0, 0, 0], [1, 0, 0])
%!error<geom.UCS.threepoint: P1, P2 and P3 must be real 3-element vectors of finite values.> ...
%! geom.UCS.threepoint ([0, 0, 0], [1, 0], [0, 1, 0])
%!error<geom.UCS.threepoint: P1, P2 and P3 must not lie on one line.> ...
%! geom.UCS.threepoint ([0, 0, 0], [1, 0, 0], [5, 0, 0])
%!error<geom.UCS.threepoint: P1, P2 and P3 must not lie on one line.> ...
%! geom.UCS.threepoint ([0, 0, 0], [0, 0, 0], [5, 1, 0])
%!error<geom.UCS.toworld: invalid number of input arguments.> toworld (geom.UCS ())
%!error<geom.UCS.toworld: P must be an N-by-2 or N-by-3 real matrix of finite values.> ...
%! toworld (geom.UCS (), [1, 2, 3, 4])
%!error<geom.UCS.tolocal: invalid number of input arguments.> tolocal (geom.UCS ())
%!error<geom.UCS.tolocal: W must be an N-by-3 real matrix of finite values.> ...
%! tolocal (geom.UCS (), [1, 2])
