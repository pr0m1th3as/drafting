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

classdef Path
  ## -*- texinfo -*-
  ## @deftp {drafting} geom.Path
  ##
  ## A path of straight segments and circular arcs in three dimensions.
  ##
  ## A @code{geom.Path} is the route a section is swept along by
  ## @code{solid.sweep}: a pipe run, a bent bar or the centre line of a frame.
  ## It is open or closed and, unlike a @code{geom.Polyline}, need not lie in
  ## one plane.
  ##
  ## The vertices are coordinates in the path's @code{geom.UCS}, the world
  ## coordinate system by default, so the same path can be laid anywhere, as a
  ## polyline is laid on a plane.  Assigning another UCS moves the path, its
  ## shape unchanged in its own coordinates.
  ##
  ## An arc is kept by the point half way along it, which fixes its plane and
  ## its radius; a bulge, as a polyline keeps, would leave the plane of an arc
  ## undecided in three dimensions.  Arcs come from rounding corners with
  ## @code{geom.Path.fillet}, from a polyline's bulges, or from three points
  ## with @code{geom.Path.arc}, and pieces are put end to end with
  ## @code{geom.Path.join}.
  ##
  ## A @code{geom.Path} is a value: every change makes a new one.
  ##
  ## @seealso{solid.sweep, geom.Polyline, geom.Region, geom.UCS}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {geom.Path} {property} Vertices
    ##
    ## Vertices
    ##
    ## The vertices as an @math{M}-by-3 matrix @code{[@var{x}, @var{y},
    ## @var{z}]}, in millimetres in the path's UCS.
    ##
    ## @end deftp
    Vertices = zeros (0, 3);

    ## -*- texinfo -*-
    ## @deftp {geom.Path} {property} Midpoints
    ##
    ## Midpoints of the arcs
    ##
    ## An @math{M}-by-3 matrix whose row @math{i} is the point half way along
    ## the arc leaving vertex @math{i}, or @code{NaN} where the segment leaving
    ## it is straight or where no segment leaves it, at the end of an open
    ## path.  The points are in the path's UCS.
    ##
    ## @end deftp
    Midpoints = zeros (0, 3);

    ## -*- texinfo -*-
    ## @deftp {geom.Path} {property} Closed
    ##
    ## Closed flag
    ##
    ## @code{true} when the last vertex is joined back to the first.
    ##
    ## @end deftp
    Closed = false;

  endproperties

  properties

    ## -*- texinfo -*-
    ## @deftp {geom.Path} {property} UCS
    ##
    ## Coordinate system of the vertices
    ##
    ## The @code{geom.UCS} the vertices are coordinates in, the world
    ## coordinate system by default.  Assigning another moves the path onto
    ## it, its shape unchanged in its own coordinates.
    ##
    ## @end deftp
    UCS = geom.UCS ();

  endproperties

  methods (Hidden)

    function disp (this)

      if (this.Closed)
        c = "closed";
      else
        c = "open";
      endif
      printf ("  geom.Path: %s, %d segments, %d arcs\n", c, ...
              rows (this.Vertices) - ! this.Closed, ...
              nnz (! isnan (this.Midpoints(:,1))));

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Path} {@var{P} =} geom.Path (@var{V})
    ## @deftypefnx {geom.Path} {@var{P} =} geom.Path (@var{V}, @var{Name}, @var{Value}, @dots{})
    ## @deftypefnx {geom.Path} {@var{P} =} geom.Path (@var{PL})
    ##
    ## Make a path.
    ##
    ## @code{@var{P} = geom.Path (@var{V})} makes an open path of straight
    ## segments through the points given as rows of @var{V}, an @math{M}-by-3
    ## matrix in millimetres with at least two rows.
    ##
    ## Name/Value pairs:
    ##
    ## @table @asis
    ## @item @qcode{'Closed'}
    ## @code{true} to join the last point back to the first, @code{false} by
    ## default.  A closed path must @strong{not} repeat its first point at the
    ## end; a repeat is accepted and dropped.
    ##
    ## @item @qcode{'UCS'}
    ## The @code{geom.UCS} the points are coordinates in, the world coordinate
    ## system by default.
    ## @end table
    ##
    ## @code{@var{P} = geom.Path (@var{PL})} makes the path of the
    ## @code{geom.Polyline} @var{PL}, in its UCS, open or closed as @var{PL}
    ## is, with its arcs kept exact.
    ##
    ## @example
    ## @group
    ## ## The centre line of a tube bent twice, with bends of radius 15
    ## P = geom.Path ([0, 0, 0; 0, 0, 100; 80, 0, 100; 80, 60, 100]);
    ## P = fillet (P, 15);
    ## @end group
    ## @end example
    ##
    ## @end deftypefn
    function this = Path (V, varargin)

      ## Input validation
      if (nargin < 1)
        error ("geom.Path: invalid number of input arguments.");
      endif
      if (isa (V, 'geom.Polyline'))
        if (nargin > 1)
          error ("geom.Path: invalid number of input arguments.");
        endif
        [this.Vertices, this.Midpoints] = frompolyline (V);
        this.Closed = V.Closed;
        this.UCS = V.UCS;
        return;
      endif
      if (! isnumeric (V) || ! isreal (V) || ! ismatrix (V) ...
          || columns (V) != 3 || rows (V) < 2 || ! all (isfinite (V(:))))
        error (strcat ("geom.Path: V must be an M-by-3 real matrix of", ...
                       " finite values with at least two rows."));
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("geom.Path: Name/Value arguments must come in pairs.");
      endif
      opt = struct ('Closed', false, 'UCS', geom.UCS ());
      for k = 1:2:numel (varargin)
        name = varargin{k};
        if (! ischar (name) || ! isrow (name) ...
            || ! any (strcmp (name, fieldnames (opt))))
          error ("geom.Path: unknown parameter.");
        endif
        opt.(name) = varargin{k+1};
      endfor
      if (! (islogical (opt.Closed) || isnumeric (opt.Closed)) ...
          || ! isscalar (opt.Closed) || ! any (opt.Closed == [0, 1]))
        error ("geom.Path: Closed must be a logical scalar.");
      endif
      if (! isa (opt.UCS, 'geom.UCS') || ! isscalar (opt.UCS))
        error ("geom.Path: UCS must be a geom.UCS object.");
      endif

      V = double (V);
      closed = logical (opt.Closed);

      ## Accept an explicitly closed path and drop the repeat
      if (closed && rows (V) > 2 && isequal (V(1,:), V(end,:)))
        V(end,:) = [];
      endif
      if (closed)
        D = V([2:end, 1],:) - V;
      else
        D = diff (V);
      endif
      if (any (all (D == 0, 2)))
        error ("geom.Path: V must not repeat a point consecutively.");
      endif

      this.Vertices = V;
      this.Midpoints = NaN (rows (V), 3);
      this.Closed = closed;
      this.UCS = opt.UCS;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Path} {@var{P} =} fillet (@var{P}, @var{RADIUS})
    ## @deftypefnx {geom.Path} {@var{P} =} fillet (@var{P}, @var{RADIUS}, @var{IDX})
    ##
    ## Round the corners of a path.
    ##
    ## @code{@var{P} = fillet (@var{P}, @var{RADIUS})} rounds every corner
    ## where two straight segments meet with an arc of radius @var{RADIUS}
    ## millimetres, tangent to both and in their plane, as a tube is bent: the
    ## corner vertex becomes the two points where the arc meets the segments,
    ## joined by the arc.  Corners where an arc meets a segment are left as
    ## they are, and so are the two ends of an open path.
    ##
    ## @code{@var{P} = fillet (@var{P}, @var{RADIUS}, @var{IDX})} rounds only
    ## the corners at the vertices indexed by @var{IDX}, each of which must be
    ## a corner between two straight segments.
    ##
    ## A radius too large for a corner, whose arc would run past the end of a
    ## segment or into the round of the next corner, is refused.  Rounds that
    ## use up a segment between them meet, and the segment is dropped.
    ##
    ## @seealso{geom.Polyline.fillet}
    ## @end deftypefn
    function this = fillet (this, RADIUS, IDX = [])

      ## Input validation
      if (nargin < 2)
        error ("geom.Path.fillet: invalid number of input arguments.");
      endif
      if (! isnumeric (RADIUS) || ! isreal (RADIUS) || ! isscalar (RADIUS) ...
          || ! isfinite (RADIUS) || ! (RADIUS > 0))
        error (strcat ("geom.Path.fillet: RADIUS must be a positive and", ...
                       " finite real scalar."));
      endif

      ## The corners, their neighbours and the angle the path turns there
      V = this.Vertices;
      M = this.Midpoints;
      n = rows (V);
      if (this.Closed)
        prev = [n, 1:n-1];
        next = [2:n, 1];
        ends = false (1, n);
      else
        prev = [1, 1:n-1];
        next = [2:n, n];
        ends = [true, false(1, n - 2), true];
      endif
      u = V - V(prev,:);
      v = V(next,:) - V;
      lu = sqrt (sum (u .^ 2, 2))';
      lv = sqrt (sum (v .^ 2, 2))';
      th = acos (min (max (sum (u .* v, 2)' ./ (lu .* lv), -1), 1));
      straight = isnan (M(:,1))';
      corner = ! ends & straight(prev) & straight & th > 1e-12;
      if (isempty (IDX))
        IDX = find (corner);
      else
        if (! isnumeric (IDX) || ! isreal (IDX) || ! isvector (IDX) ...
            || any (IDX != fix (IDX)) || any (IDX < 1) || any (IDX > n))
          error (strcat ("geom.Path.fillet: IDX must be a vector of", ...
                         " vertex indices of P."));
        endif
        IDX = unique (double (IDX(:)'));
        bad = IDX(! corner(IDX));
        if (! isempty (bad))
          error (strcat ("geom.Path.fillet: vertex %d is not a corner", ...
                         " between two straight segments."), bad(1));
        endif
      endif

      ## How far back along each segment the round at either end reaches
      t = zeros (1, n);
      t(IDX) = RADIUS * tan (th(IDX) / 2);
      for i = IDX
        if (t(i) + t(next(i)) > lv(i) * (1 + 1e-12) ...
            || t(i) + t(prev(i)) > lu(i) * (1 + 1e-12))
          error (strcat ("geom.Path.fillet: the round at vertex %d does", ...
                         " not fit its segments."), i);
        endif
      endfor

      ## Each rounded corner becomes the arc between its tangent points, the
      ## middle of the arc on the bisector of the corner
      W = num2cell (V, 2);
      N = num2cell (M, 2);
      for i = IDX
        a = V(i,:) - t(i) * u(i,:) / lu(i);
        b = V(i,:) + t(i) * v(i,:) / lv(i);
        d = v(i,:) / lv(i) - u(i,:) / lu(i);
        m = V(i,:) + d / norm (d) * RADIUS * (1 / cos (th(i) / 2) - 1);
        W{i} = [a; b];
        N{i} = [m; M(i,:)];
      endfor
      W = vertcat (W{:});
      N = vertcat (N{:});

      ## A straight segment that the rounds at its ends used up is dropped
      k = rows (W);
      if (this.Closed)
        L = sqrt (sum ((W([2:k, 1],:) - W) .^ 2, 2));
      else
        L = [sqrt(sum (diff (W) .^ 2, 2)); Inf];
      endif
      gone = isnan (N(:,1)) & L <= 1e-9 * max (lv);
      this.Vertices = W(! gone,:);
      this.Midpoints = N(! gone,:);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Path} {@var{P} =} join (@var{P1}, @var{P2}, @dots{})
    ##
    ## Put paths end to end.
    ##
    ## @code{@var{P} = join (@var{P1}, @var{P2}, @dots{})} returns the path
    ## that runs along @var{P1}, then @var{P2}, and so on.  Each path must be
    ## open and begin where the one before it ends.  The pieces need not meet
    ## smoothly: where they meet at an angle, the path has a corner.  When the
    ## last piece ends where the first begins, the path is closed.  The path
    ## is in the UCS of @var{P1}, the others' points carried into it.
    ##
    ## @example
    ## @group
    ## ## A hairpin: up, over the top by a half circle, and down
    ## P = join (geom.Path ([0, 0, 0; 0, 0, 50]), ...
    ##           geom.Path.arc ([0, 0, 50], [10, 0, 60], [20, 0, 50]), ...
    ##           geom.Path ([20, 0, 50; 20, 0, 0]));
    ## @end group
    ## @end example
    ##
    ## @end deftypefn
    function this = join (varargin)

      ## Input validation
      if (nargin < 2)
        error ("geom.Path.join: invalid number of input arguments.");
      endif
      for k = 1:nargin
        P = varargin{k};
        if (! isa (P, 'geom.Path') || ! isscalar (P))
          error ("geom.Path.join: every argument must be a geom.Path object.");
        endif
        if (P.Closed)
          error ("geom.Path.join: path %d is closed.", k);
        endif
      endfor

      this = varargin{1};
      V = this.Vertices;
      M = this.Midpoints;
      for k = 2:nargin
        P = varargin{k};
        [W, N] = into (P, this.UCS);
        tol = 1e-9 * max ([1, max(abs (V(:))), max(abs (W(:)))]);
        if (norm (W(1,:) - V(end,:)) > tol)
          error (strcat ("geom.Path.join: path %d does not begin where", ...
                         " path %d ends."), k, k - 1);
        endif
        M = [M(1:end-1,:); N];
        V = [V; W(2:end,:)];
      endfor

      ## A path ending where it began is closed
      tol = 1e-9 * max (1, max (abs (V(:))));
      if (rows (V) > 2 && norm (V(end,:) - V(1,:)) <= tol)
        V(end,:) = [];
        M(end,:) = [];
        this.Closed = true;
      endif
      this.Vertices = V;
      this.Midpoints = M;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Path} {@var{L} =} length (@var{P})
    ##
    ## The length of a path.
    ##
    ## @code{@var{L} = length (@var{P})} returns the length of the path
    ## @var{P} in millimetres along its arcs, including the segment that
    ## closes a closed path.
    ##
    ## @end deftypefn
    function L = length (this)

      V = this.Vertices;
      M = this.Midpoints;
      B = V([2:end, 1],:);
      if (! this.Closed)
        V(end,:) = [];
        M(end,:) = [];
        B(end,:) = [];
      endif
      c = sqrt (sum ((B - V) .^ 2, 2));
      s = sqrt (sum ((M - (V + B) / 2) .^ 2, 2));

      ## An arc's bulge, the tangent of a quarter of its angle, is its height
      ## over half its chord
      th = 4 * atan (2 * s ./ c);
      arc = ! isnan (M(:,1));
      c(arc) = c(arc) ./ (2 * sin (th(arc) / 2)) .* th(arc);
      L = sum (c);

    endfunction

  endmethods

  methods (Static)

    ## -*- texinfo -*-
    ## @deftypefn {geom.Path} {@var{P} =} geom.Path.arc (@var{P1}, @var{PM}, @var{P2})
    ##
    ## A path along a circular arc through three points.
    ##
    ## @code{@var{P} = geom.Path.arc (@var{P1}, @var{PM}, @var{P2})} returns
    ## the open path along the circular arc that starts at @var{P1}, passes
    ## through @var{PM} and ends at @var{P2}.  @var{PM} may be any point on the
    ## arc between its ends.  Each point is a 3-element vector in world
    ## coordinates, and the three must not lie on one line.  The path is in
    ## the world coordinate system, and assigning it a UCS moves it there.
    ##
    ## @seealso{geom.Path.join}
    ## @end deftypefn
    function this = arc (P1, PM, P2)

      ## Input validation
      if (nargin != 3)
        error ("geom.Path.arc: invalid number of input arguments.");
      endif
      if (! isvec3 (P1) || ! isvec3 (PM) || ! isvec3 (P2))
        error (strcat ("geom.Path.arc: P1, PM and P2 must be real", ...
                       " 3-element vectors of finite values."));
      endif
      P1 = double (P1(:)');
      PM = double (PM(:)');
      P2 = double (P2(:)');
      a = P1 - PM;
      b = P2 - PM;
      n = cross (a, b);
      if (norm (n) <= 1e-12 * max ([norm(a), norm(b), norm(a - b)]) ^ 2)
        error ("geom.Path.arc: P1, PM and P2 must not lie on one line.");
      endif

      ## The centre, and the point half way round from P1 to P2 through PM
      C = PM + cross (dot (a, a) * b - dot (b, b) * a, n) / (2 * dot (n, n));
      r = norm (P1 - C);
      x = (P1 - C) / r;
      y = cross (-n / norm (n), x);
      th = mod (atan2 (dot (P2 - C, y), dot (P2 - C, x)), 2 * pi);
      this = geom.Path ([P1; P2]);
      this.Midpoints(1,:) = C + r * (cos (th / 2) * x + sin (th / 2) * y);

    endfunction

  endmethods

  methods

    function this = set.UCS (this, U)

      if (! isa (U, 'geom.UCS') || ! isscalar (U))
        error ("geom.Path: UCS must be a geom.UCS object.");
      endif
      this.UCS = U;

    endfunction

  endmethods

endclassdef

## The vertices of the polyline PL in its UCS, and the midpoints of its arcs,
## a bulge B on the segment from p to q putting the middle of the arc B times
## half the chord to the right of it
function [V, M] = frompolyline (PL)

  P = PL.Vertices;
  n = rows (P);
  if (PL.Closed)
    Q = P([2:n, 1],1:2);
  else
    Q = P([2:n, n],1:2);
  endif
  D = Q - P(:,1:2);
  M2 = (P(:,1:2) + Q) / 2 + P(:,3) / 2 .* [D(:,2), -D(:,1)];
  V = [P(:,1:2), zeros(n, 1)];
  M = [M2, zeros(n, 1)];
  M(P(:,3) == 0,:) = NaN;

endfunction

## The vertices and midpoints of the path P as coordinates in the UCS U
function [V, M] = into (P, U)

  V = P.Vertices;
  M = P.Midpoints;
  if (! (P.UCS == U))
    arc = ! isnan (M(:,1));
    V = tolocal (U, toworld (P.UCS, V));
    M(arc,:) = tolocal (U, toworld (P.UCS, M(arc,:)));
  endif

endfunction

function TF = isvec3 (V)

  TF = isnumeric (V) && isreal (V) && isvector (V) && numel (V) == 3 ...
       && all (isfinite (V));

endfunction

%!test
%! P = geom.Path ([0, 0, 0; 10, 0, 0; 10, 5, 3]);
%! assert_equal (P.Vertices, [0, 0, 0; 10, 0, 0; 10, 5, 3]);
%! assert_equal (P.Midpoints, NaN (3, 3));
%! assert_equal (P.Closed, false);
%! assert_equal (P.UCS, geom.UCS ());
%! assert_equal (length (P), 10 + sqrt (34), 1e-12);

%!test  # closed, a repeated first point dropped, the closing segment counted
%! P = geom.Path ([0, 0, 0; 4, 0, 0; 4, 3, 0; 0, 0, 0], 'Closed', true);
%! assert_equal (rows (P.Vertices), 3);
%! assert_equal (P.Closed, true);
%! assert_equal (length (P), 12, 1e-12);

%!test  # a polyline's arcs, in its UCS
%! U = geom.UCS ([0, -1, 0], [0, 0, 5]);
%! PL = geom.Polyline ([0, 0, 1; 20, 0, 0], 'UCS', U);
%! P = geom.Path (PL);
%! assert_equal (P.UCS, U);
%! assert_equal (P.Vertices, [0, 0, 0; 20, 0, 0]);
%! assert_equal (P.Midpoints, [10, -10, 0; NaN, NaN, NaN], 1e-12);
%! assert_equal (length (P), 10 * pi, 1e-12);

%!test  # points given in a UCS; assigning another moves the path
%! U = geom.UCS ([1, 0, 0], [5, 5, 5]);
%! P = geom.Path ([0, 0, 0; 0, 0, 10], 'UCS', U);
%! assert_equal (P.UCS, U);
%! P.UCS = geom.UCS ();
%! assert_equal (P.Vertices, [0, 0, 0; 0, 0, 10]);
%! assert_equal (P.UCS, geom.UCS ());

%!test  # a closed polyline: a slot, two straights and two half circles
%! PL = geom.Polyline ([0, -6, 0; 40, -6, 1; 40, 6, 0; 0, 6, 1], ...
%!                     'Closed', true);
%! P = geom.Path (PL);
%! assert_equal (P.Closed, true);
%! assert_equal (P.Midpoints([2, 4],:), [46, 0, 0; -6, 0, 0], 1e-12);
%! assert_equal (length (P), 80 + 12 * pi, 1e-12);

%!test  # a right-angle bend out of the xy plane
%! P = fillet (geom.Path ([0, 0, 0; 0, 0, 10; 10, 0, 10]), 4);
%! assert_equal (P.Vertices, [0, 0, 0; 0, 0, 6; 4, 0, 10; 10, 0, 10], 1e-12);
%! assert_equal (P.Midpoints(2,:), [4 - 4 / sqrt(2), 0, 6 + 4 / sqrt(2)], ...
%!               1e-12);
%! assert_equal (length (P), 12 + 2 * pi, 1e-12);

%!test  # chosen corners of a closed path
%! P = geom.Path ([0, 0, 0; 30, 0, 0; 30, 20, 0; 0, 20, 0], 'Closed', true);
%! Q = fillet (P, 5, [1, 3]);
%! assert_equal (rows (Q.Vertices), 6);
%! assert_equal (length (Q), 100 - 4 * 5 + 5 * pi, 1e-12);

%!test  # rounds that use up the segment between them meet
%! P = geom.Path ([0, 0, 0; 0, 0, 50; 20, 0, 50; 20, 0, 0]);
%! P = fillet (P, 10);
%! assert_equal (P.Vertices, [0, 0, 0; 0, 0, 40; 10, 0, 50; 20, 0, 40; ...
%!                            20, 0, 0], 1e-12);
%! assert_equal (length (P), 80 + 10 * pi, 1e-12);

%!test  # an arc through three points, PM anywhere along it
%! P = geom.Path.arc ([10, 0, 0], [6, 8, 0], [-10, 0, 0]);
%! assert_equal (P.Midpoints(1,:), [0, 10, 0], 1e-12);
%! assert_equal (length (P), 10 * pi, 1e-12);

%!test  # an arc of more than a half circle
%! P = geom.Path.arc ([0, 0, 10], [0, -10, 0], [0, 10, 0]);
%! assert_equal (P.Midpoints(1,:), [0, -sqrt(50), -sqrt(50)], 1e-12);
%! assert_equal (length (P), 15 * pi, 1e-12);

%!test  # a hairpin joined from three pieces
%! P = join (geom.Path ([0, 0, 0; 0, 0, 50]), ...
%!           geom.Path.arc ([0, 0, 50], [10, 0, 60], [20, 0, 50]), ...
%!           geom.Path ([20, 0, 50; 20, 0, 0]));
%! assert_equal (P.Vertices, [0, 0, 0; 0, 0, 50; 20, 0, 50; 20, 0, 0]);
%! assert_equal (P.Midpoints(2,:), [10, 0, 60], 1e-12);
%! assert_equal (P.Closed, false);
%! assert_equal (length (P), 100 + 10 * pi, 1e-12);

%!test  # pieces in different UCSs, joined in the first one's
%! U = geom.UCS ([0, 0, 1], [0, 0, 10]);
%! P = geom.Path.arc ([0, 0, 0], [5, 5, 0], [10, 0, 0]);
%! P.UCS = U;
%! Q = join (geom.Path ([0, 0, 0; 0, 0, 10]), P);
%! assert_equal (Q.UCS, geom.UCS ());
%! assert_equal (Q.Vertices, [0, 0, 0; 0, 0, 10; 10, 0, 10], 1e-12);
%! assert_equal (Q.Midpoints(2,:), [5, 5, 10], 1e-12);

%!test  # joined end to start, closed
%! P = join (geom.Path ([0, 0, 0; 10, 0, 0]), ...
%!           geom.Path.arc ([10, 0, 0], [5, 5, 0], [0, 0, 0]));
%! assert_equal (P.Closed, true);
%! assert_equal (rows (P.Vertices), 2);
%! assert_equal (length (P), 10 + 5 * pi, 1e-12);

%!error<geom.Path: invalid number of input arguments.> geom.Path ()
%!error<geom.Path: invalid number of input arguments.> ...
%! geom.Path (geom.Polyline ([0, 0; 1, 0]), 'Closed', true)
%!error<geom.Path: V must be an M-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Path ([0, 0; 1, 0])
%!error<geom.Path: V must be an M-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Path ([0, 0, 0])
%!error<geom.Path: V must be an M-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Path ([0, 0, 0; 1, 0, Inf])
%!error<geom.Path: Name/Value arguments must come in pairs.> ...
%! geom.Path ([0, 0, 0; 1, 0, 0], 'Closed')
%!error<geom.Path: unknown parameter.> ...
%! geom.Path ([0, 0, 0; 1, 0, 0], 'Bulge', [0, 0])
%!error<geom.Path: UCS must be a geom.UCS object.> ...
%! geom.Path ([0, 0, 0; 1, 0, 0], 'UCS', [0, 0, 1])
%!error<geom.Path: UCS must be a geom.UCS object.>
%! P = geom.Path ([0, 0, 0; 1, 0, 0]);
%! P.UCS = [0, 0, 0];
%!error<geom.Path: Closed must be a logical scalar.> ...
%! geom.Path ([0, 0, 0; 1, 0, 0], 'Closed', 2)
%!error<geom.Path: V must not repeat a point consecutively.> ...
%! geom.Path ([0, 0, 0; 1, 0, 0; 1, 0, 0])
%!error<geom.Path.fillet: invalid number of input arguments.> ...
%! fillet (geom.Path ([0, 0, 0; 1, 0, 0]))
%!error<geom.Path.fillet: RADIUS must be a positive and finite real scalar.> ...
%! fillet (geom.Path ([0, 0, 0; 1, 0, 0; 1, 1, 0]), -1)
%!error<geom.Path.fillet: IDX must be a vector of vertex indices of P.> ...
%! fillet (geom.Path ([0, 0, 0; 1, 0, 0; 1, 1, 0]), 0.1, 4)
%!error<geom.Path.fillet: vertex 1 is not a corner between two straight segments.> ...
%! fillet (geom.Path ([0, 0, 0; 1, 0, 0; 1, 1, 0]), 0.1, 1)
%!error<geom.Path.fillet: vertex 2 is not a corner between two straight segments.> ...
%! fillet (geom.Path ([0, 0, 0; 1, 0, 0; 2, 0, 0]), 0.1, 2)
%!error<geom.Path.fillet: the round at vertex 2 does not fit its segments.> ...
%! fillet (geom.Path ([0, 0, 0; 1, 0, 0; 1, 1, 0]), 2)
%!error<geom.Path.join: invalid number of input arguments.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]))
%!error<geom.Path.join: every argument must be a geom.Path object.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]), [1, 0, 0; 2, 0, 0])
%!error<geom.Path.join: path 2 is closed.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]), ...
%!       geom.Path ([1, 0, 0; 2, 0, 0; 2, 1, 0], 'Closed', true))
%!error<geom.Path.join: path 2 does not begin where path 1 ends.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]), geom.Path ([2, 0, 0; 3, 0, 0]))
%!error<geom.Path.arc: invalid number of input arguments.> ...
%! geom.Path.arc ([0, 0, 0], [1, 1, 0])
%!error<geom.Path.arc: P1, PM and P2 must be real 3-element vectors of finite values.> ...
%! geom.Path.arc ([0, 0], [1, 1, 0], [2, 0, 0])
%!error<geom.Path.arc: P1, PM and P2 must not lie on one line.> ...
%! geom.Path.arc ([0, 0, 0], [1, 1, 1], [2, 2, 2])
%!error<geom.Path.arc: P1, PM and P2 must not lie on one line.> ...
%! geom.Path.arc ([0, 0, 0], [1, 1, 0], [0, 0, 0])
