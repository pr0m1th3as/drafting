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
  ## The vertices are coordinates in the polyline's @code{geom.UCS}, so the
  ## same outline can be laid on any plane, as a CAD program's user coordinate
  ## system lays a sketch on a face.  By default it is the world @math{xy}
  ## plane, and assigning another UCS moves the polyline onto it.
  ##
  ## A @code{geom.Polyline} is a value: every change makes a new one.
  ##
  ## @seealso{geom.Region, geom.UCS, draw.Drawing.polyline}
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

  endproperties

  properties

    ## -*- texinfo -*-
    ## @deftp {geom.Polyline} {property} UCS
    ##
    ## Coordinate system of the vertices
    ##
    ## The @code{geom.UCS} the vertices are coordinates in, the world
    ## @math{xy} plane by default.  Assigning another moves the polyline onto
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
      vn = rows (this.Vertices);
      vw = 'vertex';
      if (vn > 1)
        vw = 'vertices';
      endif
      an = nnz (this.Vertices(:,3));
      aw = 'arc';
      if (an > 1)
        aw = 'arcs';
      endif
      printf ("  geom.Polyline: %s, %d %s, %d %s\n", c, vn, vw, an, aw);

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
    ## world @math{xy} plane through the vertices given as rows of @var{P}, in
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
    ## @item @qcode{'UCS'}
    ## The @code{geom.UCS} the vertices are coordinates in, the world
    ## @math{xy} plane by default.
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
      if (! isnumeric (P) || ! isreal (P) || ! ismatrix (P)
          || ! any (columns (P) == [2, 3]) || rows (P) < 2
          || ! all (isfinite (P(:))))
        error (strcat ("geom.Polyline: P must be an N-by-2 or N-by-3 real", ...
                       " matrix of finite values with at least two rows."));
      endif
      if (mod (numel (varargin), 2) != 0)
        error ("geom.Polyline: Name/Value arguments must come in pairs.");
      endif
      opt = struct ('Closed', false, 'UCS', geom.UCS ());
      for k = 1:2:numel (varargin)
        name = varargin{k};
        if (! ischar (name) || ! isrow (name)
            || ! any (strcmp (name, fieldnames (opt))))
          error ("geom.Polyline: unknown parameter.");
        endif
        opt.(name) = varargin{k+1};
      endfor
      if (! (islogical (opt.Closed) || isnumeric (opt.Closed))
          || ! isscalar (opt.Closed) || ! any (opt.Closed == [0, 1]))
        error ("geom.Polyline: Closed must be a logical scalar.");
      endif
      if (! isa (opt.UCS, 'geom.UCS') || ! isscalar (opt.UCS))
        error ("geom.Polyline: UCS must be a geom.UCS object.");
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
      this.UCS = opt.UCS;

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Polyline} {@var{PL} =} fillet (@var{PL}, @var{RADIUS})
    ## @deftypefnx {geom.Polyline} {@var{PL} =} fillet (@var{PL}, @var{RADIUS}, @var{IDX})
    ##
    ## Round the corners of a polyline.
    ##
    ## @code{@var{PL} = fillet (@var{PL}, @var{RADIUS})} rounds every corner
    ## where two straight segments meet with an arc of radius @var{RADIUS}
    ## millimetres, tangent to both: the corner vertex becomes the two points
    ## where the arc meets the segments, joined by the arc.  Corners where an
    ## arc meets a segment are left as they are, and so are the two ends of an
    ## open polyline.
    ##
    ## @code{@var{PL} = fillet (@var{PL}, @var{RADIUS}, @var{IDX})} rounds
    ## only the corners at the vertices indexed by @var{IDX}, each of which
    ## must be a corner between two straight segments.
    ##
    ## A radius too large for a corner, whose arc would run past the end of a
    ## segment or into the round of the next corner, is refused.
    ##
    ## @example
    ## @group
    ## ## A plate 60 by 40 with corners of radius 5
    ## PL = fillet (geom.Polyline ([0, 0; 60, 0; 60, 40; 0, 40], ...
    ##                             'Closed', true), 5);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Region.fillet}
    ## @end deftypefn
    function this = fillet (this, RADIUS, IDX = [])

      ## Input validation
      if (nargin < 2)
        error ("geom.Polyline.fillet: invalid number of input arguments.");
      endif
      if (! isnumeric (RADIUS) || ! isreal (RADIUS) || ! isscalar (RADIUS)
          || ! isfinite (RADIUS) || ! (RADIUS > 0))
        error (strcat ("geom.Polyline.fillet: RADIUS must be a positive", ...
                       " and finite real scalar."));
      endif
      V = this.Vertices;
      [errmsg, C] = corners (V, this.Closed, IDX);
      if (! isempty (errmsg))
        error ("geom.Polyline.fillet: %s", errmsg);
      endif

      ## How far back along each segment the round at either end reaches
      t = zeros (1, rows (V));
      t(C.idx) = RADIUS * tan (abs (C.th(C.idx)) / 2);
      errmsg = fits (C, t, t, "round");
      if (! isempty (errmsg))
        error ("geom.Polyline.fillet: %s", errmsg);
      endif

      ## Each rounded corner becomes the arc between its tangent points
      this.Vertices = cut (V, C, t, t, tan (C.th / 4));

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Polyline} {@var{PL} =} chamfer (@var{PL}, @var{D})
    ## @deftypefnx {geom.Polyline} {@var{PL} =} chamfer (@var{PL}, [@var{D1}, @var{D2}])
    ## @deftypefnx {geom.Polyline} {@var{PL} =} chamfer (@dots{}, @var{IDX})
    ## @deftypefnx {geom.Polyline} {@var{PL} =} chamfer (@dots{}, @qcode{'Angle'}, @var{A})
    ##
    ## Cut the corners of a polyline.
    ##
    ## @code{@var{PL} = chamfer (@var{PL}, @var{D})} cuts every corner where
    ## two straight segments meet with a straight segment from @var{D}
    ## millimetres back along the segment before the corner to @var{D} along
    ## the segment after it.  Corners where an arc meets a segment are left as
    ## they are, and so are the two ends of an open polyline.
    ##
    ## @code{@var{PL} = chamfer (@var{PL}, [@var{D1}, @var{D2}])} cuts back
    ## @var{D1} along the segment before each corner and @var{D2} along the
    ## segment after it, before and after in the order of the vertices.
    ##
    ## @code{@var{PL} = chamfer (@var{PL}, @var{D}, @qcode{'Angle'}, @var{A})}
    ## cuts back @var{D} along the segment before each corner, with the cut at
    ## @var{A} degrees to that segment, so a square corner is cut @code{@var{D}
    ## x @var{A}}, reaching @code{@var{D} * tand (@var{A})} along the segment
    ## after it.
    ##
    ## @code{@var{PL} = chamfer (@dots{}, @var{IDX})} cuts only the corners at
    ## the vertices indexed by @var{IDX}, each of which must be a corner
    ## between two straight segments.
    ##
    ## A cut that would run past the end of a segment, or into the cut or round
    ## of the next corner, or an angle at which the cut misses the segment
    ## after the corner, is refused.
    ##
    ## @example
    ## @group
    ## ## A plate 60 by 40 with its corners cut 5 by 45 degrees
    ## PL = geom.Polyline ([0, 0; 60, 0; 60, 40; 0, 40], 'Closed', true);
    ## PL = chamfer (PL, 5);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Polyline.fillet, geom.Region.chamfer}
    ## @end deftypefn
    function this = chamfer (this, D, varargin)

      ## Input validation
      if (nargin < 2)
        error ("geom.Polyline.chamfer: invalid number of input arguments.");
      endif
      if (! isnumeric (D) || ! isreal (D) || ! isvector (D)
          || numel (D) > 2 || ! all (isfinite (D)) || ! all (D > 0))
        error (strcat ("geom.Polyline.chamfer: D must be one positive", ...
                       " finite distance, or two."));
      endif
      IDX = [];
      if (mod (numel (varargin), 2) == 1)
        IDX = varargin{1};
        varargin(1) = [];
      endif
      A = [];
      for k = 1:2:numel (varargin)
        if (! ischar (varargin{k}) || ! strcmp (varargin{k}, 'Angle'))
          error ("geom.Polyline.chamfer: unknown parameter.");
        endif
        A = varargin{k+1};
        if (! isnumeric (A) || ! isreal (A) || ! isscalar (A)
            || ! (A > 0) || ! (A < 180))
          error (strcat ("geom.Polyline.chamfer: Angle must be in the", ...
                         " range (0, 180) degrees."));
        endif
      endfor
      if (! isempty (A) && numel (D) == 2)
        error ("geom.Polyline.chamfer: an angle goes with one distance D.");
      endif
      V = this.Vertices;
      [errmsg, C] = corners (V, this.Closed, IDX);
      if (! isempty (errmsg))
        error ("geom.Polyline.chamfer: %s", errmsg);
      endif

      ## How far back along the segments before and after each corner
      tin = zeros (1, rows (V));
      tout = zeros (1, rows (V));
      tin(C.idx) = D(1);
      tout(C.idx) = D(end);
      if (! isempty (A))
        ## The angle at the corner, and so the triangle the cut makes
        phi = pi - abs (C.th(C.idx));
        far = pi - A * pi / 180 - phi;
        bad = C.idx(far <= 1e-12);
        if (! isempty (bad))
          error (strcat ("geom.Polyline.chamfer: the chamfer at vertex %d", ...
                         " misses the segment after it at that angle."), ...
                 bad(1));
        endif
        tout(C.idx) = D * sind (A) ./ sin (far);
      endif
      errmsg = fits (C, tin, tout, "chamfer");
      if (! isempty (errmsg))
        error ("geom.Polyline.chamfer: %s", errmsg);
      endif

      this.Vertices = cut (V, C, tin, tout, zeros (1, rows (V)));

    endfunction

    function this = set.UCS (this, U)

      if (! isa (U, 'geom.UCS') || ! isscalar (U))
        error ("geom.Polyline: UCS must be a geom.UCS object.");
      endif
      this.UCS = U;

    endfunction


    ## -*- texinfo -*-
    ## @deftypefn  {geom.Polyline} {} write (@var{PL}, @var{FILE})
    ## @deftypefnx {geom.Polyline} {} write (@var{PL}, @var{FILE}, @var{Name}, @var{Value}, @dots{})
    ##
    ## Write a polyline to a DXF file.
    ##
    ## @code{write (@var{PL}, @var{FILE})} writes the polyline @var{PL} to
    ## @var{FILE}, which must end in @file{.dxf}, as one @code{LWPOLYLINE} of
    ## an ASCII DXF drawing.  The entity holds the polyline's plane as its
    ## normal and elevation, and the polyline's @code{geom.UCS} goes with it
    ## as extended data under the application @qcode{'DRAFTING'}, so
    ## @code{geom.read} gives back the polyline that was written, frame and
    ## all.
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
    ## lines and arcs, which is what a polyline is made of.
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
        error ("geom.Polyline.write: invalid number of input arguments.");
      endif
      __dxf__ ('write', FILE, {this}, varargin, 'geom.Polyline.write');

    endfunction

  endmethods

endclassdef

## The corners of the vertices V, closed or not, that IDX names, or all of
## them where two straight segments meet when IDX is empty: their indices,
## the directions into and out of every vertex, the angle the polyline turns
## through there, and its neighbours.  Returns an error message body, empty
## when IDX names only such corners.
function [errmsg, C] = corners (V, closed, IDX)

  errmsg = '';
  n = rows (V);
  if (closed)
    prev = [n, 1:n-1];
    next = [2:n, 1];
    ends = false (1, n);
  else
    prev = [1, 1:n-1];
    next = [2:n, n];
    ends = [true, false(1, n - 2), true];
  endif
  u = V(:,1:2) - V(prev,1:2);
  v = V(next,1:2) - V(:,1:2);
  th = atan2 (u(:,1) .* v(:,2) - u(:,2) .* v(:,1), sum (u .* v, 2))';
  corner = ! ends & (V(prev,3) == 0)' & (V(:,3) == 0)' & abs (th) > 1e-12;
  if (isempty (IDX))
    IDX = find (corner);
  else
    if (! isnumeric (IDX) || ! isreal (IDX) || ! isvector (IDX)
        || any (IDX != fix (IDX)) || any (IDX < 1) || any (IDX > n))
      errmsg = "IDX must be a vector of vertex indices of PL.";
    else
      IDX = unique (double (IDX(:)'));
      bad = IDX(! corner(IDX));
      if (! isempty (bad))
        errmsg = sprintf (strcat ("vertex %d is not a corner between two", ...
                                  " straight segments."), bad(1));
      endif
    endif
  endif
  C = struct ('idx', IDX, 'u', u, 'v', v, 'th', th, 'prev', prev, ...
              'next', next, 'len', sqrt (sum (v .^ 2, 2))');

endfunction

## Whether the cuts TIN back along the segment into each corner and TOUT
## along the segment out of it fit, the cut at one end of a segment clear of
## the cut at the other.  Returns an error message body naming the first
## corner, WHAT, that does not fit.
function errmsg = fits (C, TIN, TOUT, WHAT)

  errmsg = '';
  for i = C.idx
    if (TOUT(i) + TIN(C.next(i)) > C.len(i) * (1 + 1e-12)
        || TIN(i) + TOUT(C.prev(i)) > C.len(C.prev(i)) * (1 + 1e-12))
      errmsg = sprintf ("the %s at vertex %d does not fit its segments.", ...
                        WHAT, i);
      return;
    endif
  endfor

endfunction

## The vertices V with each corner of C replaced by the points TIN back along
## the segment into it and TOUT along the segment out of it, the first given
## the bulge B of the corner, the second none
function W = cut (V, C, TIN, TOUT, B)

  W = num2cell (V, 2);
  for i = C.idx
    a = V(i,1:2) - TIN(i) * C.u(i,:) / norm (C.u(i,:));
    b = V(i,1:2) + TOUT(i) * C.v(i,:) / norm (C.v(i,:));
    W{i} = [a, B(i); b, 0];
  endfor
  W = vertcat (W{:});

endfunction

%!test
%! PL = geom.Polyline ([0, 0; 10, 0; 10, 5]);
%! assert_equal (PL.Vertices, [0, 0, 0; 10, 0, 0; 10, 5, 0]);
%! assert_equal (PL.Closed, false);
%! assert_equal (PL.UCS, geom.UCS ());

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

%!test  # vertices given in a UCS of their own
%! U = geom.UCS ([0, -3, 4], [0, 0, 10]);
%! PL = geom.Polyline ([0, 0; 1, 0], 'UCS', U);
%! assert_equal (PL.UCS, U);
%! assert_equal (PL.Vertices, [0, 0, 0; 1, 0, 0]);

%!test  # assigning a UCS moves the polyline, its own coordinates unchanged
%! PL = geom.Polyline ([0, 0, 1; 10, 0, 0]);
%! U = geom.UCS ([1, 0, 0], [5, 5, 5]);
%! PL.UCS = U;
%! assert_equal (PL.UCS, U);
%! assert_equal (PL.Vertices, [0, 0, 1; 10, 0, 0]);

%!test  # every corner of a rectangle rounded
%! PL = geom.Polyline ([0, 0; 60, 0; 60, 40; 0, 40], 'Closed', true);
%! PL = fillet (PL, 5);
%! b = tand (22.5);
%! assert_equal (PL.Vertices, [0, 5, b; 5, 0, 0; 55, 0, b; 60, 5, 0; ...
%!                             60, 35, b; 55, 40, 0; 5, 40, b; 0, 35, 0], ...
%!               1e-12);

%!test  # chosen corners; a right turn rounds clockwise
%! PL = geom.Polyline ([0, 0; 20, 0; 20, 10; 30, 10]);
%! PL = fillet (PL, 2, [2, 3]);
%! assert_equal (PL.Vertices(:,3)', [0, tand(22.5), 0, -tand(22.5), 0, 0], ...
%!               1e-12);
%! assert_equal (PL.Vertices([1, end],1:2), [0, 0; 30, 10]);

%!test  # a corner next to an arc is left, unless asked for
%! PL = geom.Polyline ([0, 0, 0; 20, 0, 0; 20, 10, 1; 0, 10, 0], ...
%!                     'Closed', true);
%! Q = fillet (PL, 2);
%! assert_equal (rows (Q.Vertices), 6);

%!error<geom.Polyline.fillet: invalid number of input arguments.> ...
%! fillet (geom.Polyline ([0, 0; 1, 0]))
%!error<geom.Polyline.fillet: RADIUS must be a positive and finite real scalar.> ...
%! fillet (geom.Polyline ([0, 0; 1, 0; 1, 1]), 0)
%!error<geom.Polyline.fillet: IDX must be a vector of vertex indices of PL.> ...
%! fillet (geom.Polyline ([0, 0; 1, 0; 1, 1]), 0.1, 4)
%!error<geom.Polyline.fillet: vertex 1 is not a corner between two straight segments.> ...
%! fillet (geom.Polyline ([0, 0; 1, 0; 1, 1]), 0.1, 1)
%!error<geom.Polyline.fillet: vertex 3 is not a corner between two straight segments.> ...
%! fillet (geom.Polyline ([0, 0, 0; 20, 0, 0; 20, 10, 1; 0, 10, 0], ...
%!                        'Closed', true), 2, 3)
%!error<geom.Polyline.fillet: the round at vertex 1 does not fit its segments.> ...
%! fillet (geom.Polyline ([0, 0; 4, 0; 4, 10; 0, 10], 'Closed', true), 3)

%!test  # every corner of a rectangle cut 5 by 45 degrees
%! PL = geom.Polyline ([0, 0; 60, 0; 60, 40; 0, 40], 'Closed', true);
%! Q = chamfer (PL, 5);
%! assert_equal (Q.Vertices, [0, 5, 0; 5, 0, 0; 55, 0, 0; 60, 5, 0; ...
%!                            60, 35, 0; 55, 40, 0; 5, 40, 0; 0, 35, 0], 1e-12);

%!test  # two distances, before and after in the order of the vertices
%! PL = geom.Polyline ([0, 0; 20, 0; 20, 10]);
%! Q = chamfer (PL, [3, 2]);
%! assert_equal (Q.Vertices(:,1:2), [0, 0; 17, 0; 20, 2; 20, 10], 1e-12);

%!test  # a distance and an angle: D * tand (A) along the segment after
%! PL = geom.Polyline ([0, 0; 20, 0; 20, 10]);
%! Q = chamfer (PL, 3, 'Angle', 30);
%! assert_equal (Q.Vertices(:,1:2), [0, 0; 17, 0; 20, 3 * tand(30); 20, 10], ...
%!               1e-12);

%!test  # chosen corners; an obtuse corner at an angle
%! PL = geom.Polyline ([0, 0; 10, 0; 20, 10; 20, 20]);
%! Q = chamfer (PL, 2, 2, 'Angle', 20);
%! d = 2 * sind (20) / sind (180 - 20 - 135);
%! assert_equal (Q.Vertices(3,1:2), [10, 0] + d * [1, 1] / sqrt (2), 1e-12);
%! assert_equal (rows (Q.Vertices), 5);

%!error<geom.Polyline.chamfer: invalid number of input arguments.> ...
%! chamfer (geom.Polyline ([0, 0; 1, 0]))
%!error<geom.Polyline.chamfer: D must be one positive finite distance, or two.> ...
%! chamfer (geom.Polyline ([0, 0; 1, 0; 1, 1]), [1, 2, 3])
%!error<geom.Polyline.chamfer: D must be one positive finite distance, or two.> ...
%! chamfer (geom.Polyline ([0, 0; 1, 0; 1, 1]), -1)
%!error<geom.Polyline.chamfer: unknown parameter.> ...
%! chamfer (geom.Polyline ([0, 0; 1, 0; 1, 1]), 0.1, 'Slope', 30)
%!error<geom.Polyline.chamfer: Angle must be in the range \(0, 180\) degrees.> ...
%! chamfer (geom.Polyline ([0, 0; 1, 0; 1, 1]), 0.1, 'Angle', 180)
%!error<geom.Polyline.chamfer: an angle goes with one distance D.> ...
%! chamfer (geom.Polyline ([0, 0; 1, 0; 1, 1]), [0.1, 0.2], 'Angle', 30)
%!error<geom.Polyline.chamfer: IDX must be a vector of vertex indices of PL.> ...
%! chamfer (geom.Polyline ([0, 0; 1, 0; 1, 1]), 0.1, 7)
%!error<geom.Polyline.chamfer: vertex 3 is not a corner between two straight segments.> ...
%! chamfer (geom.Polyline ([0, 0; 1, 0; 1, 1]), 0.1, 3)
%!error<geom.Polyline.chamfer: the chamfer at vertex 2 misses the segment after it at that angle.> ...
%! chamfer (geom.Polyline ([0, 0; 1, 0; 1, 1]), 0.1, 'Angle', 95)
%!error<geom.Polyline.chamfer: the chamfer at vertex 1 does not fit its segments.> ...
%! chamfer (geom.Polyline ([0, 0; 4, 0; 4, 10; 0, 10], 'Closed', true), 3)

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
%!error<geom.Polyline: UCS must be a geom.UCS object.> ...
%! geom.Polyline ([0, 0; 1, 0], 'UCS', [0, 0, 1])
%!error<geom.Polyline: UCS must be a geom.UCS object.>
%! PL = geom.Polyline ([0, 0; 1, 0]);
%! PL.UCS = [0, 0, 0];
%!error<geom.Polyline: P must not repeat a vertex consecutively.> ...
%! geom.Polyline ([0, 0; 1, 0; 1, 0; 2, 2])
%!error<geom.Polyline: P must not repeat a vertex consecutively.> ...
%! geom.Polyline ([0, 0; 0, 0], 'Closed', true)
%!error<geom.Polyline: the last vertex of an open polyline must have a zero bulge.> ...
%! geom.Polyline ([0, 0, 0; 10, 0, 1])

%!test  # write: geom.read gives back the polyline, bulges, frame and all
%! U = geom.UCS ([1, 1, 1], [5, 0, 3]);
%! PL = geom.Polyline ([0, 0, 0; 10, 0, 0.5; 10, 5, 0], 'Closed', true, ...
%!                     'UCS', U);
%! fn = [tempname(), '.dxf'];
%! unwind_protect
%!   write (PL, fn);
%!   C = geom.read (fn);
%!   assert_equal (C{1}.Vertices, PL.Vertices, 1e-12);
%!   assert_equal (C{1}.Closed, true);
%!   assert_equal ([C{1}.UCS.Origin; C{1}.UCS.XAxis; C{1}.UCS.Normal], ...
%!                 [U.Origin; U.XAxis; U.Normal], 1e-12);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect
%!test  # write: R12 holds a polyline, and it reads back
%! PL = geom.Polyline ([0, 0, 1; 10, 0, 0; 10, 5, 0]);
%! fn = [tempname(), '.dxf'];
%! unwind_protect
%!   write (PL, fn, 'Version', 'R12', 'Layer', 'P', 'Colour', 2);
%!   txt = fileread (fn);
%!   assert_equal (numel (strfind (txt, "AC1009")), 1);
%!   C = geom.read (fn, 'Layer', 'P');
%!   assert_equal (C{1}.Vertices, PL.Vertices, 1e-12);
%! unwind_protect_cleanup
%!   unlink (fn);
%! end_unwind_protect

%!error<geom.Polyline.write: invalid number of input arguments.> ...
%! write (geom.Polyline ([0, 0; 1, 0]))
%!error<geom.Polyline.write: FILE must end in .dxf.> ...
%! write (geom.Polyline ([0, 0; 1, 0]), 'a.stl')
%!error<geom.Polyline.write: Layer must be a non-empty character vector.> ...
%! write (geom.Polyline ([0, 0; 1, 0]), 'a.dxf', 'Layer', {'A'})
%!error<geom.Polyline.write: Colour must be an integer from 1 to 256.> ...
%! write (geom.Polyline ([0, 0; 1, 0]), 'a.dxf', 'Colour', 1.5)
%!error<geom.Polyline.write: unknown parameter.> ...
%! write (geom.Polyline ([0, 0; 1, 0]), 'a.dxf', 'Fill', true)
