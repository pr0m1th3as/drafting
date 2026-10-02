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

classdef Polyline
  ## -*- texinfo -*-
  ## @deftp {drafting} geom.Polyline
  ##
  ## A polyline of straight segments and circular arcs, lying in a plane.
  ##
  ## A @code{geom.Polyline} is the package's one representation of an outline
  ## that may carry arcs, the polyline of a DXF file.  Its vertices are rows
  ## @code{[@var{x}, @var{y}, @var{bulge}]} in its own plane, and it is open or
  ## closed.  It may cross itself: it is a line in a drawing.  An area to make
  ## a solid from is a @code{geom.Region}, built from closed polylines.
  ##
  ## The bulge of a vertex turns the segment leaving it into a circular arc.
  ## It is the tangent of a quarter of the arc's included angle: zero is a
  ## straight segment, 1 a semicircle and 0.4142 a quarter circle.  The height
  ## of the arc above the middle of its chord is the bulge times half the
  ## chord.  A positive bulge is an arc running anticlockwise from the vertex
  ## to the next, which puts it to the right of the direction of travel; a
  ## negative one runs clockwise, to the left.  So a polyline from
  ## @code{[0, 0]} to @code{[20, 0]} with a bulge of 1 dips @emph{below} the
  ## chord, to @math{y = -10}.  Two vertices with a bulge of 1 each make a
  ## whole circle.
  ##
  ## The plane is a user coordinate system, an origin, an @math{x} axis and a
  ## normal, with the @math{y} axis the normal crossed with the @math{x} axis.
  ## The vertices are coordinates in that plane, so the same outline can be
  ## laid on any plane, as a CAD program's user coordinate system lays a sketch
  ## on a face.  By default it is the @math{xy} plane.
  ##
  ## A @code{geom.Polyline} is a value: it is made by its constructor and
  ## never changes.
  ##
  ## @seealso{geom.Region, draw.Drawing.polyline}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {geom.Polyline} {property} Vertices
    ##
    ## Vertices and bulges
    ##
    ## The vertices as an @math{N}-by-3 matrix @code{[@var{x}, @var{y},
    ## @var{bulge}]}, in millimetres in the polyline's plane.
    ##
    ## @end deftp
    Vertices = zeros (0, 3);

    ## -*- texinfo -*-
    ## @deftp {geom.Polyline} {property} Closed
    ##
    ## Closed flag
    ##
    ## @code{true} when the last vertex is joined back to the first.
    ##
    ## @end deftp
    Closed = false;

    ## -*- texinfo -*-
    ## @deftp {geom.Polyline} {property} Origin
    ##
    ## Origin of the plane
    ##
    ## The origin of the polyline's plane, a 1-by-3 point in model
    ## coordinates.
    ##
    ## @end deftp
    Origin = [0, 0, 0];

    ## -*- texinfo -*-
    ## @deftp {geom.Polyline} {property} XAxis
    ##
    ## x axis of the plane
    ##
    ## The unit @math{x} axis of the polyline's plane.
    ##
    ## @end deftp
    XAxis = [1, 0, 0];

    ## -*- texinfo -*-
    ## @deftp {geom.Polyline} {property} Normal
    ##
    ## Normal of the plane
    ##
    ## The unit normal of the polyline's plane.
    ##
    ## @end deftp
    Normal = [0, 0, 1];

  endproperties

  properties (Dependent)

    ## -*- texinfo -*-
    ## @deftp {geom.Polyline} {property} YAxis
    ##
    ## y axis of the plane
    ##
    ## The unit @math{y} axis of the polyline's plane, the normal crossed with
    ## the @math{x} axis.
    ##
    ## @end deftp
    YAxis

  endproperties

  methods (Hidden)

    function disp (this)

      if (this.Closed)
        c = "closed";
      else
        c = "open";
      endif
      printf ("  geom.Polyline: %s, %d vertices, %d arcs\n", c, ...
              rows (this.Vertices), nnz (this.Vertices(:,3)));

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Polyline} {@var{PL} =} geom.Polyline (@var{P})
    ## @deftypefnx {geom.Polyline} {@var{PL} =} geom.Polyline (@var{P}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Make a polyline.
    ##
    ## @code{@var{PL} = geom.Polyline (@var{P})} makes an open polyline in the
    ## @math{xy} plane through the vertices given as rows of @var{P}, in
    ## millimetres.  @var{P} is an @math{N}-by-3 matrix @code{[@var{x},
    ## @var{y}, @var{bulge}]}, or an @math{N}-by-2 matrix of vertices joined by
    ## straight segments, with at least two rows.
    ##
    ## Name/Value pairs:
    ##
    ## @table @asis
    ## @item @qcode{'Closed'}
    ## @code{true} to join the last vertex back to the first, @code{false} by
    ## default.  A closed polyline must @strong{not} repeat its first vertex at
    ## the end; a repeat is accepted and dropped.  An open polyline has no
    ## segment leaving its last vertex, so the bulge there must be zero.
    ##
    ## @item @qcode{'Origin'}
    ## The point, in model coordinates, at which the polyline's plane has its
    ## origin; @code{[0, 0, 0]} by default.
    ##
    ## @item @qcode{'Normal'}
    ## The direction square to the plane, @code{[0, 0, 1]} by default.
    ##
    ## @item @qcode{'XAxis'}
    ## The direction of the plane's @math{x} axis, square to the normal.  When
    ## it is not given it follows from the normal by DXF's arbitrary axis
    ## algorithm, so a plane named by its normal alone means the same here as
    ## in a DXF file: the @math{x} axis is horizontal, along the model's
    ## @math{x} axis whenever the normal allows it.
    ## @end table
    ##
    ## @example
    ## @group
    ## ## A slot 40 between centres and 12 wide, as one closed polyline
    ## PL = geom.Polyline ([0, -6, 0; 40, -6, 1; 40, 6, 0; 0, 6, 1], ...
    ##                     'Closed', true);
    ## @end group
    ## @end example
    ##
    ## @end deftypefn
    function this = Polyline (P, varargin)

      ## Input validation
      if (nargin < 1)
        error ("geom.Polyline: invalid number of input arguments.");
      endif
      if (! isnumeric (P) || ! isreal (P) || ! ismatrix (P) ...
          || ! any (columns (P) == [2, 3]) || rows (P) < 2 ...
          || ! all (isfinite (P(:))))
        error (strcat ("geom.Polyline: P must be an N-by-2 or N-by-3 real", ...
                       " matrix of finite values with at least two rows."));
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("geom.Polyline: Name/Value arguments must come in pairs.");
      endif
      opt = struct ('Closed', false, 'Origin', [0, 0, 0], ...
                    'Normal', [0, 0, 1], 'XAxis', []);
      for k = 1:2:numel (varargin)
        name = varargin{k};
        if (! ischar (name) || ! isrow (name) ...
            || ! any (strcmp (name, fieldnames (opt))))
          error ("geom.Polyline: unknown parameter.");
        endif
        opt.(name) = varargin{k+1};
      endfor
      if (! (islogical (opt.Closed) || isnumeric (opt.Closed)) ...
          || ! isscalar (opt.Closed) || ! any (opt.Closed == [0, 1]))
        error ("geom.Polyline: Closed must be a logical scalar.");
      endif
      if (! isvec3 (opt.Origin))
        error (strcat ("geom.Polyline: Origin must be a real 3-element", ...
                       " vector of finite values."));
      endif
      if (! isvec3 (opt.Normal) || all (opt.Normal == 0))
        error (strcat ("geom.Polyline: Normal must be a nonzero real", ...
                       " 3-element vector of finite values."));
      endif
      N = double (opt.Normal(:)') / norm (opt.Normal);
      if (isempty (opt.XAxis))
        X = arbitraryaxis (N);
      else
        if (! isvec3 (opt.XAxis) || all (opt.XAxis == 0))
          error (strcat ("geom.Polyline: XAxis must be a nonzero real", ...
                         " 3-element vector of finite values."));
        endif
        X = double (opt.XAxis(:)') / norm (opt.XAxis);
        if (abs (X * N') > 1e-9)
          error ("geom.Polyline: XAxis must be perpendicular to Normal.");
        endif
      endif

      P = double (P);
      if (columns (P) == 2)
        P(:,3) = 0;
      endif
      closed = logical (opt.Closed);

      ## Accept an explicitly closed polyline and drop the repeat
      if (closed && rows (P) > 2 && isequal (P(1,1:2), P(end,1:2)))
        P(end,:) = [];
      endif
      if (closed)
        D = P([2:end, 1],1:2) - P(:,1:2);
      else
        D = diff (P(:,1:2));
      endif
      if (any (all (D == 0, 2)))
        error ("geom.Polyline: P must not repeat a vertex consecutively.");
      endif
      if (! closed && P(end,3) != 0)
        error (strcat ("geom.Polyline: the last vertex of an open polyline", ...
                       " must have a zero bulge."));
      endif

      this.Vertices = P;
      this.Closed = closed;
      this.Origin = double (opt.Origin(:)');
      this.XAxis = X;
      this.Normal = N;

    endfunction

    function Y = get.YAxis (this)

      Y = cross (this.Normal, this.XAxis);

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

%!test
%! PL = geom.Polyline ([0, 0; 10, 0; 10, 5]);
%! assert_equal (PL.Vertices, [0, 0, 0; 10, 0, 0; 10, 5, 0]);
%! assert_equal (PL.Closed, false);
%! assert_equal (PL.Origin, [0, 0, 0]);
%! assert_equal (PL.XAxis, [1, 0, 0]);
%! assert_equal (PL.YAxis, [0, 1, 0]);
%! assert_equal (PL.Normal, [0, 0, 1]);

%!test  # bulges kept, a repeated first vertex dropped
%! PL = geom.Polyline ([0, -6, 0; 40, -6, 1; 40, 6, 0; 0, 6, 1; 0, -6, 0], ...
%!                     'Closed', true);
%! assert_equal (PL.Vertices, [0, -6, 0; 40, -6, 1; 40, 6, 0; 0, 6, 1]);
%! assert_equal (PL.Closed, true);

%!test  # a circle from two vertices
%! PL = geom.Polyline ([0, 0, 1; 10, 0, 1], 'Closed', true);
%! assert_equal (rows (PL.Vertices), 2);

%!test  # an open polyline may cross itself
%! PL = geom.Polyline ([0, 0; 10, 10; 10, 0; 0, 10]);
%! assert_equal (rows (PL.Vertices), 4);

%!test  # a plane named by its normal follows DXF's arbitrary axis algorithm
%! PL = geom.Polyline ([0, 0; 1, 0], 'Normal', [0, 0, -2]);
%! assert_equal (PL.Normal, [0, 0, -1]);
%! assert_equal (PL.XAxis, [-1, 0, 0]);
%! assert_equal (PL.YAxis, [0, 1, 0]);

%!test  # a sloping plane keeps its x axis level
%! PL = geom.Polyline ([0, 0; 1, 0], 'Normal', [0, -3, 4]);
%! assert_equal (PL.Normal, [0, -0.6, 0.8], 1e-15);
%! assert_equal (PL.XAxis, [1, 0, 0], 1e-15);
%! assert_equal (PL.YAxis, [0, 0.8, 0.6], 1e-15);

%!test  # a vertical plane facing x has its x axis along y
%! PL = geom.Polyline ([0, 0; 1, 0], 'Normal', [1, 0, 0], ...
%!                     'Origin', [5, 0, 2]);
%! assert_equal (PL.XAxis, [0, 1, 0]);
%! assert_equal (PL.YAxis, [0, 0, 1]);
%! assert_equal (PL.Origin, [5, 0, 2]);

%!test  # an x axis given explicitly
%! PL = geom.Polyline ([0, 0; 1, 0], 'Normal', [0, -1, 0], ...
%!                     'XAxis', [2, 0, 0]);
%! assert_equal (PL.XAxis, [1, 0, 0]);
%! assert_equal (PL.YAxis, [0, 0, 1]);

%!error<geom.Polyline: invalid number of input arguments.> geom.Polyline ()
%!error<geom.Polyline: P must be an N-by-2 or N-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Polyline ([0, 0])
%!error<geom.Polyline: P must be an N-by-2 or N-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Polyline ([0, 0, 0, 0; 1, 0, 0, 0])
%!error<geom.Polyline: P must be an N-by-2 or N-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Polyline ([0, 0; 1, NaN])
%!error<geom.Polyline: P must be an N-by-2 or N-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Polyline ({[0, 0; 1, 0]})
%!error<geom.Polyline: Name/Value arguments must come in pairs.> ...
%! geom.Polyline ([0, 0; 1, 0], 'Closed')
%!error<geom.Polyline: unknown parameter.> ...
%! geom.Polyline ([0, 0; 1, 0], 'Bulge', [0, 0])
%!error<geom.Polyline: Closed must be a logical scalar.> ...
%! geom.Polyline ([0, 0; 1, 0], 'Closed', 2)
%!error<geom.Polyline: Origin must be a real 3-element vector of finite values.> ...
%! geom.Polyline ([0, 0; 1, 0], 'Origin', [0, 0])
%!error<geom.Polyline: Normal must be a nonzero real 3-element vector of finite values.> ...
%! geom.Polyline ([0, 0; 1, 0], 'Normal', [0, 0, 0])
%!error<geom.Polyline: XAxis must be a nonzero real 3-element vector of finite values.> ...
%! geom.Polyline ([0, 0; 1, 0], 'XAxis', [Inf, 0, 0])
%!error<geom.Polyline: XAxis must be perpendicular to Normal.> ...
%! geom.Polyline ([0, 0; 1, 0], 'XAxis', [1, 0, 1])
%!error<geom.Polyline: P must not repeat a vertex consecutively.> ...
%! geom.Polyline ([0, 0; 1, 0; 1, 0; 2, 2])
%!error<geom.Polyline: P must not repeat a vertex consecutively.> ...
%! geom.Polyline ([0, 0; 0, 0], 'Closed', true)
%!error<geom.Polyline: the last vertex of an open polyline must have a zero bulge.> ...
%! geom.Polyline ([0, 0, 0; 10, 0, 1])
