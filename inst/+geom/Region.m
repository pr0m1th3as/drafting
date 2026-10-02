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
  ## inside one closed loop, the outline, less the areas inside any number of
  ## others, the holes.  Each loop is a closed @code{geom.Path} of straight
  ## segments, arcs and splines, so a hole may have any shape: a circle, a
  ## slot, a square or a smooth closed @code{geom.Spline}.  A hole goes right
  ## through whatever is made from the region; a recess of limited depth is a
  ## pocket, worked on the solid.
  ##
  ## A region is always valid: every outline closed, none crossing or touching
  ## itself or enclosing no area, every hole in the plane of the outline and
  ## strictly inside it, and no two holes overlapping or touching.  An island
  ## inside a hole is not a region; union a second solid made from it.  Arcs
  ## are followed to within 2 degrees, and splines as closely, when the loops
  ## are checked against one another.
  ##
  ## The outline and holes may be drawn either way round.  The region stores
  ## the outline anticlockwise and the holes clockwise, all in the
  ## @code{geom.UCS} of the outline, which is the UCS of the region.
  ## Assigning the region another UCS moves it there.
  ##
  ## A @code{geom.Region} is a value: every change makes a new one.
  ##
  ## @seealso{geom.Path, geom.Polyline, geom.Spline, geom.UCS, solid.extrude}
  ## @end deftp

  properties (SetAccess = private)

    ## -*- texinfo -*-
    ## @deftp {geom.Region} {property} Outline
    ##
    ## Outline of the region
    ##
    ## The outline, a closed @code{geom.Path} running anticlockwise in the
    ## plane of its UCS, which is the plane of the region.
    ##
    ## @end deftp
    Outline = [];

    ## -*- texinfo -*-
    ## @deftp {geom.Region} {property} Holes
    ##
    ## Holes in the region
    ##
    ## The holes, a row cell array of closed @code{geom.Path} objects running
    ## clockwise, in the UCS of the outline; empty when there are none.
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

      printf ("  geom.Region: an outline of %d segments, %d holes\n", ...
              rows (this.Outline.Vertices), numel (this.Holes));

    endfunction

    ## The region scaled by the factor F about the origin of its UCS
    function this = __scaled__ (this, F)

      this.Outline = __scaled__ (this.Outline, F);
      this.Holes = cellfun (@(h) __scaled__ (h, F), this.Holes, ...
                            'UniformOutput', false);

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
    ## @var{OUTLINE}, a closed @code{geom.Polyline}, @code{geom.Path} or
    ## @code{geom.Spline} lying in the plane of its UCS.
    ##
    ## @code{@var{R} = geom.Region (@var{OUTLINE}, @var{HOLES})} cuts out of
    ## it the areas inside the closed polylines, paths and splines in the cell
    ## array @var{HOLES}.  A hole given in another frame of the same plane is
    ## carried into the frame of the outline.  The region keeps each as a
    ## @code{geom.Path}.
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
    ## A hole with a smooth outline is a closed spline:
    ##
    ## @example
    ## @group
    ## H = geom.Spline ([20, 15; 35, 12; 40, 25; 28, 35; 18, 28], ...
    ##                  'Closed', true);
    ## R = geom.Region ([0, 0; 80, 0; 80, 50; 0, 50], @{H@});
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

    ## -*- texinfo -*-
    ## @deftypefn {geom.Region} {@var{R} =} fillet (@var{R}, @var{RADIUS})
    ##
    ## Round the corners of a region.
    ##
    ## @code{@var{R} = fillet (@var{R}, @var{RADIUS})} rounds every corner of
    ## the outline and of every hole where two straight segments meet, with an
    ## arc of radius @var{RADIUS} millimetres tangent to both, as
    ## @code{geom.Path.fillet} does: the outline's corners and the inside
    ## corners of its holes alike.  This is the rounded outline of a plate or a
    ## pocket, drawn before it is extruded, which is simpler and more exact
    ## than rounding the edges of the solid afterwards.  Corners next to an arc
    ## or a spline are left as they are.  To round only some corners, round the
    ## outline or a hole as a path and make the region again.
    ##
    ## @example
    ## @group
    ## ## A plate 60 by 40 with corners of radius 5 and a slot with sharp
    ## ## corners rounded to 1
    ## R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
    ##                  @{[20, 15; 40, 15; 40, 25; 20, 25]@});
    ## S = solid.extrude (fillet (R, 1), 6);
    ## @end group
    ## @end example
    ##
    ## @seealso{geom.Path.fillet}
    ## @end deftypefn
    function this = fillet (this, RADIUS)

      ## Input validation
      if (nargin != 2)
        error ("geom.Region.fillet: invalid number of input arguments.");
      endif

      try
        O = fillet (this.Outline, RADIUS);
      catch err
        error ("geom.Region.fillet: OUTLINE: %s", ...
               regexprep (err.message, '^geom\.Path\.fillet: ', ''));
      end_try_catch
      H = this.Holes;
      for k = 1:numel (H)
        try
          H{k} = fillet (H{k}, RADIUS);
        catch err
          error ("geom.Region.fillet: HOLES{%d}: %s", k, ...
                 regexprep (err.message, '^geom\.Path\.fillet: ', ''));
        end_try_catch
      endfor
      this = geom.Region (O, H);

    endfunction

    ## -*- texinfo -*-
    ## @deftypefn  {geom.Region} {@var{R} =} chamfer (@var{R}, @var{D})
    ## @deftypefnx {geom.Region} {@var{R} =} chamfer (@var{R}, [@var{D1}, @var{D2}])
    ## @deftypefnx {geom.Region} {@var{R} =} chamfer (@var{R}, @var{D}, @qcode{'Angle'}, @var{A})
    ##
    ## Cut the corners of a region.
    ##
    ## @code{@var{R} = chamfer (@var{R}, @var{D})} cuts every corner of the
    ## outline and of every hole where two straight segments meet, @var{D}
    ## millimetres back along both segments, as @code{geom.Path.chamfer}
    ## does.  Two distances or a distance and an angle are taken as there,
    ## before and after each corner in the order the region stores its
    ## vertices: anticlockwise round the outline, clockwise round the holes.
    ## To cut only some corners, cut the outline or a hole as a path and make
    ## the region again.
    ##
    ## @seealso{geom.Path.chamfer, geom.Region.fillet}
    ## @end deftypefn
    function this = chamfer (this, varargin)

      ## Input validation
      if (nargin < 2)
        error ("geom.Region.chamfer: invalid number of input arguments.");
      endif

      try
        O = chamfer (this.Outline, varargin{:});
      catch err
        error ("geom.Region.chamfer: OUTLINE: %s", ...
               regexprep (err.message, '^geom\.Path\.chamfer: ', ''));
      end_try_catch
      H = this.Holes;
      for k = 1:numel (H)
        try
          H{k} = chamfer (H{k}, varargin{:});
        catch err
          error ("geom.Region.chamfer: HOLES{%d}: %s", k, ...
                 regexprep (err.message, '^geom\.Path\.chamfer: ', ''));
        end_try_catch
      endfor
      this = geom.Region (O, H);

    endfunction

    function this = Region (OUTLINE, HOLES = {})

      ## Input validation
      if (nargin < 1 || nargin > 2)
        error ("geom.Region: invalid number of input arguments.");
      endif
      [errmsg, O] = toloop (OUTLINE, 'OUTLINE', []);
      if (! isempty (errmsg))
        error ("geom.Region: %s", errmsg);
      endif
      if (! iscell (HOLES) || ! (isvector (HOLES) || isempty (HOLES)))
        error ("geom.Region: HOLES must be a cell array of holes.");
      endif
      H = cell (1, numel (HOLES));
      for k = 1:numel (HOLES)
        [errmsg, H{k}] = toloop (HOLES{k}, sprintf ("HOLES{%d}", k), O);
        if (! isempty (errmsg))
          error ("geom.Region: %s", errmsg);
        endif
      endfor

      ## Each loop on its own, sampled along its arcs and splines
      names = [{'OUTLINE'}, arrayfun(@(k) sprintf ("HOLES{%d}", k), ...
                                     1:numel (H), 'UniformOutput', false)];
      all_ = [{O}, H];
      S = cell (size (all_));
      A = zeros (size (all_));
      for k = 1:numel (all_)
        S{k} = __sample__ (all_{k})(:,1:2);
        if (rows (S{k}) > 2 && geom.selfintersects (S{k}, true))
          error ("geom.Region: %s must not cross or touch itself.", names{k});
        endif
        A(k) = __area__ (all_{k});
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
        O = __reversed__ (O);
      endif
      for k = 1:numel (H)
        if (A(k+1) > 0)
          H{k} = __reversed__ (H{k});
        endif
      endfor
      this.Outline = O;
      this.Holes = H;

    endfunction

  endmethods

endclassdef

## A closed loop from ARG, named NAME in errors: a closed geom.Polyline,
## geom.Path or geom.Spline, or a matrix of polyline vertices in the plane of
## the loop IN, or the xy plane when IN is empty, as a geom.Path.  A loop in
## another frame of the same plane is carried into the frame of IN.  Returns
## an error message body, empty when it is valid.
function [errmsg, P] = toloop (ARG, NAME, IN)

  errmsg = '';
  P = [];
  if (isnumeric (ARG))
    if (isempty (IN))
      args = {};
    else
      args = {'UCS', IN.UCS};
    endif
    try
      P = geom.Path (geom.Polyline (ARG, 'Closed', true, args{:}));
    catch err
      errmsg = sprintf ("%s: %s", NAME, regexprep (err.message, ...
                                                   '^geom\.Polyline: ', ''));
    end_try_catch
    return;
  endif
  if (! isscalar (ARG) || ! (isa (ARG, 'geom.Polyline') ...
                             || isa (ARG, 'geom.Path') ...
                             || isa (ARG, 'geom.Spline')))
    errmsg = sprintf (strcat ("%s must be a closed geom.Polyline,", ...
                              " geom.Path or geom.Spline, or a matrix of", ...
                              " vertices."), NAME);
    return;
  endif
  if (! ARG.Closed)
    errmsg = sprintf ("%s must be closed.", NAME);
    return;
  endif
  if (isa (ARG, 'geom.Path'))
    P = ARG;
  else
    P = geom.Path (ARG);
  endif
  if (isempty (IN))
    if (! flat (P))
      errmsg = sprintf ("%s must lie in the plane of its UCS.", NAME);
    endif
    return;
  endif

  ## Into the UCS of IN, which must be on the same plane
  P = __into__ (P, IN.UCS);
  if (! flat (P))
    errmsg = sprintf ("%s must lie in the plane of OUTLINE.", NAME);
  endif

endfunction

## True when every point of the path P, and every direction it is given, lies
## in the plane of its UCS
function TF = flat (P)

  V = P.Vertices;
  M = P.Midpoints;
  z = [V(:,3); M(! isnan (M(:,1)),3)];
  d = [];
  for i = find (! cellfun (@isempty, P.Splines))'
    SP = P.Splines{i};
    z = [z; SP.Points(:,3)];
    d = [d; SP.Tangents(! isnan (SP.Tangents(:,1)),3)];
  endfor
  scale = max ([1; abs(V(:)); abs(P.UCS.Origin(:))]);
  TF = all (abs (z) <= 1e-9 * scale) && all (abs (d) <= 1e-9);

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
%! assert_equal (R.Outline.Vertices, [0, 0, 0; 60, 0, 0; 60, 40, 0; 0, 40, 0]);
%! assert_equal (R.Outline.Midpoints(2,:), [40, 20, 0], 1e-12);
%! assert_equal (__area__ (R.Outline), 2400 - 200 * pi, 1e-9);

%!test  # holes of any shape, stored clockwise
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                  {[20, 20, 1; 40, 20, 1], [4, 4; 10, 4; 10, 10; 4, 10]});
%! assert_equal (R.Holes{1}.Vertices, [20, 20, 0; 40, 20, 0]);
%! assert_equal (R.Holes{1}.Midpoints, [30, 30, 0; 30, 10, 0], 1e-12);
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
%! assert_equal (R.Holes{1}.Vertices, [30, 20, 0; 20, 20, 0], 1e-12);
%! assert_equal (__area__ (R.Holes{1}), -25 * pi, 1e-9);
%! assert_equal (R.Holes{1}.UCS, geom.UCS ());

%!test  # assigning a UCS moves the region, holes and all
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], {[20, 20, 1; 40, 20, 1]});
%! U = geom.UCS ([0, -3, 4], [0, 0, 10]);
%! R.UCS = U;
%! assert_equal (R.UCS, U);
%! assert_equal (R.Holes{1}.UCS, U);
%! assert_equal (R.Outline.Vertices, [0, 0, 0; 60, 0, 0; 60, 40, 0; 0, 40, 0]);
%! assert_equal (R.Holes{1}.Vertices, [20, 20, 0; 40, 20, 0]);

%!test  # every corner of the outline and of a hole rounded
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                  {[20, 15; 40, 15; 40, 25; 20, 25]});
%! Q = fillet (R, 1);
%! assert_equal (rows (Q.Outline.Vertices), 8);
%! assert_equal (rows (Q.Holes{1}.Vertices), 8);
%! assert_equal (all (! isnan (Q.Holes{1}.Midpoints(1:2:end,1))), true);
%! assert_equal (__area__ (Q.Holes{1}), -(200 - (4 - pi)), 1e-9);
%! assert_equal (Q.UCS, R.UCS);

%!test  # every corner of the outline and of a hole cut
%! R = geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                  {[20, 15; 40, 15; 40, 25; 20, 25]});
%! Q = chamfer (R, 1);
%! assert_equal (rows (Q.Outline.Vertices), 8);
%! assert_equal (rows (Q.Holes{1}.Vertices), 8);
%! ## The outline loses four corners, the hole gives four back
%! A = @(P) polyarea (P(:,1), P(:,2));
%! assert_equal (A (Q.Outline.Vertices) - A (Q.Holes{1}.Vertices), 2200, 1e-9);

%!test  # a smooth hole, a closed spline
%! H = geom.Spline ([20, 15; 35, 12; 40, 25; 28, 35; 18, 28], ...
%!                  'Closed', true);
%! R = geom.Region ([0, 0; 80, 0; 80, 50; 0, 50], {H});
%! assert_equal (class (R.Holes{1}), 'geom.Path');
%! assert_equal (__area__ (R.Holes{1}) < 0, true);
%! assert_equal (-__area__ (R.Holes{1}), abs (__area__ (geom.Path (H))), 1e-9);

%!test  # an outline of a straight edge and a spline, from a path
%! P = join (geom.Path ([0, 0; 40, 0]), ...
%!           geom.Spline ([40, 0; 45, 20; 20, 30; 0, 0]));
%! R = geom.Region (P, {geom.Polyline([10, 8, 1; 16, 8, 1], 'Closed', true)});
%! assert_equal (R.Outline.Closed, true);
%! assert_equal (numel (R.Holes), 1);
%! assert_equal (isempty (R.Outline.Splines{2}), false);

%!test  # a closed spline as the outline, given in a UCS of its own
%! U = geom.UCS ([0, 0, 1], [5, 5, 5]);
%! O = geom.Spline ([0, 0; 30, -5; 45, 15; 25, 30; 5, 20], 'Closed', true, ...
%!                  'UCS', U);
%! R = geom.Region (O, {[20, 10; 25, 10; 25, 15]});
%! assert_equal (R.UCS, U);
%! assert_equal (__area__ (R.Outline) > 0, true);

%!test  # chamfer and fillet leave the corners next to a spline
%! P = join (geom.Path ([0, 0; 40, 0; 40, 10]), ...
%!           geom.Spline ([40, 10; 20, 25; 0, 10]), geom.Path ([0, 10; 0, 0]));
%! R = geom.Region (P);
%! assert_equal (rows (fillet (R, 1).Outline.Vertices), 6);
%! assert_equal (rows (chamfer (R, 1).Outline.Vertices), 6);

%!error<geom.Region: HOLES\{1\} must lie strictly inside OUTLINE.> ...
%! geom.Region ([0, 0; 30, 0; 30, 30; 0, 30], ...
%!              {geom.Spline([20, 10; 35, 15; 20, 20], 'Closed', true)})
%!error<geom.Region: OUTLINE must not cross or touch itself.> ...
%! geom.Region (geom.Spline ([0, 0; 10, 10; 20, 0; 20, 10; 10, 0; 0, 10], ...
%!                           'Closed', true))
%!error<geom.Region: OUTLINE must be closed.> ...
%! geom.Region (geom.Spline ([0, 0; 10, 10; 20, 0]))
%!error<geom.Region: OUTLINE must lie in the plane of its UCS.> ...
%! geom.Region (geom.Path ([0, 0, 0; 10, 0, 0; 10, 10, 1], 'Closed', true))
%!error<geom.Region: HOLES\{1\} must lie in the plane of OUTLINE.> ...
%! geom.Region ([0, 0; 30, 0; 30, 30; 0, 30], ...
%!              {geom.Spline([10, 10, 0; 20, 10, 0; 15, 20, 1], ...
%!                           'Closed', true)})
%!error<geom.Region.chamfer: invalid number of input arguments.> ...
%! chamfer (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<geom.Region.chamfer: OUTLINE: D must be one positive finite distance, or two.> ...
%! chamfer (geom.Region ([0, 0; 1, 0; 1, 1]), 0)
%!error<geom.Region.chamfer: HOLES\{1\}: the chamfer at vertex 1 does not fit its segments.> ...
%! chamfer (geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                      {[20, 15; 24, 15; 24, 25; 20, 25]}), 3)

%!error<geom.Region.fillet: invalid number of input arguments.> ...
%! fillet (geom.Region ([0, 0; 1, 0; 1, 1]))
%!error<geom.Region.fillet: OUTLINE: RADIUS must be a positive and finite real scalar.> ...
%! fillet (geom.Region ([0, 0; 1, 0; 1, 1]), -1)
%!error<geom.Region.fillet: HOLES\{1\}: the round at vertex 1 does not fit its segments.> ...
%! fillet (geom.Region ([0, 0; 60, 0; 60, 40; 0, 40], ...
%!                      {[20, 15; 24, 15; 24, 25; 20, 25]}), 3)

%!error<geom.Region: invalid number of input arguments.> geom.Region ()
%!error<geom.Region: UCS must be a geom.UCS object.>
%! R = geom.Region ([0, 0; 1, 0; 1, 1]);
%! R.UCS = 1;
%!error<geom.Region: OUTLINE must be a closed geom.Polyline, geom.Path or geom.Spline, or a matrix of vertices.> ...
%! geom.Region ({[0, 0; 1, 0; 1, 1]})
%!error<geom.Region: OUTLINE: P must be an N-by-2 or N-by-3 real matrix of finite values with at least two rows.> ...
%! geom.Region ([0, 0])
%!error<geom.Region: OUTLINE must be closed.> ...
%! geom.Region (geom.Polyline ([0, 0; 1, 0; 1, 1]))
%!error<geom.Region: HOLES must be a cell array of holes.> ...
%! geom.Region ([0, 0; 10, 0; 10, 10], [1, 1; 2, 1; 2, 2])
%!error<geom.Region: HOLES\{1\} must be a closed geom.Polyline, geom.Path or geom.Spline, or a matrix of vertices.> ...
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
