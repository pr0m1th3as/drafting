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

classdef Spline
  ## -*- texinfo -*-
  ## @deftp {drafting} geom.Spline
  ##
  ## A smooth curve through points.
  ##
  ## A @code{geom.Spline} is an open cubic spline that passes through each of
  ## its points in turn, smooth all along: its direction and its curvature
  ## change without a jump.  It is the curve of a grip, a curved rib or a
  ## channel that follows a surface, and @code{solid.sweep} carries a section
  ## along it as one segment of a @code{geom.Path}.
  ##
  ## The curve is parametrised by the distance from point to point.  Either
  ## end may be given a direction; an end left free is shaped as Octave's
  ## @code{spline} shapes it, the first and last two pieces each one cubic,
  ## so a spline through points of a parabola is that parabola.  When a
  ## spline is joined into a path, its free ends take the direction of what
  ## they meet.
  ##
  ## The points are coordinates in the spline's @code{geom.UCS}, the world
  ## coordinate system by default, and assigning another UCS moves the
  ## spline, its shape unchanged in its own coordinates.  A spline whose
  ## points all have @math{z = 0} lies in the plane of its UCS.
  ##
  ## A @code{geom.Spline} is a value: every change makes a new one.
  ##
  ## @seealso{geom.Path, geom.Polyline, solid.sweep, spline}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} Points
    ##
    ## Points the spline passes through
    ##
    ## The points as an @math{M}-by-3 matrix @code{[@var{x}, @var{y},
    ## @var{z}]}, in millimetres in the spline's UCS, in the order the spline
    ## passes through them.
    ##
    ## @end deftp
    Points = zeros (0, 3);

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} Tangents
    ##
    ## Directions at the ends
    ##
    ## A 2-by-3 matrix whose rows are the unit directions of the spline at its
    ## first and its last point, or @code{NaN} for an end left free.
    ##
    ## @end deftp
    Tangents = NaN (2, 3);

  endproperties

  properties

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} UCS
    ##
    ## Coordinate system of the points
    ##
    ## The @code{geom.UCS} the points are coordinates in, the world coordinate
    ## system by default.  Assigning another moves the spline onto it, its
    ## shape unchanged in its own coordinates.
    ##
    ## @end deftp
    UCS = geom.UCS ();

  endproperties

  methods (Hidden)

    function disp (this)

      free = {"given", "free"};
      printf ("  geom.Spline: %d points, start %s, end %s\n", ...
              rows (this.Points), free{isnan (this.Tangents(1,1)) + 1}, ...
              free{isnan (this.Tangents(2,1)) + 1});

    endfunction

    ## The parameter of each point, the distance from point to point, and the
    ## derivative of the curve there with respect to it
    function [t, m] = __hermite__ (this)

      V = this.Points;
      T = this.Tangents;
      n = rows (V);
      h = sqrt (sum (diff (V) .^ 2, 2));
      t = [0; cumsum(h)];
      d = diff (V) ./ h;
      free = isnan (T(:,1));
      if (n == 2)
        m = [d; d];
        if (! free(1) && ! free(2))
          m = T;
        elseif (! free(1))
          m = [T(1,:); 2 * d - T(1,:)];
        elseif (! free(2))
          m = [2 * d - T(2,:); T(2,:)];
        endif
        return;
      endif
      if (n == 3 && all (free))
        ## Free at both ends through three points: the parabola through them
        c = (d(2,:) - d(1,:)) / (h(1) + h(2));
        m = [d(1,:) - h(1) * c; d(1,:) + h(1) * c; d(2,:) + h(2) * c];
        return;
      endif

      ## The second derivative continuous at every inner point
      A = zeros (n);
      b = zeros (n, 3);
      for i = 2:n-1
        A(i,i-1:i+1) = [h(i), 2 * (h(i-1) + h(i)), h(i-1)];
        b(i,:) = 3 * (h(i) * d(i-1,:) + h(i-1) * d(i,:));
      endfor

      ## Either end given its direction, or one cubic over its last two pieces
      if (free(1))
        A(1,1:2) = [h(2), h(1) + h(2)];
        b(1,:) = ((h(1) + 2 * (h(1) + h(2))) * h(2) * d(1,:) ...
                  + h(1) ^ 2 * d(2,:)) / (h(1) + h(2));
      else
        A(1,1) = 1;
        b(1,:) = T(1,:);
      endif
      if (free(2))
        A(n,n-1:n) = [h(n-1) + h(n-2), h(n-2)];
        b(n,:) = (h(n-1) ^ 2 * d(n-2,:) ...
                  + (2 * (h(n-2) + h(n-1)) + h(n-1)) * h(n-2) * d(n-1,:)) ...
                 / (h(n-2) + h(n-1));
      else
        A(n,n) = 1;
        b(n,:) = T(2,:);
      endif
      m = A \ b;

    endfunction

    ## The control points of the spline as cubic Bezier pieces, end to end,
    ## and the parameters where the pieces meet
    function [P, t] = __bezier__ (this)

      V = this.Points;
      [t, m] = __hermite__ (this);
      h = diff (t);
      n = rows (V);
      P = zeros (3 * (n - 1) + 1, 3);
      P(1:3:end,:) = V;
      P(2:3:end,:) = V(1:n-1,:) + h .* m(1:n-1,:) / 3;
      P(3:3:end,:) = V(2:n,:) - h .* m(2:n,:) / 3;

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Spline} {@var{SP} =} geom.Spline (@var{V})
    ## @deftypefnx {geom.Spline} {@var{SP} =} geom.Spline (@var{V}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Make a spline.
    ##
    ## @code{@var{SP} = geom.Spline (@var{V})} makes the spline through the
    ## points given as rows of @var{V}, an @math{M}-by-3 matrix in
    ## millimetres, or an @math{M}-by-2 matrix of points in the plane of the
    ## UCS, with at least two rows.  Through two points with both ends free,
    ## the spline is the straight line between them.
    ##
    ## Name/Value pairs:
    ##
    ## @table @asis
    ## @item @qcode{'Tangents'}
    ## A 2-by-3 matrix @code{[@var{T1}; @var{T2}]} of the directions at the
    ## first and the last point, of any nonzero length; a row of @code{NaN}
    ## leaves that end free.  Both ends are free by default.
    ##
    ## @item @qcode{'UCS'}
    ## The @code{geom.UCS} the points are coordinates in, the world coordinate
    ## system by default.
    ## @end table
    ##
    ## @example
    ## @group
    ## ## The centre line of a grip, leaving straight up and arriving level
    ## SP = geom.Spline ([0, 0, 0; 10, 0, 30; 40, 0, 50; 80, 0, 50], ...
    ##                   'Tangents', [0, 0, 1; 1, 0, 0]);
    ## @end group
    ## @end example
    ##
    ## @end deftypefn
    function this = Spline (V, varargin)

      ## Input validation
      if (nargin < 1)
        error ("geom.Spline: invalid number of input arguments.");
      endif
      if (! isnumeric (V) || ! isreal (V) || ! ismatrix (V) ...
          || ! any (columns (V) == [2, 3]) || rows (V) < 2 ...
          || ! all (isfinite (V(:))))
        error (strcat ("geom.Spline: V must be an M-by-2 or M-by-3 real", ...
                       " matrix of finite values with at least two rows."));
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("geom.Spline: Name/Value arguments must come in pairs.");
      endif
      opt = struct ('Tangents', NaN (2, 3), 'UCS', geom.UCS ());
      for k = 1:2:numel (varargin)
        name = varargin{k};
        if (! ischar (name) || ! isrow (name) ...
            || ! any (strcmp (name, fieldnames (opt))))
          error ("geom.Spline: unknown parameter.");
        endif
        opt.(name) = varargin{k+1};
      endfor
      T = opt.Tangents;
      if (! isnumeric (T) || ! isreal (T) || ! isequal (size (T), [2, 3]))
        T = [];
      else
        T = double (T);
        free = all (isnan (T), 2);
        given = all (isfinite (T), 2) & any (T != 0, 2);
        if (! all (free | given))
          T = [];
        endif
      endif
      if (isempty (T))
        error (strcat ("geom.Spline: Tangents must be a 2-by-3 real", ...
                       " matrix, each row a nonzero direction or NaN."));
      endif
      if (! isa (opt.UCS, 'geom.UCS') || ! isscalar (opt.UCS))
        error ("geom.Spline: UCS must be a geom.UCS object.");
      endif

      V = double (V);
      if (columns (V) == 2)
        V(:,3) = 0;
      endif
      if (any (all (diff (V) == 0, 2)))
        error ("geom.Spline: V must not repeat a point consecutively.");
      endif

      this.Points = V;
      this.Tangents = T ./ sqrt (sum (T .^ 2, 2));
      this.UCS = opt.UCS;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Spline} {@var{L} =} length (@var{SP})
    ##
    ## The length of a spline.
    ##
    ## @code{@var{L} = length (@var{SP})} returns the length of the spline
    ## @var{SP} along the curve, in millimetres.
    ##
    ## @end deftypefn
    function L = length (this)

      [t, m] = __hermite__ (this);
      V = this.Points;
      L = 0;
      for i = 1:rows (V) - 1
        L += integral (@(s) speed (V(i:i+1,:), m(i:i+1,:), t(i+1) - t(i), ...
                                    s), 0, 1, 'RelTol', 1e-13, ...
                       'AbsTol', 1e-14);
      endfor

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Spline} {@var{P} =} points (@var{SP}, @var{N})
    ##
    ## Points along a spline.
    ##
    ## @code{@var{P} = points (@var{SP}, @var{N})} returns @var{N} points
    ## along the spline @var{SP}, from its first point to its last, as an
    ## @var{N}-by-3 matrix of coordinates in its UCS.  They are spaced evenly
    ## in the spline's parameter, the distance from point to point, so they
    ## include every point the spline passes through only when @var{N} falls
    ## on them.  Convert them to world coordinates with
    ## @code{geom.UCS.toworld}.
    ##
    ## @end deftypefn
    function P = points (this, N)

      ## Input validation
      if (nargin != 2)
        error ("geom.Spline.points: invalid number of input arguments.");
      endif
      if (! isnumeric (N) || ! isreal (N) || ! isscalar (N) || N != fix (N) ...
          || N < 2)
        error ("geom.Spline.points: N must be an integer of at least 2.");
      endif

      [t, m] = __hermite__ (this);
      V = this.Points;
      s = linspace (0, t(end), double (N))';
      i = min (max (lookup (t, s), 1), rows (V) - 1);
      h = t(i+1) - t(i);
      u = (s - t(i)) ./ h;
      P = (2 * u .^ 3 - 3 * u .^ 2 + 1) .* V(i,:) ...
          + (u .^ 3 - 2 * u .^ 2 + u) .* h .* m(i,:) ...
          + (-2 * u .^ 3 + 3 * u .^ 2) .* V(i+1,:) ...
          + (u .^ 3 - u .^ 2) .* h .* m(i+1,:);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Spline} {@var{P} =} join (@var{SP}, @var{P2}, @dots{})
    ## @deftypefnx {geom.Spline} {@var{P} =} join (@dots{}, @qcode{'Tangent'}, @var{TF})
    ##
    ## Put a spline and paths end to end.
    ##
    ## @code{@var{P} = join (@var{SP}, @var{P2}, @dots{})} returns the
    ## @code{geom.Path} that runs along the spline @var{SP}, then along
    ## @var{P2}, and so on, as @code{geom.Path.join} puts paths and splines
    ## end to end.
    ##
    ## @seealso{geom.Path.join}
    ## @end deftypefn
    function P = join (varargin)

      for k = 1:numel (varargin)
        if (isa (varargin{k}, 'geom.Spline'))
          varargin{k} = geom.Path (varargin{k});
        endif
      endfor
      P = join (varargin{:});

    endfunction

    function this = set.UCS (this, U)

      if (! isa (U, 'geom.UCS') || ! isscalar (U))
        error ("geom.Spline: UCS must be a geom.UCS object.");
      endif
      this.UCS = U;

    endfunction

  endmethods

endclassdef

## The speed along the piece from the point V(1,:) to V(2,:), with derivatives
## M and parameter length H, at the fractions S of the way along it
function v = speed (V, M, H, S)

  S = S(:);
  D = (6 * S .^ 2 - 6 * S) .* (V(1,:) - V(2,:)) / H ...
      + (3 * S .^ 2 - 4 * S + 1) .* M(1,:) + (3 * S .^ 2 - 2 * S) .* M(2,:);
  v = sqrt (sum (D .^ 2, 2))' * H;

endfunction

%!test
%! SP = geom.Spline ([0, 0; 10, 0; 20, 5]);
%! assert_equal (SP.Points, [0, 0, 0; 10, 0, 0; 20, 5, 0]);
%! assert_equal (SP.Tangents, NaN (2, 3));
%! assert_equal (SP.UCS, geom.UCS ());

%!test  # the same curve as Octave's spline, free ends not-a-knot
%! V = [0, 0, 0; 10, 5, 2; 20, 3, 8; 30, 10, 9; 35, 20, 4];
%! t = [0; cumsum(sqrt (sum (diff (V) .^ 2, 2)))];
%! P = points (geom.Spline (V), 41);
%! assert_equal (P, spline (t', V', linspace (0, t(end), 41))', 1e-10);

%!test  # both ends given, as Octave's spline with end slopes
%! V = [0, 0, 0; 10, 5, 2; 20, 3, 8; 30, 10, 9];
%! T = [0, 0, 1; 1, 0, 0];
%! t = [0; cumsum(sqrt (sum (diff (V) .^ 2, 2)))];
%! P = points (geom.Spline (V, 'Tangents', 2 * T), 31);
%! Q = spline (t', [T(1,:)', V', T(2,:)'], linspace (0, t(end), 31))';
%! assert_equal (P, Q, 1e-10);

%!test  # one end given, one free
%! SP = geom.Spline ([0, 0; 10, 10; 20, 0; 30, 10], ...
%!                   'Tangents', [1, 0, 0; NaN, NaN, NaN]);
%! [~, m] = __hermite__ (SP);
%! assert_equal (m(1,:), [1, 0, 0], 1e-12);
%! assert_equal (SP.Tangents(2,:), NaN (1, 3));

%!test  # through three points with free ends, the parabola through them
%! SP = geom.Spline ([-1, 1; 0, 0; 1, 1]);
%! P = points (SP, 3);
%! assert_equal (P, [-1, 1, 0; 0, 0, 0; 1, 1, 0], 1e-12);
%! assert_equal (length (SP), sqrt (5) + asinh (2) / 2, -1e-6);

%!test  # through points on a line, that line
%! SP = geom.Spline ([0, 0, 0; 1, 2, 2; 4, 8, 8; 5, 10, 10]);
%! assert_equal (length (SP), 15, 1e-12);
%! assert_equal (points (SP, 4)(:,2), [0; 10/3; 20/3; 10], 1e-12);

%!test  # two points with free ends, a straight line
%! assert_equal (length (geom.Spline ([0, 0, 0; 3, 4, 0])), 5, 1e-12);

%!test  # close to a circle through points on it
%! a = linspace (0, pi, 13)';
%! SP = geom.Spline ([10 * cos(a), 10 * sin(a)], ...
%!                   'Tangents', [0, 1, 0; 0, -1, 0]);
%! assert_equal (length (SP), 10 * pi, -1e-4);
%! P = points (SP, 200);
%! assert_equal (sqrt (sum (P .^ 2, 2)), 10 * ones (200, 1), 1e-3);

%!test  # points in a UCS; assigning another moves the spline
%! U = geom.UCS ([1, 0, 0], [5, 5, 5]);
%! SP = geom.Spline ([0, 0; 10, 5; 20, 0], 'UCS', U);
%! assert_equal (SP.UCS, U);
%! SP.UCS = geom.UCS ();
%! assert_equal (SP.Points, [0, 0, 0; 10, 5, 0; 20, 0, 0]);

%!test  # directions kept as unit vectors
%! SP = geom.Spline ([0, 0; 1, 0], 'Tangents', [3, 4, 0; NaN, NaN, NaN]);
%! assert_equal (SP.Tangents, [0.6, 0.8, 0; NaN, NaN, NaN]);

%!test  # joined to a path, the spline first
%! P = join (geom.Spline ([0, 0, 0; 5, 0, 5; 10, 0, 10]), ...
%!           geom.Path ([10, 0, 10; 10, 0, 20]));
%! assert_equal (class (P), 'geom.Path');
%! assert_equal (P.Splines{1}.Tangents(2,:), [0, 0, 1]);

%!error<geom.Spline: invalid number of input arguments.> geom.Spline ()
%!error<geom.Spline: V must be an M-by-2 or M-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Spline ([0, 0, 0])
%!error<geom.Spline: V must be an M-by-2 or M-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Spline ([0, 0, 0, 0; 1, 0, 0, 0])
%!error<geom.Spline: V must be an M-by-2 or M-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Spline ([0, 0; NaN, 1])
%!error<geom.Spline: Name/Value arguments must come in pairs.> ...
%! geom.Spline ([0, 0; 1, 0], 'Tangents')
%!error<geom.Spline: unknown parameter.> ...
%! geom.Spline ([0, 0; 1, 0], 'Closed', true)
%!error<geom.Spline: Tangents must be a 2-by-3 real matrix, each row a nonzero direction or NaN.> ...
%! geom.Spline ([0, 0; 1, 0], 'Tangents', [1, 0, 0])
%!error<geom.Spline: Tangents must be a 2-by-3 real matrix, each row a nonzero direction or NaN.> ...
%! geom.Spline ([0, 0; 1, 0], 'Tangents', [0, 0, 0; 1, 0, 0])
%!error<geom.Spline: Tangents must be a 2-by-3 real matrix, each row a nonzero direction or NaN.> ...
%! geom.Spline ([0, 0; 1, 0], 'Tangents', [1, NaN, 0; 1, 0, 0])
%!error<geom.Spline: UCS must be a geom.UCS object.> ...
%! geom.Spline ([0, 0; 1, 0], 'UCS', [0, 0, 1])
%!error<geom.Spline: UCS must be a geom.UCS object.>
%! SP = geom.Spline ([0, 0; 1, 0]);
%! SP.UCS = 1;
%!error<geom.Spline: V must not repeat a point consecutively.> ...
%! geom.Spline ([0, 0; 1, 0; 1, 0])
%!error<geom.Spline.points: invalid number of input arguments.> ...
%! points (geom.Spline ([0, 0; 1, 0]))
%!error<geom.Spline.points: N must be an integer of at least 2.> ...
%! points (geom.Spline ([0, 0; 1, 0]), 1)
%!error<geom.Spline.points: N must be an integer of at least 2.> ...
%! points (geom.Spline ([0, 0; 1, 0]), 2.5)
