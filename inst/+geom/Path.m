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
  ## A path of straight segments, circular arcs and splines in three
  ## dimensions.
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
  ## with @code{geom.Path.arc}.  A @code{geom.Spline} makes one smooth segment
  ## of its own.  Pieces are put end to end with @code{geom.Path.join}.
  ##
  ## A @code{geom.Path} is a value: every change makes a new one.
  ##
  ## @seealso{solid.sweep, geom.Spline, geom.Polyline, geom.Region, geom.UCS}
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
    ## @deftp {geom.Path} {property} Splines
    ##
    ## Splines of the path
    ##
    ## An @math{M}-by-1 cell whose element @math{i} is the @code{geom.Spline}
    ## of the segment leaving vertex @math{i}, its points in the path's
    ## coordinates, or empty where that segment is a straight segment or an
    ## arc.
    ##
    ## @end deftp
    Splines = cell (0, 1);

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
      printf ("  geom.Path: %s, %d segments, %d arcs, %d splines\n", c, ...
              rows (this.Vertices) - ! this.Closed, ...
              nnz (! isnan (this.Midpoints(:,1))), ...
              nnz (! cellfun (@isempty, this.Splines)));

    endfunction

    ## The unit directions of the path at the start and the end of each of its
    ## segments, in its coordinates
    function [tin, tout] = __tangents__ (this)

      [tin, tout] = tangents (this.Vertices, this.Midpoints, this.Splines, ...
                              this.Closed);

    endfunction

    ## The path as Open CASCADE takes it, all in world coordinates: its
    ## vertices, the midpoints of its arcs, NaN for a segment that is not an
    ## arc, a cell with, for each spline segment, its control points, their
    ## weights, its distinct knots and their multiplicities and its degree,
    ## its end control points set on the vertices so that the wire closes
    ## exactly, and whether the path is closed
    function D = __data__ (this)

      V = toworld (this.UCS, this.Vertices);
      M = this.Midpoints;
      arc = ! isnan (M(:,1));
      M(arc,:) = toworld (this.UCS, M(arc,:));
      n = rows (V);
      C = cell (n, 1);
      for i = find (! cellfun (@isempty, this.Splines))'
        SP = this.Splines{i};
        B = toworld (this.UCS, SP.ControlPoints);
        B([1, end],:) = V([i, mod(i, n) + 1],:);
        [k, ~, j] = unique (SP.Knots);
        C{i} = struct ('poles', B, 'weights', SP.Weights, 'knots', k(:), ...
                       'mults', accumarray (j(:), 1), 'degree', SP.Degree);
      endfor
      D = struct ('vertices', V, 'midpoints', M, 'splines', {C}, ...
                  'closed', this.Closed);

    endfunction

    ## The same path run the other way round, a closed one from the same first
    ## vertex: each segment reversed and moved to the vertex it now leaves
    function this = __reversed__ (this)

      n = rows (this.Vertices);
      if (this.Closed)
        k = [1, n:-1:2];
        g = k([2:end, 1]);
      else
        k = n:-1:1;
        g = [n-1:-1:1, n];
      endif
      M = this.Midpoints(g,:);
      S = this.Splines(g);
      if (! this.Closed)
        M(end,:) = NaN;
        S{end} = [];
      endif
      for i = find (! cellfun (@isempty, S))'
        S{i} = __reversed__ (S{i});
      endfor
      this.Vertices = this.Vertices(k,:);
      this.Midpoints = M;
      this.Splines = S;

    endfunction

    ## The same path where it lies, its coordinates given in the UCS U
    function this = __into__ (this, U)

      [this.Vertices, this.Midpoints, this.Splines] = into (this, U);
      this.UCS = U;

    endfunction

    ## The path scaled by the factor F about the origin of its UCS
    function this = __scaled__ (this, F)

      this.Vertices *= F;
      this.Midpoints *= F;
      for i = find (! cellfun (@isempty, this.Splines))'
        this.Splines{i} = __affine__ (this.Splines{i}, F * eye (3), 0);
      endfor

    endfunction

    ## Points along the path in its coordinates, arcs every 2 degrees or
    ## closer and splines as finely, closed paths not repeating the first
    function Q = __sample__ (this)

      V = this.Vertices;
      M = this.Midpoints;
      S = this.Splines;
      n = rows (V);
      Q = cell (n, 1);
      for i = 1:n
        Q{i} = V(i,:);
        if (! this.Closed && i == n)
          break;
        endif
        B = V(mod (i, n) + 1,:);
        if (! isempty (S{i}))
          Q{i} = __sample__ (S{i})(1:end-1,:);
        elseif (! isnan (M(i,1)))
          [C, x, y, th] = circle (V(i,:), M(i,:), B);
          r = norm (V(i,:) - C);
          f = (1:ceil (th / (pi / 90)) - 1)' / ceil (th / (pi / 90)) * th;
          Q{i} = [Q{i}; C + r * (cos (f) * x + sin (f) * y)];
        endif
      endfor
      Q = vertcat (Q{:});

    endfunction

    ## The signed area the closed path encloses in the plane of its UCS,
    ## positive anticlockwise: from every segment its share of the integral of
    ## x dy - y dx, exact for straight segments, arcs and splines alike
    function A = __area__ (this)

      V = this.Vertices;
      M = this.Midpoints;
      S = this.Splines;
      n = rows (V);
      A = 0;
      for i = 1:n
        B = V(mod (i, n) + 1,:);
        if (! isempty (S{i}))
          A += __green__ (S{i});
        else
          A += (V(i,1) * B(2) - B(1) * V(i,2)) / 2;
          if (! isnan (M(i,1)))
            ## The circular segment between the chord and the arc, added where
            ## the arc lies to the right of the chord
            d = B(1:2) - V(i,1:2);
            e = M(i,1:2) - V(i,1:2);
            c = norm (d);
            sg = norm (M(i,1:2) - (V(i,1:2) + B(1:2)) / 2);
            th = 4 * atan (2 * sg / c);
            r = c / (2 * sin (th / 2));
            A -= sign (d(1) * e(2) - d(2) * e(1)) * r ^ 2 / 2 ...
                 * (th - sin (th));
          endif
        endif
      endfor

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Path} {@var{P} =} geom.Path (@var{V})
    ## @deftypefnx {geom.Path} {@var{P} =} geom.Path (@var{V}, @var{Name}, @var{Value}, @dots{})
    ## @deftypefnx {geom.Path} {@var{P} =} geom.Path (@var{PL})
    ## @deftypefnx {geom.Path} {@var{P} =} geom.Path (@var{SP})
    ##
    ## Make a path.
    ##
    ## @code{@var{P} = geom.Path (@var{V})} makes an open path of straight
    ## segments through the points given as rows of @var{V}, an @math{M}-by-3
    ## matrix in millimetres, or an @math{M}-by-2 matrix of points in the plane
    ## of the UCS, with at least two rows.
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
    ## @code{@var{P} = geom.Path (@var{SP})} makes the path of one segment
    ## along the @code{geom.Spline} @var{SP}, in its UCS.  A closed spline
    ## makes a closed path of one vertex, its first point, the spline running
    ## from it round and back.
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
        this.Splines = cell (rows (this.Vertices), 1);
        this.Closed = V.Closed;
        this.UCS = V.UCS;
        return;
      endif
      if (isa (V, 'geom.Spline'))
        if (nargin > 1)
          error ("geom.Path: invalid number of input arguments.");
        endif
        SP = V;
        SP.UCS = geom.UCS ();
        if (SP.Closed)
          this.Vertices = SP.ControlPoints(1,:);
          this.Midpoints = NaN (1, 3);
          this.Splines = {SP};
          this.Closed = true;
        else
          this.Vertices = SP.ControlPoints([1, end],:);
          this.Midpoints = NaN (2, 3);
          this.Splines = {SP; []};
        endif
        this.UCS = V.UCS;
        return;
      endif
      if (! isnumeric (V) || ! isreal (V) || ! ismatrix (V) ...
          || ! any (columns (V) == [2, 3]) || rows (V) < 2 ...
          || ! all (isfinite (V(:))))
        error (strcat ("geom.Path: V must be an M-by-2 or M-by-3 real", ...
                       " matrix of finite values with at least two rows."));
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
      if (columns (V) == 2)
        V(:,3) = 0;
      endif
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
      this.Splines = cell (rows (V), 1);
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
    ## joined by the arc.  Corners where an arc or a spline meets a segment are
    ## left as they are, and so are the two ends of an open path.
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
      [errmsg, C] = corners (this, IDX);
      if (! isempty (errmsg))
        error ("geom.Path.fillet: %s", errmsg);
      endif

      ## How far back along each segment the round at either end reaches
      t = zeros (1, rows (this.Vertices));
      t(C.idx) = RADIUS * tan (C.th(C.idx) / 2);
      errmsg = fits (C, t, t, "round");
      if (! isempty (errmsg))
        error ("geom.Path.fillet: %s", errmsg);
      endif

      ## Each rounded corner becomes the arc between its tangent points, the
      ## middle of the arc on the bisector of the corner
      Mid = NaN (rows (this.Vertices), 3);
      for i = C.idx
        d = C.v(i,:) / C.lv(i) - C.u(i,:) / C.lu(i);
        Mid(i,:) = this.Vertices(i,:) ...
                   + d / norm (d) * RADIUS * (1 / cos (C.th(i) / 2) - 1);
      endfor
      this = cut (this, C, t, t, Mid);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Path} {@var{P} =} chamfer (@var{P}, @var{D})
    ## @deftypefnx {geom.Path} {@var{P} =} chamfer (@var{P}, [@var{D1}, @var{D2}])
    ## @deftypefnx {geom.Path} {@var{P} =} chamfer (@dots{}, @var{IDX})
    ## @deftypefnx {geom.Path} {@var{P} =} chamfer (@dots{}, @qcode{'Angle'}, @var{A})
    ##
    ## Cut the corners of a path.
    ##
    ## @code{@var{P} = chamfer (@var{P}, @var{D})} cuts every corner where two
    ## straight segments meet with a straight segment from @var{D} millimetres
    ## back along the segment before the corner to @var{D} along the segment
    ## after it.  Corners where an arc or a spline meets a segment are left as
    ## they are, and so are the two ends of an open path.
    ##
    ## @code{@var{P} = chamfer (@var{P}, [@var{D1}, @var{D2}])} cuts back
    ## @var{D1} along the segment before each corner and @var{D2} along the
    ## segment after it, before and after in the order of the vertices.
    ##
    ## @code{@var{P} = chamfer (@var{P}, @var{D}, @qcode{'Angle'}, @var{A})}
    ## cuts back @var{D} along the segment before each corner, with the cut at
    ## @var{A} degrees to that segment.
    ##
    ## @code{@var{P} = chamfer (@dots{}, @var{IDX})} cuts only the corners at
    ## the vertices indexed by @var{IDX}, each of which must be a corner
    ## between two straight segments.
    ##
    ## A cut that would run past the end of a segment, or into the cut or round
    ## of the next corner, or an angle at which the cut misses the segment
    ## after the corner, is refused.
    ##
    ## @seealso{geom.Path.fillet, geom.Polyline.chamfer}
    ## @end deftypefn
    function this = chamfer (this, D, varargin)

      ## Input validation
      if (nargin < 2)
        error ("geom.Path.chamfer: invalid number of input arguments.");
      endif
      if (! isnumeric (D) || ! isreal (D) || ! isvector (D) ...
          || numel (D) > 2 || ! all (isfinite (D)) || ! all (D > 0))
        error (strcat ("geom.Path.chamfer: D must be one positive finite", ...
                       " distance, or two."));
      endif
      IDX = [];
      if (mod (numel (varargin), 2) == 1)
        IDX = varargin{1};
        varargin(1) = [];
      endif
      A = [];
      for k = 1:2:numel (varargin)
        if (! ischar (varargin{k}) || ! strcmp (varargin{k}, 'Angle'))
          error ("geom.Path.chamfer: unknown parameter.");
        endif
        A = varargin{k+1};
        if (! isnumeric (A) || ! isreal (A) || ! isscalar (A) ...
            || ! (A > 0) || ! (A < 180))
          error (strcat ("geom.Path.chamfer: Angle must be in the range", ...
                         " (0, 180) degrees."));
        endif
      endfor
      if (! isempty (A) && numel (D) == 2)
        error ("geom.Path.chamfer: an angle goes with one distance D.");
      endif
      [errmsg, C] = corners (this, IDX);
      if (! isempty (errmsg))
        error ("geom.Path.chamfer: %s", errmsg);
      endif

      ## How far back along the segments before and after each corner
      n = rows (this.Vertices);
      tin = zeros (1, n);
      tout = zeros (1, n);
      tin(C.idx) = D(1);
      tout(C.idx) = D(end);
      if (! isempty (A))
        ## The angle at the corner, and so the triangle the cut makes
        far = pi - A * pi / 180 - (pi - C.th(C.idx));
        bad = C.idx(far <= 1e-12);
        if (! isempty (bad))
          error (strcat ("geom.Path.chamfer: the chamfer at vertex %d", ...
                         " misses the segment after it at that angle."), ...
                 bad(1));
        endif
        tout(C.idx) = D * sind (A) ./ sin (far);
      endif
      errmsg = fits (C, tin, tout, "chamfer");
      if (! isempty (errmsg))
        error ("geom.Path.chamfer: %s", errmsg);
      endif

      this = cut (this, C, tin, tout, NaN (n, 3));

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Path} {@var{P} =} join (@var{P1}, @var{P2}, @dots{})
    ## @deftypefnx {geom.Path} {@var{P} =} join (@dots{}, @qcode{'Tangent'}, @var{TF})
    ##
    ## Put paths and splines end to end.
    ##
    ## @code{@var{P} = join (@var{P1}, @var{P2}, @dots{})} returns the path
    ## that runs along @var{P1}, then @var{P2}, and so on, each a
    ## @code{geom.Path} or a @code{geom.Spline}.  Each path must be open and
    ## begin where the piece before it ends.  The pieces need not meet
    ## smoothly: where they meet at an angle, the path has a corner.  When the
    ## last piece ends where the first begins, the path is closed.  The path
    ## is in the UCS of @var{P1}, the others' points carried into it.
    ##
    ## Where a free end of a spline drawn through points meets a straight
    ## segment, an arc or a spline end with a direction of its own, the spline
    ## takes that direction, so the path runs on smoothly there.  A spline made
    ## from control points is kept as it is.  With
    ## @qcode{'Tangent'} set to @code{false}, free ends stay free and the
    ## path may have a corner there.
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
      k = find (cellfun (@ischar, varargin), 1);
      opts = {};
      if (! isempty (k))
        opts = varargin(k:end);
        varargin = varargin(1:k-1);
      endif
      if (numel (varargin) < 2)
        error ("geom.Path.join: invalid number of input arguments.");
      endif
      if (mod (numel (opts), 2) != 0)
        error ("geom.Path.join: Name/Value arguments must come in pairs.");
      endif
      tangent = true;
      for k = 1:2:numel (opts)
        if (! strcmp (opts{k}, 'Tangent'))
          error ("geom.Path.join: unknown parameter.");
        endif
        tangent = opts{k+1};
        if (! (islogical (tangent) || isnumeric (tangent)) ...
            || ! isscalar (tangent) || ! any (tangent == [0, 1]))
          error ("geom.Path.join: Tangent must be a logical scalar.");
        endif
      endfor
      for k = 1:numel (varargin)
        P = varargin{k};
        if (isa (P, 'geom.Spline') && isscalar (P))
          varargin{k} = geom.Path (P);
        elseif (! isa (P, 'geom.Path') || ! isscalar (P))
          error (strcat ("geom.Path.join: every piece must be a geom.Path", ...
                         " or a geom.Spline object."));
        elseif (P.Closed)
          error ("geom.Path.join: path %d is closed.", k);
        endif
      endfor

      this = varargin{1};
      V = this.Vertices;
      M = this.Midpoints;
      S = this.Splines;
      joints = [];
      for k = 2:numel (varargin)
        [W, N, C] = into (varargin{k}, this.UCS);
        tol = 1e-9 * max ([1, max(abs (V(:))), max(abs (W(:)))]);
        if (norm (W(1,:) - V(end,:)) > tol)
          error (strcat ("geom.Path.join: path %d does not begin where", ...
                         " path %d ends."), k, k - 1);
        endif
        joints(end+1) = rows (V);
        M = [M(1:end-1,:); N];
        S = [S(1:end-1); C];
        V = [V; W(2:end,:)];
      endfor

      ## A path ending where it began is closed
      tol = 1e-9 * max (1, max (abs (V(:))));
      closed = rows (V) > 2 && norm (V(end,:) - V(1,:)) <= tol;
      if (closed)
        V(end,:) = [];
        M(end,:) = [];
        S(end) = [];
        joints(end+1) = 1;
      endif

      ## A free end of a spline drawn through points takes the direction of
      ## what it meets, unless that is a free spline end too
      if (tangent)
        [tin, tout] = tangents (V, M, S, closed);
        n = rows (V);
        free = @(SP, e) ! isempty (SP) && ! isempty (SP.FitPoints) ...
                        && isnan (SP.Tangents(e,1));
        for j = joints
          in = j - 1 + n * (j == 1);
          fin = free (S{in}, 2);
          fout = free (S{j}, 1);
          if (fout && ! fin)
            T = S{j}.Tangents;
            T(1,:) = tout(in,:);
            S{j} = geom.Spline (S{j}.FitPoints, 'Tangents', T);
          elseif (fin && ! fout)
            T = S{in}.Tangents;
            T(2,:) = tin(j,:);
            S{in} = geom.Spline (S{in}.FitPoints, 'Tangents', T);
          endif
        endfor
      endif

      this.Vertices = V;
      this.Midpoints = M;
      this.Splines = S;
      this.Closed = closed;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn {geom.Path} {@var{L} =} length (@var{P})
    ##
    ## The length of a path.
    ##
    ## @code{@var{L} = length (@var{P})} returns the length of the path
    ## @var{P} in millimetres along its arcs and splines, including the
    ## segment that closes a closed path.
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
      for i = find (! cellfun (@isempty, this.Splines(1:rows (c))))'
        c(i) = length (this.Splines{i});
      endfor
      L = sum (c);

    endfunction

  endmethods

  methods (Access = private)

    ## The path P with each corner of C replaced by the points TIN back along
    ## the segment into it and TOUT along the segment out of it, joined by an
    ## arc through MID or a straight segment where MID is NaN.  A straight
    ## segment that the cuts at its ends used up is dropped.
    function P = cut (P, C, TIN, TOUT, MID)

      V = P.Vertices;
      W = num2cell (V, 2);
      N = num2cell (P.Midpoints, 2);
      S = num2cell (P.Splines);
      for i = C.idx
        a = V(i,:) - TIN(i) * C.u(i,:) / C.lu(i);
        b = V(i,:) + TOUT(i) * C.v(i,:) / C.lv(i);
        W{i} = [a; b];
        N{i} = [MID(i,:); NaN, NaN, NaN];
        S{i} = cell (2, 1);
      endfor
      W = vertcat (W{:});
      N = vertcat (N{:});
      S = vertcat (S{:});
      k = rows (W);
      if (P.Closed)
        L = sqrt (sum ((W([2:k, 1],:) - W) .^ 2, 2));
      else
        L = [sqrt(sum (diff (W) .^ 2, 2)); Inf];
      endif
      gone = isnan (N(:,1)) & cellfun (@isempty, S) & L <= 1e-9 * max (C.lv);
      P.Vertices = W(! gone,:);
      P.Midpoints = N(! gone,:);
      P.Splines = S(! gone);

    endfunction

  endmethods

  methods (Static, Hidden)

    ## The closed path through PIECES in turn, each a line, an arc through
    ## three points or a B-spline, as Open CASCADE hands back the loops of a
    ## face lying in the plane z = 0
    function P = __loop__ (pieces)

      ## Lines that follow one another make one polyline, so that a loop of
      ## many short segments is joined in a few pieces
      Q = {};
      run = zeros (0, columns (pieces{1}.points));
      for i = 1:numel (pieces)
        c = pieces{i};
        if (strcmp (c.type, 'line'))
          if (isempty (run))
            run = c.points;
          else
            run(end+1,:) = c.points(end,:);
          endif
          continue;
        endif
        if (! isempty (run))
          Q{end+1} = geom.Path (run);
          run = zeros (0, columns (c.points));
        endif
        if (strcmp (c.type, 'arc'))
          Q{end+1} = geom.Path.arc (c.points(1,:), c.points(2,:), ...
                                    c.points(3,:));
        else
          Q{end+1} = geom.Spline.nurbs (c.points, ...
                                        repelem (c.knots', c.mults'), ...
                                        c.weights);
        endif
      endfor
      if (! isempty (run))
        Q{end+1} = geom.Path (run);
      endif
      if (numel (Q) > 1)
        P = join (Q{:}, 'Tangent', false);
      elseif (isa (Q{1}, 'geom.Spline'))
        P = geom.Path (Q{1});
      else
        P = geom.Path (run(1:end-1,:), 'Closed', true);
      endif

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

      ## The point half way round from P1 to P2 through PM
      [C, x, y, th] = circle (P1, PM, P2);
      r = norm (P1 - C);
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

## The corners of the path P that IDX names, or all of them where two straight
## segments meet when IDX is empty: their indices, the vectors into and out of
## every vertex and their lengths, the angle the path turns through there, and
## its neighbours.  Returns an error message body, empty when IDX names only
## such corners.
function [errmsg, C] = corners (P, IDX)

  errmsg = '';
  V = P.Vertices;
  n = rows (V);
  if (P.Closed)
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
  straight = isnan (P.Midpoints(:,1))' & cellfun (@isempty, P.Splines)';
  corner = ! ends & straight(prev) & straight & th > 1e-12;
  if (isempty (IDX))
    IDX = find (corner);
  elseif (! isnumeric (IDX) || ! isreal (IDX) || ! isvector (IDX) ...
          || any (IDX != fix (IDX)) || any (IDX < 1) || any (IDX > n))
    errmsg = "IDX must be a vector of vertex indices of P.";
  else
    IDX = unique (double (IDX(:)'));
    bad = IDX(! corner(IDX));
    if (! isempty (bad))
      errmsg = sprintf (strcat ("vertex %d is not a corner between two", ...
                                " straight segments."), bad(1));
    endif
  endif
  C = struct ('idx', IDX, 'u', u, 'v', v, 'lu', lu, 'lv', lv, 'th', th, ...
              'prev', prev, 'next', next);

endfunction

## Whether the cuts TIN back along the segment into each corner and TOUT
## along the segment out of it fit, the cut at one end of a segment clear of
## the cut at the other.  Returns an error message body naming the first
## corner, WHAT, that does not fit.
function errmsg = fits (C, TIN, TOUT, WHAT)

  errmsg = '';
  for i = C.idx
    if (TOUT(i) + TIN(C.next(i)) > C.lv(i) * (1 + 1e-12) ...
        || TIN(i) + TOUT(C.prev(i)) > C.lu(i) * (1 + 1e-12))
      errmsg = sprintf ("the %s at vertex %d does not fit its segments.", ...
                        WHAT, i);
      return;
    endif
  endfor

endfunction

## The circle through the points A, M and B in turn: its centre C, the unit
## vector X from it to A, the unit vector Y square to X in its plane towards
## the way round from A through M, and the angle TH from A round to B
function [C, X, Y, TH] = circle (A, M, B)

  a = A - M;
  b = B - M;
  n = cross (a, b);
  C = M + cross (dot (a, a) * b - dot (b, b) * a, n) / (2 * dot (n, n));
  X = (A - C) / norm (A - C);
  Y = cross (-n / norm (n), X);
  TH = mod (atan2 (dot (B - C, Y), dot (B - C, X)), 2 * pi);

endfunction

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

## The vertices, arc midpoints and splines of the path P as coordinates in
## the UCS U
function [V, M, S] = into (P, U)

  V = P.Vertices;
  M = P.Midpoints;
  S = P.Splines;
  A = P.UCS;
  if (! (A == U))
    arc = ! isnan (M(:,1));
    V = tolocal (U, toworld (A, V));
    M(arc,:) = tolocal (U, toworld (A, M(arc,:)));
    R = [A.XAxis; A.YAxis; A.Normal] * [U.XAxis; U.YAxis; U.Normal]';
    b = (A.Origin - U.Origin) * [U.XAxis; U.YAxis; U.Normal]';
    for i = find (! cellfun (@isempty, S))'
      S{i} = __affine__ (S{i}, R, b);
    endfor
  endif

endfunction

## The unit directions at the start and the end of each segment of the path
## through the vertices V, with arc midpoints M and splines S.  The tangent at
## either end of an arc is the chord reflected in the chord to the arc's
## middle; a spline's is its own.
function [tin, tout] = tangents (A, M, S, closed)

  B = A([2:end, 1],:);
  if (! closed)
    A(end,:) = [];
    B(end,:) = [];
    M(end,:) = [];
    S(end) = [];
  endif
  d = unit (B - A);
  tin = d;
  tout = d;
  arc = ! isnan (M(:,1));
  if (any (arc))
    a = unit (M(arc,:) - A(arc,:));
    b = unit (B(arc,:) - M(arc,:));
    tin(arc,:) = 2 * sum (d(arc,:) .* a, 2) .* a - d(arc,:);
    tout(arc,:) = 2 * sum (d(arc,:) .* b, 2) .* b - d(arc,:);
  endif
  for i = find (! cellfun (@isempty, S))'
    [tin(i,:), tout(i,:)] = __ends__ (S{i});
  endfor

endfunction

function U = unit (V)

  U = V ./ sqrt (sum (V .^ 2, 2));

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

%!test  # a spline as a path of one segment
%! U = geom.UCS ([1, 0, 0], [1, 2, 3]);
%! SP = geom.Spline ([0, 0; 10, 5; 20, 0], 'UCS', U);
%! P = geom.Path (SP);
%! assert_equal (P.Vertices, [0, 0, 0; 20, 0, 0]);
%! assert_equal (P.UCS, SP.UCS);
%! assert_equal (P.Splines{1}.FitPoints, SP.FitPoints);
%! assert_equal (length (P), length (SP), 1e-12);

%!test  # a free spline end takes the direction of the line it meets
%! SP = geom.Spline ([0, 0, 10; 5, 0, 20; 10, 0, 30]);
%! P = join (geom.Path ([0, 0, 0; 0, 0, 10]), SP, ...
%!           geom.Path ([10, 0, 30; 20, 0, 30]));
%! assert_equal (P.Splines{2}.Tangents, [0, 0, 1; 1, 0, 0]);
%! [tin, tout] = __tangents__ (P);
%! assert_equal (tout(1:2,:), tin(2:3,:), 1e-12);
%! assert_equal (length (P), 20 + length (P.Splines{2}), 1e-12);

%!test  # an end with its own direction is kept, and opting out keeps free
%! SP = geom.Spline ([0, 0, 10; 5, 0, 20; 10, 0, 30], ...
%!                   'Tangents', [1, 0, 1; NaN, NaN, NaN]);
%! P = join (geom.Path ([0, 0, 0; 0, 0, 10]), SP);
%! assert_equal (P.Splines{2}.Tangents, [1, 0, 1; NaN, NaN, NaN] / sqrt (2), ...
%!               1e-15);
%! P = join (geom.Path ([0, 0, 0; 0, 0, 10]), geom.Spline (SP.FitPoints), ...
%!           'Tangent', false);
%! assert_equal (P.Splines{2}.Tangents, NaN (2, 3));

%!test  # a spline first, and the spline's end taken by an arc after it
%! SP = geom.Spline ([0, 0, 0; 5, 0, 5; 10, 0, 0]);
%! P = join (SP, geom.Path.arc ([10, 0, 0], [15, 5, 0], [20, 0, 0]));
%! assert_equal (P.Splines{1}.Tangents(2,:), [0, 1, 0], 1e-12);
%! assert_equal (isnan (P.Splines{1}.Tangents(1,1)), true);

%!test  # a spline carried into the first piece's UCS
%! SP = geom.Spline ([0, 0; 5, 5; 10, 0], 'Tangents', [1, 0, 0; NaN, NaN, NaN]);
%! SP.UCS = geom.UCS ([1, 0, 0], [0, 0, 10]);
%! P = join (geom.Path ([0, 0, 0; 0, 0, 10]), SP, 'Tangent', false);
%! assert_equal (P.Splines{2}.FitPoints, [0, 0, 10; 0, 5, 15; 0, 10, 10], ...
%!               1e-12);
%! assert_equal (P.Splines{2}.Tangents(1,:), [0, 1, 0], 1e-12);

%!test  # a corner next to a spline is not rounded
%! P = join (geom.Path ([0, 0, 0; 10, 0, 0; 10, 10, 0]), ...
%!           geom.Spline ([10, 10, 0; 15, 15, 0; 10, 20, 0]));
%! Q = fillet (P, 2);
%! assert_equal (rows (Q.Vertices), rows (P.Vertices) + 1);
%! assert_equal (Q.Splines{4}.FitPoints, P.Splines{3}.FitPoints);

%!test  # points in the plane of the UCS
%! P = geom.Path ([0, 0; 10, 0; 10, 5]);
%! assert_equal (P.Vertices, [0, 0, 0; 10, 0, 0; 10, 5, 0]);

%!test  # a closed spline, a closed path of one vertex
%! SP = geom.Spline ([0, 0; 30, -5; 45, 15; 25, 30; 5, 20], 'Closed', true);
%! P = geom.Path (SP);
%! assert_equal (P.Closed, true);
%! assert_equal (P.Vertices, [0, 0, 0]);
%! assert_equal (length (P), length (SP), 1e-12);
%! P = fillet (P, 1);
%! assert_equal (rows (P.Vertices), 1);
%! [tin, tout] = __tangents__ (P);
%! assert_equal (tin, tout, 1e-12);

%!test  # every corner of a closed path cut, two distances
%! P = geom.Path ([0, 0; 60, 0; 60, 40; 0, 40], 'Closed', true);
%! Q = chamfer (P, [3, 2]);
%! assert_equal (Q.Vertices(1:2,:), [0, 3, 0; 2, 0, 0], 1e-12);
%! assert_equal (rows (Q.Vertices), 8);
%! assert_equal (all (isnan (Q.Midpoints(:))), true);

%!test  # a corner cut at an angle, out of the xy plane
%! P = geom.Path ([0, 0, 0; 0, 0, 20; 10, 0, 20]);
%! Q = chamfer (P, 3, 'Angle', 30);
%! assert_equal (Q.Vertices(2:3,:), [0, 0, 17; 3 * tand(30), 0, 20], 1e-12);

%!test  # reversed: the same path the other way round
%! P = join (geom.Path ([0, 0; 10, 0]), ...
%!           geom.Path.arc ([10, 0, 0], [15, 5, 0], [20, 0, 0]), ...
%!           geom.Spline ([20, 0; 25, -5; 30, 0]));
%! R = __reversed__ (P);
%! assert_equal (R.Vertices, flipud (P.Vertices));
%! assert_equal (R.Midpoints(2,:), [15, 5, 0], 1e-12);
%! assert_equal (R.Splines{1}.FitPoints, flipud (P.Splines{3}.FitPoints));
%! assert_equal (length (R), length (P), 1e-12);

%!test  # area: a square, a disc of two arcs, a closed spline's polygon
%! assert_equal (__area__ (geom.Path ([0, 0; 4, 0; 4, 3; 0, 3], ...
%!                                    'Closed', true)), 12);
%! D = geom.Path (geom.Polyline ([0, 0, 1; 10, 0, 1], 'Closed', true));
%! assert_equal (__area__ (D), 25 * pi, 1e-12);
%! assert_equal (__area__ (__reversed__ (D)), -25 * pi, 1e-12);
%! SP = geom.Spline ([0, 0; 30, -5; 45, 15; 25, 30; 5, 20], 'Closed', true);
%! Q = points (SP, 20001);
%! assert_equal (__area__ (geom.Path (SP)), polyarea (Q(:,1), Q(:,2)), -1e-7);

%!test  # sampled: arcs every 2 degrees, a spline finely
%! D = geom.Path (geom.Polyline ([0, 0, 1; 10, 0, 1], 'Closed', true));
%! Q = __sample__ (D);
%! assert_equal (rows (Q), 180);
%! assert_equal (max (abs (hypot (Q(:,1) - 5, Q(:,2)) - 5)), 0, 1e-12);

%!test  # joined end to start, closed
%! P = join (geom.Path ([0, 0, 0; 10, 0, 0]), ...
%!           geom.Path.arc ([10, 0, 0], [5, 5, 0], [0, 0, 0]));
%! assert_equal (P.Closed, true);
%! assert_equal (rows (P.Vertices), 2);
%! assert_equal (length (P), 10 + 5 * pi, 1e-12);

%!error<geom.Path: invalid number of input arguments.> geom.Path ()
%!error<geom.Path: invalid number of input arguments.> ...
%! geom.Path (geom.Polyline ([0, 0; 1, 0]), 'Closed', true)
%!error<geom.Path: V must be an M-by-2 or M-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Path ([0, 0, 0])
%!error<geom.Path: V must be an M-by-2 or M-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Path ([0, 0, 0, 0; 1, 0, 0, 0])
%!error<geom.Path: V must be an M-by-2 or M-by-3 real matrix of finite values with at least two rows.> ...
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
%!error<geom.Path.join: every piece must be a geom.Path or a geom.Spline object.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]), [1, 0, 0; 2, 0, 0])
%!error<geom.Path.join: invalid number of input arguments.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]), 'Tangent', false)
%!error<geom.Path.join: Name/Value arguments must come in pairs.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]), geom.Path ([1, 0, 0; 2, 0, 0]), ...
%!       'Tangent')
%!error<geom.Path.join: unknown parameter.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]), geom.Path ([1, 0, 0; 2, 0, 0]), ...
%!       'Smooth', true)
%!error<geom.Path.join: Tangent must be a logical scalar.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]), geom.Path ([1, 0, 0; 2, 0, 0]), ...
%!       'Tangent', 2)
%!error<geom.Path.join: path 2 is closed.> ...
%! join (geom.Path ([0, 0, 0; 1, 0, 0]), ...
%!       geom.Path ([1, 0, 0; 2, 0, 0; 2, 1, 0], 'Closed', true))
%!error<geom.Path.chamfer: invalid number of input arguments.> ...
%! chamfer (geom.Path ([0, 0; 1, 0]))
%!error<geom.Path.chamfer: D must be one positive finite distance, or two.> ...
%! chamfer (geom.Path ([0, 0; 1, 0; 1, 1]), [1, 2, 3])
%!error<geom.Path.chamfer: unknown parameter.> ...
%! chamfer (geom.Path ([0, 0; 1, 0; 1, 1]), 0.1, 'Slope', 30)
%!error<geom.Path.chamfer: Angle must be in the range \(0, 180\) degrees.> ...
%! chamfer (geom.Path ([0, 0; 1, 0; 1, 1]), 0.1, 'Angle', 0)
%!error<geom.Path.chamfer: an angle goes with one distance D.> ...
%! chamfer (geom.Path ([0, 0; 1, 0; 1, 1]), [0.1, 0.2], 'Angle', 30)
%!error<geom.Path.chamfer: IDX must be a vector of vertex indices of P.> ...
%! chamfer (geom.Path ([0, 0; 1, 0; 1, 1]), 0.1, 7)
%!error<geom.Path.chamfer: vertex 3 is not a corner between two straight segments.> ...
%! chamfer (geom.Path ([0, 0; 1, 0; 1, 1]), 0.1, 3)
%!error<geom.Path.chamfer: the chamfer at vertex 2 misses the segment after it at that angle.> ...
%! chamfer (geom.Path ([0, 0; 1, 0; 1, 1]), 0.1, 'Angle', 95)
%!error<geom.Path.chamfer: the chamfer at vertex 1 does not fit its segments.> ...
%! chamfer (geom.Path ([0, 0; 4, 0; 4, 10; 0, 10], 'Closed', true), 3)
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
