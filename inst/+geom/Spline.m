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
  ## A smooth curve: a NURBS, drawn through points or given by its control
  ## points.
  ##
  ## A @code{geom.Spline} holds a non-uniform rational B-spline: control
  ## points that pull the curve towards them, a weight for each, a degree and
  ## a knot vector.  This form carries exactly the curves a solid is made of
  ## and a cut through it gives, a circle, an ellipse or any other conic as a
  ## rational spline and Open CASCADE's own B-splines as they are, and it is
  ## what a DXF @code{SPLINE} holds.  The curve is open, or closed and joined
  ## back to its start.
  ##
  ## A spline is usually drawn through points: a cubic that passes through
  ## each in turn, smooth all along, its direction and curvature changing
  ## without a jump.  It is parametrised by the distance from point to point.
  ## Either end of an open spline may be given a direction; an end left free is
  ## shaped as Octave's @code{spline} shapes it, the first and last two pieces
  ## each one cubic.  A closed spline is smooth all round.  The points and the
  ## directions are kept as the spline's fit data, as DXF keeps them, and when
  ## the spline is joined into a path its free ends take the direction of
  ## what they meet.  @code{geom.Spline.nurbs} makes a spline from control
  ## points, knots and weights instead, with no fit data.
  ##
  ## A spline is the curve of a grip, a curved rib or a channel that follows a
  ## surface: @code{solid.sweep} carries a section along it as one segment of
  ## a @code{geom.Path}, and a closed spline is a smooth outline or hole of a
  ## @code{geom.Region}.
  ##
  ## Its points are coordinates in the spline's @code{geom.UCS}, the world
  ## coordinate system by default, and assigning another UCS moves the
  ## spline, its shape unchanged in its own coordinates.  A spline whose
  ## points all have @math{z = 0} lies in the plane of its UCS.
  ##
  ## A @code{geom.Spline} is a value: every change makes a new one.
  ##
  ## @seealso{geom.Path, geom.Region, geom.Polyline, solid.sweep, spline}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} Degree
    ##
    ## Degree of the curve
    ##
    ## The degree of the polynomial pieces the curve is made of, 3 for a
    ## spline drawn through points.
    ##
    ## @end deftp
    Degree = 3;

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} ControlPoints
    ##
    ## Control points
    ##
    ## The control points as an @math{N}-by-3 matrix in millimetres in the
    ## spline's UCS.  The curve starts at the first and ends at the last.
    ##
    ## @end deftp
    ControlPoints = zeros (0, 3);

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} Weights
    ##
    ## Weights of the control points
    ##
    ## An @math{N}-by-1 vector of positive weights, all 1 for a curve that is
    ## not rational.
    ##
    ## @end deftp
    Weights = zeros (0, 1);

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} Knots
    ##
    ## Knot vector
    ##
    ## The full knot vector, a row of @math{N} + @code{Degree} + 1
    ## nondecreasing parameters, its first and its last value each repeated
    ## @code{Degree} + 1 times.  For a spline drawn through points the inner
    ## knots are the distances along the points.
    ##
    ## @end deftp
    Knots = zeros (1, 0);

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} Closed
    ##
    ## Closed flag
    ##
    ## @code{true} when the curve ends where it starts.
    ##
    ## @end deftp
    Closed = false;

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} FitPoints
    ##
    ## Points the spline was drawn through
    ##
    ## For a spline drawn through points, the points as an @math{M}-by-3
    ## matrix in its UCS, in the order the spline passes through them; empty
    ## for a spline made from control points.
    ##
    ## @end deftp
    FitPoints = zeros (0, 3);

    ## -*- texinfo -*-
    ## @deftp {geom.Spline} {property} Tangents
    ##
    ## Directions at the ends
    ##
    ## For a spline drawn through points, a 2-by-3 matrix whose rows are the
    ## unit directions given at its first and its last point, or @code{NaN}
    ## for an end left free, as both are for a closed spline; empty for a
    ## spline made from control points.
    ##
    ## @end deftp
    Tangents = zeros (0, 3);

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

      if (this.Closed)
        c = "closed";
      else
        c = "open";
      endif
      if (any (this.Weights != 1))
        r = "rational, ";
      else
        r = "";
      endif
      printf ("  geom.Spline: %s, %sdegree %d, %d control points", c, r, ...
              this.Degree, rows (this.ControlPoints));
      if (! isempty (this.FitPoints))
        printf (", through %d points", rows (this.FitPoints));
      endif
      printf ("\n");

    endfunction

    ## The unit directions of the curve at its start and at its end
    function [T1, T2] = __ends__ (this)

      [~, D] = curve (this, this.Knots([1, end])');
      D = D ./ sqrt (sum (D .^ 2, 2));
      T1 = D(1,:);
      T2 = D(2,:);

    endfunction

    ## Points along the curve from its start to its end, both included, each
    ## piece cut finely enough that the curve turns by at most DEG degrees,
    ## 2 by default, from one to the next
    function Q = __sample__ (this, DEG = 2)

      u = unique (this.Knots);
      Q = cell (numel (u) - 1, 1);
      for j = 1:numel (u) - 1
        [~, D] = curve (this, [u(j); (u(j) + u(j+1)) / 2; u(j+1)]);
        a = turn (D(1,:), D(2,:)) + turn (D(2,:), D(3,:));
        k = max (16, ceil (a / (DEG * pi / 180)));
        s = u(j) + (u(j+1) - u(j)) * (0:k-1)' / k;
        Q{j} = curve (this, s);
      endfor
      Q = [vertcat(Q{:}); curve(this, u(end))];

    endfunction

    ## Half the integral of x dy - y dx along the curve, its share of the
    ## signed area of a closed loop in the plane of its UCS
    function G = __green__ (this)

      u = unique (this.Knots);
      W = this.Weights;
      if (all (W == W(1)))
        ## On each span a polynomial of degree 2p-1, which Gauss-Legendre
        ## quadrature on p points integrates exactly
        p = this.Degree;
        b = (1:p-1) ./ sqrt (4 * (1:p-1) .^ 2 - 1);
        [V, x] = eig (diag (b, 1) + diag (b, -1), 'vector');
        w = 2 * V(1,:)' .^ 2;
        h = diff (u(:))' / 2;
        c = (u(1:end-1)(:)' + u(2:end)(:)') / 2;
        g = green (this, c + h .* x);
        G = sum (reshape (g, p, []) .* (w .* h), 'all');
      else
        G = 0;
        tol = 1e-14 * max ([1; abs(this.ControlPoints(:))]) ^ 2;
        for j = 1:numel (u) - 1
          G += integral (@(s) green (this, s), u(j), u(j+1), ...
                         'RelTol', 1e-12, 'AbsTol', tol);
        endfor
      endif

    endfunction

    ## The same curve run the other way round, a closed one from the same
    ## first point
    function this = __reversed__ (this)

      K = this.Knots;
      this.ControlPoints = flipud (this.ControlPoints);
      this.Weights = flipud (this.Weights);
      this.Knots = K(1) + K(end) - fliplr (K);
      if (! isempty (this.FitPoints))
        if (this.Closed)
          this.FitPoints = this.FitPoints([1, end:-1:2],:);
        else
          this.FitPoints = flipud (this.FitPoints);
        endif
        this.Tangents = -flipud (this.Tangents);
      endif

    endfunction

    ## The spline with every point p moved to p * M + B and every direction d
    ## turned to d * M.  For M a rotation, a reflection or a uniform scale, a
    ## spline drawn through points is drawn again through its moved points;
    ## for any other M, which would draw a different curve through them, the
    ## control points are moved and the fit data dropped
    function this = __affine__ (this, M, B)

      U = this.UCS;
      G = M * M';
      if (norm (G - G(1) * eye (3)) > 1e-12 * G(1))
        this.ControlPoints = this.ControlPoints * M + B;
        this.FitPoints = zeros (0, 3);
        this.Tangents = zeros (0, 3);
      elseif (! isempty (this.FitPoints))
        T = this.Tangents * M;
        T(! isnan (T(:,1)),:) ./= sqrt (sum (T(! isnan (T(:,1)),:) .^ 2, 2));
        if (this.Closed)
          this = geom.Spline (this.FitPoints * M + B, 'Closed', true);
        else
          this = geom.Spline (this.FitPoints * M + B, 'Tangents', T);
        endif
      else
        this.ControlPoints = this.ControlPoints * M + B;
      endif
      this.UCS = U;

    endfunction

    ## The least and the greatest value of each coordinate along the curve, as
    ## the rows of B: from points along every piece, the least and greatest
    ## then found exactly between their neighbours
    function B = __box__ (this)

      u = unique (this.Knots);
      t = zeros (0, 1);
      for j = 1:numel (u) - 1
        t = [t; u(j) + (u(j+1) - u(j)) * (0:31)' / 32];
      endfor
      t(end+1) = u(end);
      P = curve (this, t);
      B = [min(P, [], 1); max(P, [], 1)];
      opt = optimset ('TolX', 1e-12 * (u(end) - u(1)));
      for d = 1:3
        for g = [1, -1]
          [~, i] = min (g * P(:,d));
          a = t(max (i - 1, 1));
          b = t(min (i + 1, numel (t)));
          if (a == b)
            continue;
          endif
          [~, v] = fminbnd (@(s) g * curve (this, s)(d), a, b, opt);
          if (g > 0)
            B(1,d) = min (B(1,d), v);
          else
            B(2,d) = max (B(2,d), -v);
          endif
        endfor
      endfor

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Spline} {@var{SP} =} geom.Spline (@var{V})
    ## @deftypefnx {geom.Spline} {@var{SP} =} geom.Spline (@var{V}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Make a spline through points.
    ##
    ## @code{@var{SP} = geom.Spline (@var{V})} makes the cubic spline through
    ## the points given as rows of @var{V}, an @math{M}-by-3 matrix in
    ## millimetres, or an @math{M}-by-2 matrix of points in the plane of the
    ## UCS, with at least two rows.  Through two points with both ends free,
    ## the spline is the straight line between them.
    ##
    ## Name/Value pairs:
    ##
    ## @table @asis
    ## @item @qcode{'Closed'}
    ## @code{true} for a spline that runs on from the last point back to the
    ## first, smooth there as everywhere, @code{false} by default.  A closed
    ## spline needs at least three points and has no ends to give directions
    ## to.  It must @strong{not} repeat its first point at the end; a repeat is
    ## accepted and dropped.
    ##
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
    ##
    ## ## A smooth closed outline through five points
    ## SP = geom.Spline ([0, 0; 30, -5; 45, 15; 25, 30; 5, 20], ...
    ##                   'Closed', true);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Spline.nurbs}
    ## @end deftypefn
    function this = Spline (V, varargin)

      ## Input validation
      if (nargin < 1)
        error ("geom.Spline: invalid number of input arguments.");
      endif
      if (! isnumeric (V) || ! isreal (V) || ! ismatrix (V)
          || ! any (columns (V) == [2, 3]) || rows (V) < 2
          || ! all (isfinite (V(:))))
        error (strcat ("geom.Spline: V must be an M-by-2 or M-by-3 real", ...
                       " matrix of finite values with at least two rows."));
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("geom.Spline: Name/Value arguments must come in pairs.");
      endif
      opt = struct ('Tangents', NaN (2, 3), 'Closed', false, ...
                    'UCS', geom.UCS ());
      for k = 1:2:numel (varargin)
        name = varargin{k};
        if (! ischar (name) || ! isrow (name)
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
      if (! (islogical (opt.Closed) || isnumeric (opt.Closed))
          || ! isscalar (opt.Closed) || ! any (opt.Closed == [0, 1]))
        error ("geom.Spline: Closed must be a logical scalar.");
      endif
      closed = logical (opt.Closed);
      if (closed && ! all (isnan (T(:))))
        error ("geom.Spline: a closed spline has no ends to give Tangents.");
      endif
      if (! isa (opt.UCS, 'geom.UCS') || ! isscalar (opt.UCS))
        error ("geom.Spline: UCS must be a geom.UCS object.");
      endif

      V = double (V);
      if (columns (V) == 2)
        V(:,3) = 0;
      endif

      ## Accept an explicitly closed spline and drop the repeat
      if (closed && rows (V) > 3 && isequal (V(1,:), V(end,:)))
        V(end,:) = [];
      endif
      if (closed && rows (V) < 3)
        error ("geom.Spline: a closed spline needs at least three points.");
      endif
      if (closed)
        D = V([2:end, 1],:) - V;
      else
        D = diff (V);
      endif
      if (any (all (D == 0, 2)))
        error ("geom.Spline: V must not repeat a point consecutively.");
      endif
      T = T ./ sqrt (sum (T .^ 2, 2));

      ## The cubic through the points with their derivatives there, as a
      ## B-spline with a simple knot at each inner point
      [t, m, W] = slopes (V, T, closed);
      K = [t(1), t(1), t(1), t', t(end), t(end), t(end)];
      I = eye (rows (W) + 2);
      [Q, KQ] = derivative (I, K, 3);
      A = [deboor(I, K, 3, t); deboor(Q, KQ, 2, t([1, end]))];

      this.ControlPoints = A \ [W; m([1, end],:)];
      if (closed)
        this.ControlPoints(end,:) = this.ControlPoints(1,:);
      endif
      this.Weights = ones (rows (this.ControlPoints), 1);
      this.Knots = K;
      this.Closed = closed;
      this.FitPoints = V;
      this.Tangents = T;
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

      u = unique (this.Knots);
      L = 0;
      tol = 1e-14 * max ([1; abs(this.ControlPoints(:))]);
      for j = 1:numel (u) - 1
        L += integral (@(s) speed (this, s), u(j), u(j+1), ...
                       'RelTol', 1e-12, 'AbsTol', tol);
      endfor

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Spline} {@var{P} =} points (@var{SP}, @var{N})
    ##
    ## Points along a spline.
    ##
    ## @code{@var{P} = points (@var{SP}, @var{N})} returns @var{N} points
    ## along the spline @var{SP}, from its start to its end, or round a closed
    ## spline back to its start, as an @var{N}-by-3 matrix of coordinates in its
    ## UCS.  They are spaced evenly in the spline's parameter, for a spline
    ## drawn through points the distance from point to point, so they include
    ## every point it passes through only when @var{N} falls on them.  Convert
    ## them to world coordinates with @code{geom.UCS.toworld}.
    ##
    ## @end deftypefn
    function P = points (this, N)

      ## Input validation
      if (nargin != 2)
        error ("geom.Spline.points: invalid number of input arguments.");
      endif
      if (! isnumeric (N) || ! isreal (N) || ! isscalar (N) || N != fix (N)
          || N < 2)
        error ("geom.Spline.points: N must be an integer of at least 2.");
      endif

      P = curve (this, linspace (this.Knots(1), this.Knots(end), ...
                                 double (N))');

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


    ## -*- texinfo -*-
    ## @deftypefn  {geom.Spline} {} write (@var{SP}, @var{FILE})
    ## @deftypefnx {geom.Spline} {} write (@var{SP}, @var{FILE}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Write a spline to a DXF file.
    ##
    ## @code{write (@var{SP}, @var{FILE})} writes the spline @var{SP} to
    ## @var{FILE}, which must end in @file{.dxf}, as one @code{SPLINE} of an
    ## ASCII DXF drawing, in world coordinates: its control points, knots and
    ## weights, and its fit points and end directions where it was drawn
    ## through points.  The spline's @code{geom.UCS} goes with it as extended
    ## data under the application @qcode{'DRAFTING'}, so @code{geom.read}
    ## gives back the spline that was written, frame and fit data included.
    ##
    ## Name/Value pairs:
    ##
    ## @table @asis
    ## @item @qcode{'Layer'}
    ## The layer, @qcode{'0'} by default.
    ## @item @qcode{'Linetype'}
    ## One of the line types of @code{draw.linetype}, or any name the
    ## receiving program holds; @qcode{'CONTINUOUS'} by default.
    ## @item @qcode{'Colour'}
    ## An AutoCAD colour index from 1 to 256, 256 meaning the layer's colour,
    ## which is the default.  True colour came only with R2004.
    ## @item @qcode{'Version'}
    ## @qcode{'R2000'} (@code{AC1015}), the default, or @qcode{'R12'}
    ## (@code{AC1009}) for a program that reads nothing later.  R12 holds
    ## only lines and arcs, so a spline is an error there.
    ## @item @qcode{'LTScale'}
    ## The drawing's line-type scale, 1 by default, written in the header so
    ## the dashes look the same wherever the file is opened.
    ## @end table
    ##
    ## The drawing units are millimetres.  Several geom objects go in one file
    ## through @code{geom.write}.
    ##
    ## @seealso{geom.read, geom.write, draw.Drawing.write}
    ## @end deftypefn
    function write (this, FILE, varargin)

      if (nargin < 2)
        error ("geom.Spline.write: invalid number of input arguments.");
      endif
      __dxf__ ('write', FILE, {this}, varargin, 'geom.Spline.write');

    endfunction

  endmethods

  methods (Static)

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Spline} {@var{SP} =} geom.Spline.nurbs (@var{P}, @var{KNOTS})
    ## @deftypefnx {geom.Spline} {@var{SP} =} geom.Spline.nurbs (@var{P}, @var{KNOTS}, @var{W})
    ## @deftypefnx {geom.Spline} {@var{SP} =} geom.Spline.nurbs (@dots{}, @qcode{'UCS'}, @var{U})
    ##
    ## Make a spline from its control points.
    ##
    ## @code{@var{SP} = geom.Spline.nurbs (@var{P}, @var{KNOTS})} makes the
    ## B-spline with the control points given as rows of @var{P}, an
    ## @math{N}-by-3 matrix in millimetres, or an @math{N}-by-2 matrix of
    ## points in the plane of the UCS, with at least two rows, and the knot
    ## vector @var{KNOTS}.  @var{KNOTS} has @math{N} + @var{D} + 1
    ## nondecreasing values, which sets the degree @var{D}: its first and its
    ## last value are each repeated @var{D} + 1 times, so the curve starts at
    ## the first control point and ends at the last, and no inner knot is
    ## repeated more than @var{D} times.  The degree is at most 25.
    ##
    ## @code{@var{SP} = geom.Spline.nurbs (@var{P}, @var{KNOTS}, @var{W})}
    ## gives each control point a positive weight, which makes the curve
    ## rational, a NURBS, as a circle or another conic must be.
    ##
    ## The option @qcode{'UCS'} gives the @code{geom.UCS} the control points
    ## are coordinates in, the world coordinate system by default.  The spline
    ## is closed when its first and last control points coincide.  It has no
    ## fit data.
    ##
    ## @example
    ## @group
    ## ## A quarter of a circle of radius 10, exactly
    ## SP = geom.Spline.nurbs ([10, 0; 10, 10; 0, 10], [0, 0, 0, 1, 1, 1], ...
    ##                         [1; sqrt(2) / 2; 1]);
    ## length (SP)
    ## @result{} 15.708
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Spline}
    ## @end deftypefn
    function this = nurbs (P, KNOTS, varargin)

      ## Input validation
      if (nargin < 2)
        error ("geom.Spline.nurbs: invalid number of input arguments.");
      endif
      W = [];
      if (! isempty (varargin) && ! ischar (varargin{1}))
        W = varargin{1};
        varargin(1) = [];
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("geom.Spline.nurbs: Name/Value arguments must come in pairs.");
      endif
      U = geom.UCS ();
      for k = 1:2:numel (varargin)
        if (! ischar (varargin{k}) || ! strcmp (varargin{k}, 'UCS'))
          error ("geom.Spline.nurbs: unknown parameter.");
        endif
        U = varargin{k+1};
        if (! isa (U, 'geom.UCS') || ! isscalar (U))
          error ("geom.Spline.nurbs: UCS must be a geom.UCS object.");
        endif
      endfor
      if (! isnumeric (P) || ! isreal (P) || ! ismatrix (P)
          || ! any (columns (P) == [2, 3]) || rows (P) < 2
          || ! all (isfinite (P(:))))
        error (strcat ("geom.Spline.nurbs: P must be an N-by-2 or N-by-3", ...
                       " real matrix of finite values with at least two", ...
                       " rows."));
      endif
      n = rows (P);
      if (! isnumeric (KNOTS) || ! isreal (KNOTS) || ! isvector (KNOTS)
          || numel (KNOTS) < n + 2 || ! all (isfinite (KNOTS))
          || any (diff (KNOTS) < 0) || KNOTS(1) == KNOTS(end))
        error (strcat ("geom.Spline.nurbs: KNOTS must be a nondecreasing", ...
                       " real vector of at least N + 2 finite values, not", ...
                       " all equal."));
      endif
      K = double (KNOTS(:)');
      d = numel (K) - n - 1;
      if (d > 25)
        error ("geom.Spline.nurbs: the degree must be at most 25.");
      endif
      if (any (K(1:d+1) != K(1)) || any (K(end-d:end) != K(end)))
        error (strcat ("geom.Spline.nurbs: KNOTS must repeat its first and", ...
                       " its last value one more time than the degree."));
      endif
      [~, ~, j] = unique (K);
      mult = accumarray (j(:), 1);
      if (any (mult(2:end-1) > d))
        error (strcat ("geom.Spline.nurbs: an inner knot may be repeated", ...
                       " no more times than the degree."));
      endif
      if (isempty (W))
        W = ones (n, 1);
      elseif (! isnumeric (W) || ! isreal (W) || ! isvector (W)
              || numel (W) != n || ! all (isfinite (W)) || ! all (W > 0))
        error (strcat ("geom.Spline.nurbs: W must be a vector of N", ...
                       " positive finite weights."));
      endif

      P = double (P);
      if (columns (P) == 2)
        P(:,3) = 0;
      endif
      this = geom.Spline ([0, 0; 1, 0]);
      this.Degree = d;
      this.ControlPoints = P;
      this.Weights = double (W(:));
      this.Knots = K;
      scale = max (1, max (abs (P(:))));
      this.Closed = norm (P(1,:) - P(end,:)) <= 1e-12 * scale;
      this.FitPoints = zeros (0, 3);
      this.Tangents = zeros (0, 3);
      this.UCS = U;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Spline} {@var{SP} =} geom.Spline.ellipse (@var{A}, @var{B})
    ## @deftypefnx {geom.Spline} {@var{SP} =} geom.Spline.ellipse (@var{A}, @var{B}, @qcode{'UCS'}, @var{U})
    ##
    ## An ellipse, exactly.
    ##
    ## @code{@var{SP} = geom.Spline.ellipse (@var{A}, @var{B})} returns the
    ## closed ellipse centred on the origin with the semi-axis @var{A}
    ## millimetres along the @math{x} axis and @var{B} along the @math{y}
    ## axis, a circle when they are equal.  It is a rational spline of degree
    ## 2, four quarters joined, which follows the ellipse exactly, so its area
    ## and length are those of the ellipse and a solid made from it has a true
    ## elliptic face.  As a closed spline it is the outline or a hole of a
    ## @code{geom.Region}, or a path to sweep along.
    ##
    ## The option @qcode{'UCS'} lays it in the @code{geom.UCS} @var{U},
    ## centred on its origin, @var{A} along its @math{x} axis; the world
    ## @math{xy} plane by default.  Turning the UCS turns the ellipse.
    ##
    ## @example
    ## @group
    ## ## An elliptic boss 40 by 20, 5 high, with a bore of 8
    ## R = geom.Region (geom.Spline.ellipse (20, 10), @{[-4, 0, 1; 4, 0, 1]@});
    ## S = solid.extrude (R, 5);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Spline.nurbs, geom.Region, solid.ellipsoid}
    ## @end deftypefn
    function this = ellipse (A, B, varargin)

      ## Input validation
      if (nargin != 2 && nargin != 4)
        error ("geom.Spline.ellipse: invalid number of input arguments.");
      endif
      if (! isnumeric (A) || ! isreal (A) || ! isscalar (A)
          || ! isfinite (A) || ! (A > 0))
        error (strcat ("geom.Spline.ellipse: A must be a positive and", ...
                       " finite real scalar."));
      endif
      if (! isnumeric (B) || ! isreal (B) || ! isscalar (B)
          || ! isfinite (B) || ! (B > 0))
        error (strcat ("geom.Spline.ellipse: B must be a positive and", ...
                       " finite real scalar."));
      endif
      U = geom.UCS ();
      if (nargin == 4)
        if (! ischar (varargin{1}) || ! strcmp (varargin{1}, 'UCS'))
          error ("geom.Spline.ellipse: unknown parameter.");
        endif
        U = varargin{2};
        if (! isa (U, 'geom.UCS') || ! isscalar (U))
          error ("geom.Spline.ellipse: UCS must be a geom.UCS object.");
        endif
      endif

      ## A circle of four rational quarters, stretched
      P = [1, 0; 1, 1; 0, 1; -1, 1; -1, 0; -1, -1; 0, -1; 1, -1; 1, 0] ...
          .* double ([A, B]);
      w = sqrt (2) / 2;
      this = geom.Spline.nurbs (P, [0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 4], ...
                                [1; w; 1; w; 1; w; 1; w; 1], 'UCS', U);

    endfunction

  endmethods

endclassdef

## The points of the spline SP at the parameters U, a column, and the
## derivatives of the curve there
function [C, D] = curve (SP, U)

  Pw = [SP.ControlPoints .* SP.Weights, SP.Weights];
  A = deboor (Pw, SP.Knots, SP.Degree, U);
  C = A(:,1:3) ./ A(:,4);
  if (nargout > 1)
    [Q, KQ] = derivative (Pw, SP.Knots, SP.Degree);
    dA = deboor (Q, KQ, SP.Degree - 1, U);
    D = (dA(:,1:3) - dA(:,4) .* C) ./ A(:,4);
  endif

endfunction

## The speed along the spline SP at the parameters U, a row
function v = speed (SP, U)

  [~, D] = curve (SP, U(:));
  v = sqrt (sum (D .^ 2, 2))';

endfunction

## Half of x y' - y x' along the spline SP at the parameters U, a row
function g = green (SP, U)

  [C, D] = curve (SP, U(:));
  g = (C(:,1) .* D(:,2) - C(:,2) .* D(:,1))' / 2;

endfunction

## The angle between the directions A and B
function a = turn (A, B)

  a = acos (min (1, max (-1, dot (A, B) / (norm (A) * norm (B)))));

endfunction

## The sum of the rows of PW weighted by the B-spline basis functions of
## degree P on the knot vector K, at each of the parameters U: the point of a
## curve at each, or with an identity matrix for PW, the basis itself
function A = deboor (PW, K, P, U)

  U = U(:);
  K = K(:);
  n = rows (PW);
  s = min (max (lookup (K, U), P + 1), n);
  N = [ones(numel (U), 1), zeros(numel (U), P)];
  left = zeros (numel (U), P);
  right = zeros (numel (U), P);
  for j = 1:P
    left(:,j) = U - K(s + 1 - j);
    right(:,j) = K(s + j) - U;
    saved = zeros (numel (U), 1);
    for r = 0:j-1
      tmp = N(:,r+1) ./ (right(:,r+1) + left(:,j-r));
      N(:,r+1) = saved + right(:,r+1) .* tmp;
      saved = left(:,j-r) .* tmp;
    endfor
    N(:,j+1) = saved;
  endfor
  A = zeros (numel (U), columns (PW));
  for r = 0:P
    A += N(:,r+1) .* PW(s - P + r,:);
  endfor

endfunction

## The control points Q and knot vector KQ of the derivative of the B-spline
## of degree P with control points PW on the knot vector K
function [Q, KQ] = derivative (PW, K, P)

  n = rows (PW);
  h = K((1:n-1) + P + 1) - K((1:n-1) + 1);
  Q = P * diff (PW) ./ h(:);
  Q(h == 0,:) = 0;
  KQ = K(2:end-1);

endfunction

## The parameters T of the points V, the distances from point to point, and
## the derivatives M of the cubic through them there, with the given end
## directions T or the ends free, not-a-knot; a closed spline round and round,
## its first point again at the end of W, the points the pieces run between
function [t, m, W] = slopes (V, T, closed)

  W = V;
  if (closed)
    W(end+1,:) = W(1,:);
  endif
  n = rows (W);
  h = sqrt (sum (diff (W) .^ 2, 2));
  t = [0; cumsum(h)];
  d = diff (W) ./ h;
  free = isnan (T(:,1));
  if (closed)
    ## The second derivative continuous at every point, round and round
    k = n - 1;
    A = zeros (k);
    b = zeros (k, 3);
    for i = 1:k
      p = mod (i - 2, k) + 1;
      q = mod (i, k) + 1;
      A(i,[p, i, q]) += [h(i), 2 * (h(p) + h(i)), h(p)];
      b(i,:) = 3 * (h(i) * d(p,:) + h(p) * d(i,:));
    endfor
    m = A \ b;
    m(end+1,:) = m(1,:);
    return;
  endif
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

%!test
%! SP = geom.Spline ([0, 0; 10, 0; 20, 5]);
%! assert_equal (SP.FitPoints, [0, 0, 0; 10, 0, 0; 20, 5, 0]);
%! assert_equal (SP.Tangents, NaN (2, 3));
%! assert_equal (SP.UCS, geom.UCS ());
%! assert_equal (SP.Degree, 3);
%! assert_equal (SP.ControlPoints([1, end],:), [0, 0, 0; 20, 5, 0], 1e-12);
%! assert_equal (SP.Weights, ones (5, 1));
%! assert_equal (SP.Knots, [0, 0, 0, 0, 10, 10 + sqrt(125) * [1, 1, 1, 1]], ...
%!               1e-12);

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
%! assert_equal (__ends__ (SP), [1, 0, 0], 1e-12);
%! assert_equal (SP.Tangents(2,:), NaN (1, 3));

%!test  # through three points with free ends, the parabola through them
%! SP = geom.Spline ([-1, 1; 0, 0; 1, 1]);
%! P = points (SP, 3);
%! assert_equal (P, [-1, 1, 0; 0, 0, 0; 1, 1, 0], 1e-12);
%! assert_equal (length (SP), sqrt (5) + asinh (2) / 2, -1e-12);

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
%! assert_equal (SP.FitPoints, [0, 0, 0; 10, 5, 0; 20, 0, 0]);

%!test  # closed: smooth round a circle, the repeat of the first point dropped
%! a = (0:11)' * pi / 6;
%! V = [10 * cos(a), 10 * sin(a)];
%! SP = geom.Spline ([V; V(1,:)], 'Closed', true);
%! assert_equal (rows (SP.FitPoints), 12);
%! assert_equal (SP.Closed, true);
%! assert_equal (SP.ControlPoints(end,:), SP.ControlPoints(1,:));
%! assert_equal (length (SP), 20 * pi, -2e-4);
%! P = points (SP, 361);
%! assert_equal (sqrt (sum (P .^ 2, 2)), 10 * ones (361, 1), 3e-3);
%! assert_equal (P(end,:), P(1,:), 1e-12);
%! [T1, T2] = __ends__ (SP);
%! assert_equal (T2, T1, 1e-12);

%!test  # closed: a periodic spline, the same whichever point it starts at
%! V = [0, 0; 30, -5; 45, 15; 25, 30; 5, 20];
%! P = points (geom.Spline (V, 'Closed', true), 1001);
%! Q = points (geom.Spline (V([3:5, 1:2],:), 'Closed', true), 1001);
%! d = min (sqrt ((P(:,1) - Q(:,1)') .^ 2 + (P(:,2) - Q(:,2)') .^ 2), [], 2);
%! assert_equal (max (d) < 0.05, true);

%!test  # reversed: the same curve the other way round
%! SP = geom.Spline ([0, 0; 10, 5; 20, 0; 30, 5], ...
%!                   'Tangents', [1, 0, 0; NaN, NaN, NaN]);
%! R = __reversed__ (SP);
%! assert_equal (R.FitPoints, flipud (SP.FitPoints));
%! assert_equal (R.Tangents, [NaN, NaN, NaN; -1, 0, 0]);
%! assert_equal (points (R, 11), flipud (points (SP, 11)), 1e-10);
%! C = __reversed__ (geom.Spline ([0, 0; 10, 0; 5, 8], 'Closed', true));
%! assert_equal (C.FitPoints, [0, 0, 0; 5, 8, 0; 10, 0, 0]);

%!test  # directions kept as unit vectors
%! SP = geom.Spline ([0, 0; 1, 0], 'Tangents', [3, 4, 0; NaN, NaN, NaN]);
%! assert_equal (SP.Tangents, [0.6, 0.8, 0; NaN, NaN, NaN]);

%!test  # joined to a path, the spline first
%! P = join (geom.Spline ([0, 0, 0; 5, 0, 5; 10, 0, 10]), ...
%!           geom.Path ([10, 0, 10; 10, 0, 20]));
%! assert_equal (class (P), 'geom.Path');
%! assert_equal (P.Splines{1}.Tangents(2,:), [0, 0, 1]);

%!test  # a rational quarter circle, exact
%! SP = geom.Spline.nurbs ([10, 0; 10, 10; 0, 10], [0, 0, 0, 1, 1, 1], ...
%!                         [1; sqrt(2) / 2; 1]);
%! assert_equal (SP.Degree, 2);
%! assert_equal (SP.Closed, false);
%! assert_equal (isempty (SP.FitPoints), true);
%! P = points (SP, 101);
%! assert_equal (sqrt (sum (P .^ 2, 2)), 10 * ones (101, 1), 1e-12);
%! assert_equal (length (SP), 5 * pi, 1e-12);
%! assert_equal (__green__ (SP), 25 * pi, 1e-12);
%! [T1, T2] = __ends__ (SP);
%! assert_equal ([T1; T2], [0, 1, 0; -1, 0, 0], 1e-12);

%!test  # a whole circle of nine control points, closed
%! w = sqrt (2) / 2;
%! P = [1, 0; 1, 1; 0, 1; -1, 1; -1, 0; -1, -1; 0, -1; 1, -1; 1, 0];
%! SP = geom.Spline.nurbs (P, [0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 4], ...
%!                         [1, w, 1, w, 1, w, 1, w, 1]);
%! assert_equal (SP.Closed, true);
%! assert_equal (length (SP), 2 * pi, 1e-12);
%! assert_equal (__green__ (SP), pi, 1e-12);
%! Q = __sample__ (SP);
%! assert_equal (sqrt (sum (Q .^ 2, 2)), ones (rows (Q), 1), 1e-12);
%! assert_equal (rows (Q) >= 180, true);

%!test  # a cubic B-spline, not rational, reversed
%! SP = geom.Spline.nurbs ([0, 0; 1, 2; 3, 2; 4, 0], [0, 0, 0, 0, 1, 1, 1, 1]);
%! R = __reversed__ (SP);
%! assert_equal (points (R, 7), flipud (points (SP, 7)), 1e-12);
%! assert_equal (points (SP, 3)(2,:), [2, 1.5, 0], 1e-12);

%!test  # moved: control points, or the fit points drawn through again
%! SP = geom.Spline.nurbs ([0, 0; 1, 1; 2, 0], [0, 0, 0, 1, 1, 1]);
%! Q = __affine__ (SP, 2 * eye (3), [1, 0, 0]);
%! assert_equal (Q.ControlPoints, [1, 0, 0; 3, 2, 0; 5, 0, 0]);
%! F = __affine__ (geom.Spline ([0, 0; 1, 1; 2, 0]), 2 * eye (3), [0, 0, 1]);
%! assert_equal (F.FitPoints, [0, 0, 1; 2, 2, 1; 4, 0, 1]);
%! assert_equal (F.Knots(end), 4 * sqrt (2), 1e-12);

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
%! geom.Spline ([0, 0; 1, 0], 'Periodic', true)
%!error<geom.Spline: Closed must be a logical scalar.> ...
%! geom.Spline ([0, 0; 1, 0; 1, 1], 'Closed', 'yes')
%!error<geom.Spline: a closed spline has no ends to give Tangents.> ...
%! geom.Spline ([0, 0; 1, 0; 1, 1], 'Closed', true, ...
%!              'Tangents', [1, 0, 0; NaN, NaN, NaN])
%!error<geom.Spline: a closed spline needs at least three points.> ...
%! geom.Spline ([0, 0; 1, 0], 'Closed', true)
%!error<geom.Spline: V must not repeat a point consecutively.> ...
%! geom.Spline ([0, 0; 1, 0; 0, 0], 'Closed', true)
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
%!error<geom.Spline.nurbs: invalid number of input arguments.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0])
%!error<geom.Spline.nurbs: Name/Value arguments must come in pairs.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0], [0, 0, 1, 1], 'UCS')
%!error<geom.Spline.nurbs: unknown parameter.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0], [0, 0, 1, 1], 'Closed', true)
%!error<geom.Spline.nurbs: UCS must be a geom.UCS object.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0], [0, 0, 1, 1], 'UCS', 1)
%!error<geom.Spline.nurbs: P must be an N-by-2 or N-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Spline.nurbs ([0, 0], [0, 0, 1, 1])
%!error<geom.Spline.nurbs: KNOTS must be a nondecreasing real vector of at least N \+ 2 finite values, not all equal.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0], [0, 1, 1])
%!error<geom.Spline.nurbs: KNOTS must be a nondecreasing real vector of at least N \+ 2 finite values, not all equal.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0], [0, 1, 0, 1])
%!error<geom.Spline.nurbs: KNOTS must be a nondecreasing real vector of at least N \+ 2 finite values, not all equal.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0], [1, 1, 1, 1])
%!error<geom.Spline.nurbs: KNOTS must repeat its first and its last value one more time than the degree.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0; 2, 1], [0, 0, 0, 0.5, 1, 1])
%!error<geom.Spline.nurbs: an inner knot may be repeated no more times than the degree.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0; 2, 1; 3, 3], [0, 0, 0.5, 0.5, 1, 1])
%!error<geom.Spline.nurbs: the degree must be at most 25.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0], [zeros(1, 27), ones(1, 27)])
%!error<geom.Spline.nurbs: W must be a vector of N positive finite weights.> ...
%! geom.Spline.nurbs ([0, 0; 1, 0], [0, 0, 1, 1], [1, 0])

%!test  # an ellipse: closed, its area and its length exact
%! SP = geom.Spline.ellipse (20, 10);
%! assert_equal (SP.Closed, true);
%! assert_equal (SP.Degree, 2);
%! assert_equal (__green__ (SP), 200 * pi, -1e-12);
%! [~, E] = ellipke (1 - (10 / 20) ^ 2);
%! assert_equal (length (SP), 80 * E, -1e-10);
%! assert_equal (__box__ (SP), [-20, -10, 0; 20, 10, 0], 1e-12);

%!test  # an ellipse laid in a UCS; equal semi-axes, a circle
%! U = geom.UCS ([0, 0, 1], [5, 5, 0], [1, 1, 0]);
%! SP = geom.Spline.ellipse (4, 4, 'UCS', U);
%! assert_equal (SP.UCS, U);
%! P = toworld (U, points (SP, 17));
%! assert_equal (sqrt (sum ((P - [5, 5, 0]) .^ 2, 2)), 4 * ones (17, 1), 1e-12);

%!test  # stretched unevenly: control points moved, fit data dropped
%! SP = geom.Spline ([0, 0; 10, 5; 20, 0; 30, 5]);
%! T = __affine__ (SP, diag ([2, 1, 1]), [1, 0, 0]);
%! assert_equal (T.ControlPoints, SP.ControlPoints * diag ([2, 1, 1]) ...
%!               + [1, 0, 0]);
%! assert_equal (size (T.FitPoints), [0, 3]);
%! assert_equal (points (T, 7), points (SP, 7) * diag ([2, 1, 1]) ...
%!               + [1, 0, 0], 1e-12);

%!test  # the box round a spline drawn through points
%! SP = geom.Spline ([0, 0; 10, 8; 20, 0], 'Tangents', [0, 1, 0; 0, -1, 0]);
%! B = __box__ (SP);
%! P = points (SP, 100001);
%! assert_equal (B, [min(P, [], 1); max(P, [], 1)], 1e-8);

%!error<geom.Spline.ellipse: invalid number of input arguments.> ...
%! geom.Spline.ellipse (1)
%!error<geom.Spline.ellipse: A must be a positive and finite real scalar.> ...
%! geom.Spline.ellipse (0, 1)
%!error<geom.Spline.ellipse: B must be a positive and finite real scalar.> ...
%! geom.Spline.ellipse (1, Inf)
%!error<geom.Spline.ellipse: unknown parameter.> ...
%! geom.Spline.ellipse (1, 2, 'Centre', [0, 0])
%!error<geom.Spline.ellipse: UCS must be a geom.UCS object.> ...
%! geom.Spline.ellipse (1, 2, 'UCS', 3)

%!test  # write: geom.read gives back the spline, its fit data and frame
%! U = geom.UCS ([0, -1, 0], [5, 0, 0]);
%! SP = geom.Spline ([0, 0; 10, 10; 20, 0; 30, 10], ...
%!                   'Tangents', [0, 1, 0; NaN, NaN, NaN], 'UCS', U);
%! fn = [tempname(), '.dxf'];
%! unwind_protect
%!   write (SP, fn);
%!   C = geom.read (fn);
%!   assert_equal (C{1}.FitPoints, SP.FitPoints, 1e-12);
%!   assert_equal (C{1}.ControlPoints, SP.ControlPoints, 1e-9);
%!   assert_equal (C{1}.UCS.Normal, U.Normal, 1e-12);
%! unwind_protect_cleanup
%!   [~] = unlink (fn);
%! end_unwind_protect
%!test  # write: a rational spline keeps its weights
%! SP = geom.Spline.ellipse (10, 4);
%! fn = [tempname(), '.dxf'];
%! unwind_protect
%!   write (SP, fn);
%!   C = geom.read (fn);
%!   assert_equal (C{1}.Weights, SP.Weights, 1e-12);
%!   assert_equal (C{1}.Knots, SP.Knots, 1e-12);
%! unwind_protect_cleanup
%!   [~] = unlink (fn);
%! end_unwind_protect

%!error<geom.Spline.write: invalid number of input arguments.> ...
%! write (geom.Spline ([0, 0; 1, 1; 2, 0]))
%!error<geom.Spline.write: R12 holds only lines and arcs, not a spline.> ...
%! write (geom.Spline ([0, 0; 1, 1; 2, 0]), 'a.dxf', 'Version', 'R12')
