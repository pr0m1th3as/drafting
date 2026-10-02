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

classdef Region
  ## -*- texinfo -*-
  ## @deftp {drafting} geom.Region
  ##
  ## A closed area of a plane, an outline with holes in it.
  ##
  ## A @code{geom.Region} is what a solid is made from:
  ## @code{solid.extrude}, @code{solid.revolve}, @code{solid.sweep},
  ## @code{solid.loft} and @code{solid.helix} each take one.  It is the area
  ## inside one closed @code{geom.Polyline}, the outline, less the areas inside
  ## any number of others, the holes.  A hole may have any shape, a circle, a
  ## slot, a square or any outline of straight segments and arcs, and goes
  ## right through whatever is made from the region; a recess of limited depth
  ## is a pocket, worked on the solid.
  ##
  ## A region is always valid: every outline closed, none crossing or touching
  ## itself or enclosing no area, every hole in the plane of the outline and
  ## strictly inside it, and no two holes overlapping or touching.  An island
  ## inside a hole is not a region; union a second solid made from it.  Arcs
  ## are followed to within 2 degrees when the outlines are checked against one
  ## another.
  ##
  ## The outline and holes may be drawn either way round.  The region stores
  ## the outline anticlockwise and the holes clockwise, all in the
  ## @code{geom.UCS} of the outline, which is the UCS of the region.
  ## Assigning the region another UCS moves it there.
  ##
  ## A @code{geom.Region} is a value: every change makes a new one.
  ##
  ## @seealso{geom.Polyline, geom.UCS, solid.extrude}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {geom.Region} {property} Outline
    ##
    ## Outline of the region
    ##
    ## The outline, a closed @code{geom.Polyline} running anticlockwise.  Its
    ## plane is the plane of the region.
    ##
    ## @end deftp
    Outline = [];

    ## -*- texinfo -*-
    ## @deftp {geom.Region} {property} Holes
    ##
    ## Holes in the region
    ##
    ## The holes, a row cell array of closed @code{geom.Polyline} objects
    ## running clockwise, in the plane of the outline; empty when there are
    ## none.
    ##
    ## @end deftp
    Holes = cell (1, 0);

  endproperties

  properties (Dependent)

    ## -*- texinfo -*-
    ## @deftp {geom.Region} {property} UCS
    ##
    ## Coordinate system of the region
    ##
    ## The @code{geom.UCS} the outline and holes are coordinates in.
    ## Assigning another moves the region onto it, its shape unchanged in its
    ## own coordinates, so a region drawn in the @math{xy} plane is laid on the
    ## face of a part by assigning it the face's UCS.
    ##
    ## @end deftp
    UCS

  endproperties

  methods (Hidden)

    function disp (this)

      printf ("  geom.Region: an outline of %d vertices, %d holes\n", ...
              rows (this.Outline.Vertices), numel (this.Holes));

    endfunction

  endmethods

  methods (Access = public)

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Region} {@var{R} =} geom.Region (@var{OUTLINE})
    ## @deftypefnx {geom.Region} {@var{R} =} geom.Region (@var{OUTLINE}, @var{HOLES})
    ##
    ## Make a region.
    ##
    ## @code{@var{R} = geom.Region (@var{OUTLINE})} makes the area inside
    ## @var{OUTLINE}, a closed @code{geom.Polyline}.
    ##
    ## @code{@var{R} = geom.Region (@var{OUTLINE}, @var{HOLES})} cuts out of
    ## it the areas inside the closed polylines in the cell array @var{HOLES}.
    ## A hole given in another frame of the same plane is carried into the
    ## frame of the outline.
    ##
    ## @var{OUTLINE} and each hole may also be given as the matrix of vertices
    ## a @code{geom.Polyline} is made from, @code{[@var{x}, @var{y},
    ## @var{bulge}]} rows or @code{[@var{x}, @var{y}]} rows for straight
    ## segments.  An outline given so lies in the @math{xy} plane, and a hole
    ## given so lies in the plane of the outline:
    ##
    ## @example
    ## @group
    ## ## A plate 60 by 40 with a bore of diameter 20 and two square holes
    ## R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
    ##                  @{[20, 20, 1; 40, 20, 1], ...
    ##                   [4, 4; 10, 4; 10, 10; 4, 10], ...
    ##                   [50, 30; 56, 30; 56, 36; 50, 36]@});
    ## @end group
    ## @end example
    ##
    ## An invalid region is refused with an error naming the outline or hole at
    ## fault.
    ##
    ## @end deftypefn
    function U = get.UCS (this)

      U = this.Outline.UCS;

    endfunction

    function this = set.UCS (this, U)

      if (! isa (U, 'geom.UCS') || ! isscalar (U))
        error ("geom.Region: UCS must be a geom.UCS object.");
      endif
      this.Outline.UCS = U;
      for k = 1:numel (this.Holes)
        this.Holes{k}.UCS = U;
      endfor

    endfunction

    function this = Region (OUTLINE, HOLES = {})

      ## Input validation
      if (nargin < 1 || nargin > 2)
        error ("geom.Region: invalid number of input arguments.");
      endif
      [errmsg, O] = topolyline (OUTLINE, 'OUTLINE', []);
      if (! isempty (errmsg))
        error ("geom.Region: %s", errmsg);
      endif
      if (! iscell (HOLES) || ! (isvector (HOLES) || isempty (HOLES)))
        error ("geom.Region: HOLES must be a cell array of holes.");
      endif
      H = cell (1, numel (HOLES));
      for k = 1:numel (HOLES)
        [errmsg, H{k}] = topolyline (HOLES{k}, sprintf ("HOLES{%d}", k), O);
        if (! isempty (errmsg))
          error ("geom.Region: %s", errmsg);
        endif
      endfor

      ## Each outline on its own, sampled along its arcs
      names = [{'OUTLINE'}, arrayfun(@(k) sprintf ("HOLES{%d}", k), ...
                                     1:numel (H), 'UniformOutput', false)];
      all_ = [{O}, H];
      S = cell (size (all_));
      A = zeros (size (all_));
      for k = 1:numel (all_)
        V = all_{k}.Vertices;
        S{k} = geom.__sample__ (V);
        if (rows (S{k}) > 2 && geom.selfintersects (S{k}, true))
          error ("geom.Region: %s must not cross or touch itself.", names{k});
        endif
        A(k) = signedarea (V);
        if (abs (A(k)) <= 1e-12 * max (range (S{k})) ^ 2)
          error ("geom.Region: %s must enclose a nonzero area.", names{k});
        endif
      endfor

      ## The holes against the outline and against one another
      for k = 2:numel (S)
        [in, on] = inpolygon (S{k}(:,1), S{k}(:,2), S{1}(:,1), S{1}(:,2));
        if (! all (in & ! on) || meets (S{k}, S{1}))
          error ("geom.Region: %s must lie strictly inside OUTLINE.", ...
                 names{k});
        endif
      endfor
      for j = 2:numel (S)
        for k = j+1:numel (S)
          jink = inpolygon (S{j}(:,1), S{j}(:,2), S{k}(:,1), S{k}(:,2));
          kinj = inpolygon (S{k}(:,1), S{k}(:,2), S{j}(:,1), S{j}(:,2));
          if (meets (S{j}, S{k}) || any (jink) || any (kinj))
            error ("geom.Region: %s and %s must not overlap or touch.", ...
                   names{j}, names{k});
          endif
        endfor
      endfor

      ## The outline anticlockwise and the holes clockwise
      if (A(1) < 0)
        O = reversed (O);
      endif
      for k = 1:numel (H)
        if (A(k+1) > 0)
          H{k} = reversed (H{k});
        endif
      endfor
      this.Outline = O;
      this.Holes = H;

    endfunction

  endmethods

endclassdef

## A closed polyline from ARG, named NAME in errors: a geom.Polyline, or a
## matrix of vertices in the plane of the polyline IN, or the xy plane when IN
## is empty.  A polyline in another frame of the same plane is carried into
## the frame of IN.  Returns an error message body, empty when it is valid.
function [errmsg, PL] = topolyline (ARG, NAME, IN)

  errmsg = '';
  PL = [];
  if (isnumeric (ARG))
    if (isempty (IN))
      args = {};
    else
      args = {'UCS', IN.UCS};
    endif
    try
      PL = geom.Polyline (ARG, 'Closed', true, args{:});
    catch err
      errmsg = sprintf ("%s: %s", NAME, regexprep (err.message, ...
                                                   '^geom\.Polyline: ', ''));
    end_try_catch
    return;
  endif
  if (! isa (ARG, 'geom.Polyline') || ! isscalar (ARG))
    errmsg = sprintf (strcat ("%s must be a closed geom.Polyline or a", ...
                              " matrix of its vertices."), NAME);
    return;
  endif
  if (! ARG.Closed)
    errmsg = sprintf ("%s must be closed.", NAME);
    return;
  endif
  PL = ARG;
  if (isempty (IN))
    return;
  endif

  ## Into the UCS of IN, which must be on the same plane
  [errmsg, PL] = into (ARG, IN.UCS);
  if (! isempty (errmsg))
    errmsg = sprintf ("%s must lie in the plane of OUTLINE.", NAME);
  endif

endfunction

## The closed polyline PL carried into the UCS U on the same plane, its
## vertices given in the coordinates of U; a mirror reverses the sense of every
## arc.  Returns a nonempty error message when U is on another plane.
function [errmsg, PL] = into (PL, U)

  errmsg = '';
  F = PL.UCS;
  scale = max ([1, abs(F.Origin), abs(U.Origin)]);
  if (abs (F.Normal * U.Normal') < 1 - 1e-9 ...
      || abs ((F.Origin - U.Origin) * U.Normal') > 1e-9 * scale)
    errmsg = 'not on the plane';
    return;
  endif
  V = PL.Vertices;
  W = tolocal (U, toworld (F, V(:,1:2)));
  V(:,1:2) = W(:,1:2);
  if (F.Normal * U.Normal' < 0)
    V(:,3) = -V(:,3);
  endif
  PL = geom.Polyline (V, 'Closed', true, 'UCS', U);

endfunction

## The signed area inside the vertices V, positive anticlockwise: the
## polygon's, plus the circular segment of each arc, which a positive bulge
## adds
function A = signedarea (V)

  x = V(:,1);
  y = V(:,2);
  xn = x([2:end, 1]);
  yn = y([2:end, 1]);
  c = hypot (xn - x, yn - y);
  th = 4 * atan (abs (V(:,3)));
  r = c ./ (2 * sin (th / 2));
  seg = r .^ 2 / 2 .* (th - sin (th));
  seg(V(:,3) == 0) = 0;
  A = sum (x .* yn - xn .* y) / 2 + sum (sign (V(:,3)) .* seg);

endfunction

## The same closed polyline running the other way round, from the same first
## vertex: each segment reversed, and with it the sign of its bulge
function PL = reversed (PL)

  V = PL.Vertices;
  n = rows (V);
  V = [V([1, n:-1:2],1:2), -V(n:-1:1,3)];
  PL = geom.Polyline (V, 'Closed', true, 'UCS', PL.UCS);

endfunction

## True when any segment of the closed polygon A meets any of the closed
## polygon B, crossing or touching
function TF = meets (A, B)

  a1 = A;
  a2 = A([2:end, 1],:);
  b1 = B;
  b2 = B([2:end, 1],:);
  tol = 1e-12 * max ([range(A(:)), range(B(:)), 1]) ^ 2;
  orient = @(p, q, r) (q(:,1) - p(:,1)) .* (r(:,2)' - p(:,2)) ...
                      - (q(:,2) - p(:,2)) .* (r(:,1)' - p(:,1));
  o1 = orient (a1, a2, b1);
  o2 = orient (a1, a2, b2);
  o3 = orient (b1, b2, a1)';
  o4 = orient (b1, b2, a2)';
  o1(abs (o1) < tol) = 0;
  o2(abs (o2) < tol) = 0;
  o3(abs (o3) < tol) = 0;
  o4(abs (o4) < tol) = 0;
  hit = (o1 .* o2 <= 0) & (o3 .* o4 <= 0);
  ## Collinear segments meet only where their extents overlap
  col = (o1 == 0) & (o2 == 0);
  if (any (col(:)))
    lo = @(u, v) min (u, v);
    hi = @(u, v) max (u, v);
    ox = hi (lo (a1(:,1), a2(:,1)), lo (b1(:,1), b2(:,1))') ...
         <= lo (hi (a1(:,1), a2(:,1)), hi (b1(:,1), b2(:,1))');
    oy = hi (lo (a1(:,2), a2(:,2)), lo (b1(:,2), b2(:,2))') ...
         <= lo (hi (a1(:,2), a2(:,2)), hi (b1(:,2), b2(:,2))');
    hit(col) = ox(col) & oy(col);
  endif
  TF = any (hit(:));

endfunction

%!test
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40]);
%! assert_equal (R.Outline.Vertices, [0, 0, 0; 60, 0, 0; 60, 40, 0; 0, 40, 0]);
%! assert_equal (R.Holes, cell (1, 0));

%!test  # a clockwise outline turned anticlockwise, from the same vertex
%! R = geom.Region ([0, 0, 0; 0, 40, 0; 60, 40, 1; 60, 0, 0]);
%! assert_equal (R.Outline.Vertices, [0, 0, 0; 60, 0, -1; 60, 40, 0; 0, 40, 0]);

%!test  # holes of any shape, stored clockwise
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                  {[20, 20, 1; 40, 20, 1], [4, 4; 10, 4; 10, 10; 4, 10]});
%! assert_equal (R.Holes{1}.Vertices, [20, 20, -1; 40, 20, -1]);
%! assert_equal (R.Holes{2}.Vertices, [4, 4, 0; 4, 10, 0; 10, 10, 0; 10, 4, 0]);

%!test  # an outline on a sloping plane, its holes in the same plane
%! U = geom.UCS ([0, -3, 4], [0, 0, 10]);
%! O = geom.Polyline ([0, 0; 50, 0; 50, 30; 0, 30], 'Closed', true, 'UCS', U);
%! R = geom.Region (O, {[10, 10; 20, 10; 20, 20; 10, 20]});
%! assert_equal (R.UCS, U);
%! assert_equal (R.Holes{1}.UCS, U);

%!test  # a hole drawn in another frame of the same plane is carried over
%! O = geom.Polyline ([0, 0; 60, 0; 60, 40; 0, 40], 'Closed', true);
%! H = geom.Polyline ([0, 0, 1; 10, 0, 1], 'Closed', true, ...
%!                    'UCS', geom.UCS ([0, 0, -1], [30, 20, 0]));
%! R = geom.Region (O, {H});
%! V = R.Holes{1}.Vertices;
%! assert_equal (V(:,1:2), [30, 20; 20, 20], 1e-12);
%! assert_equal (V(:,3), [-1; -1]);
%! assert_equal (R.Holes{1}.UCS, geom.UCS ());

%!test  # assigning a UCS moves the region, holes and all
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], {[20, 20, 1; 40, 20, 1]});
%! U = geom.UCS ([0, -3, 4], [0, 0, 10]);
%! R.UCS = U;
%! assert_equal (R.UCS, U);
%! assert_equal (R.Holes{1}.UCS, U);
%! assert_equal (R.Outline.Vertices, [0, 0, 0; 60, 0, 0; 60, 40, 0; 0, 40, 0]);
%! assert_equal (R.Holes{1}.Vertices, [20, 20, -1; 40, 20, -1]);

%!error<geom.Region: invalid number of input arguments.> geom.Region ()
%!error<geom.Region: UCS must be a geom.UCS object.>
%! R = geom.Region ([0, 0; 1, 0; 1, 1]);
%! R.UCS = 1;
%!error<geom.Region: OUTLINE must be a closed geom.Polyline or a matrix of its vertices.> ...
%! geom.Region ({[0, 0; 1, 0; 1, 1]})
%!error<geom.Region: OUTLINE: P must be an N-by-2 or N-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Region ([0, 0])
%!error<geom.Region: OUTLINE must be closed.> ...
%! geom.Region (geom.Polyline ([0, 0; 1, 0; 1, 1]))
%!error<geom.Region: HOLES must be a cell array of holes.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], [1, 1; 2, 1; 2, 2])
%!error<geom.Region: HOLES\{1\} must be a closed geom.Polyline or a matrix of its vertices.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], {'abc'})
%!error<geom.Region: HOLES\{2\}: P must not repeat a vertex consecutively.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], {[6, 2; 7, 2; 7, 3], [8, 2; 8, 2; 9, 3]})
%!error<geom.Region: HOLES\{1\} must be closed.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], {geom.Polyline([6, 2; 7, 2; 7, 3])})
%!error<geom.Region: HOLES\{1\} must lie in the plane of OUTLINE.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], ...
%!              {geom.Polyline([6, 2; 7, 2; 7, 3], 'Closed', true, ...
%!                             'UCS', geom.UCS ([0, 0, 1], [0, 0, 1]))})
%!error<geom.Region: HOLES\{1\} must lie in the plane of OUTLINE.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], ...
%!              {geom.Polyline([6, 2; 7, 2; 7, 3], 'Closed', true, ...
%!                             'UCS', geom.UCS ([0, 1, 1], [0, 0, 0]))})
%!error<geom.Region: OUTLINE must not cross or touch itself.> ...
%! geom.Region ([0, 0; 10, 10; 10, 0; 0, 10])
%!error<geom.Region: HOLES\{1\} must not cross or touch itself.> ...
%! geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], {[5, 5; 15, 15; 15, 5; 5, 15]})
%!error<geom.Region: OUTLINE must enclose a nonzero area.> ...
%! geom.Region ([0, 0; 5, 0; 10, 0])
%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], {[30, 5; 35, 5; 35, 10]})
%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], {[15, 5; 25, 5; 25, 10]})
%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 20, 0; 20, 20; 0, 20], {[0, 5; 5, 5; 5, 10]})
%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 20, 0; 20, 15; 0, 15], {[2, 7.5, 1; 18, 7.5, 1]})
%!error<geom.Region: HOLES\{1\} and HOLES\{2\} must not overlap or touch.> ...
%! geom.Region ([0, 0; 30, 0; 30, 20; 0, 20], ...
%!              {[2, 2; 12, 2; 12, 12; 2, 12], [8, 8; 18, 8; 18, 18; 8, 18]})
%!error<geom.Region: HOLES\{1\} and HOLES\{2\} must not overlap or touch.> ...
%! geom.Region ([0, 0; 30, 0; 30, 20; 0, 20], ...
%!              {[2, 2; 12, 2; 12, 12; 2, 12], [12, 2; 20, 2; 20, 12]})
%!error<geom.Region: HOLES\{1\} and HOLES\{2\} must not overlap or touch.> ...
%! geom.Region ([0, 0; 30, 0; 30, 20; 0, 20], ...
%!              {[2, 2; 18, 2; 18, 18; 2, 18], [5, 5; 8, 5; 8, 8; 5, 8]})
