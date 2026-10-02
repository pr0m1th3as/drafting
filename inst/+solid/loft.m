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
## @deftypefn  {drafting} {@var{S} =} solid.loft (@var{P}, @var{Z})
## @deftypefnx {drafting} {@var{S} =} solid.loft (@var{P}, @var{Z}, @var{BULGE})
## @deftypefnx {drafting} {@var{S} =} solid.loft (@dots{}, @qcode{'Ruled'}, @var{TF})
##
## A solid passing through profiles at increasing heights.
##
## @code{@var{S} = solid.loft (@var{P}, @var{Z})} returns a
## @code{solid.Shape} whose section is the profile @code{@var{P}@{@var{k}@}}
## at the height @code{@var{Z}(@var{k})} millimetres, with a smooth surface
## between them.  This is how a transition is modelled: a duct from a
## rectangle to a circle, a tapering arm, a handle that swells in the middle.
##
## @var{P} is a cell array of at least two profiles and @var{Z} a vector of
## as many heights, strictly increasing.  Each profile is an @math{N}-by-2
## matrix of vertices in millimetres, drawn in the plane parallel to
## @math{xy} at its height, closed implicitly from the last vertex back to the
## first; it must enclose an area and must not cross or touch itself.  The
## profiles need not have the same number of vertices.  Their first vertices
## are joined to one another, and so are the vertices that follow, so a loft
## twists when its profiles do not start at corresponding points or do not
## run the same way round.
##
## @var{BULGE} is a cell array with one entry per profile, each giving one
## value per vertex as in @code{draw.Drawing.polyline}: the tangent of a
## quarter of the arc's included angle, zero for a straight segment and 1 for
## a semicircle, positive for an arc that runs anticlockwise.  An empty entry
## leaves that profile straight-sided.
##
## @code{@var{S} = solid.loft (@dots{}, @qcode{'Ruled'}, @var{TF})} joins
## consecutive profiles by straight lines when @var{TF} is @code{true}, so a
## loft between polygons has flat faces and a crease at every intermediate
## profile.  It is @code{false} by default, which passes one smooth surface
## through every profile.  With two profiles both give the same solid.
##
## @example
## @group
## ## A square of 20 at the base becoming a circle of diameter 12 at 30
## base = [-10, -10; 10, -10; 10, 10; -10, 10];
## top = [6, 0; -6, 0];
## S = solid.loft (@{base, top@}, [0, 30], @{[], [1, 1]@});
## @end group
## @end example
##
## @seealso{solid.extrude, solid.revolve, draw.Drawing.polyline}
## @end deftypefn

function S = loft (P, Z, varargin)

  ## Input validation
  if (nargin < 2)
    error ("solid.loft: invalid number of input arguments.");
  endif
  if (! iscell (P) || ! isvector (P) || numel (P) < 2)
    error ("solid.loft: P must be a cell array of at least two profiles.");
  endif
  if (! isnumeric (Z) || ! isreal (Z) || ! isvector (Z) ...
      || numel (Z) != numel (P) || ! all (isfinite (Z)))
    error ("solid.loft: Z must hold one finite real height per profile.");
  endif
  if (any (diff (Z) <= 0))
    error ("solid.loft: Z must be strictly increasing.");
  endif
  BULGE = cell (size (P));
  if (mod (numel (varargin), 2) != 0)
    BULGE = varargin{1};
    varargin(1) = [];
    if (! iscell (BULGE) || numel (BULGE) != numel (P))
      error (strcat ("solid.loft: BULGE must be a cell array with one", ...
                     " entry per profile."));
    endif
  endif
  opt = struct ('Ruled', false);
  known = fieldnames (opt);
  for k = 1:2:numel (varargin)
    name = varargin{k};
    if (! ischar (name) || ! isrow (name) || ! any (strcmp (name, known)))
      error ("solid.loft: unknown parameter.");
    endif
    opt.(name) = varargin{k+1};
  endfor
  if (! (islogical (opt.Ruled) || isnumeric (opt.Ruled)) ...
      || ! isscalar (opt.Ruled) || ! any (opt.Ruled == [0, 1]))
    error ("solid.loft: Ruled must be a logical scalar.");
  endif
  for k = 1:numel (P)
    [errmsg, P{k}, BULGE{k}] = solid.__checkprofile__ ...
                                 (P{k}, BULGE{k}, sprintf ("P{%d}", k), ...
                                  sprintf ("BULGE{%d}", k));
    if (! isempty (errmsg))
      error ("solid.loft: %s", errmsg);
    endif
  endfor
  errmsg = solid.__checkocct__ ();
  if (! isempty (errmsg))
    error ("solid.loft: %s", errmsg);
  endif

  S = solid.Shape (__occt__ ('loft', 'solid.loft', P(:)', BULGE(:)', ...
                             double (Z), logical (opt.Ruled)));

endfunction

%!testif ; exist ('__occt__') == 3  # a frustum of a square pyramid
%! P = {[0, 0; 10, 0; 10, 10; 0, 10], [2.5, 2.5; 7.5, 2.5; 7.5, 7.5; 2.5, 7.5]};
%! S = solid.loft (P, [0, 10]);
%! assert_equal (volume (S), 10 / 3 * (100 + 25 + 50), 1e-9);
%! assert_equal (bbox (S), [0, 0, 0, 10, 10, 10], 1e-6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # ruled through three, two frustums
%! sq = @(a) [-a, -a; a, -a; a, a; -a, a];
%! S = solid.loft ({sq(5), sq(3), sq(5)}, [0, 5, 10], 'Ruled', true);
%! assert_equal (volume (S), 2 * 5 / 3 * (100 + 36 + 60), 1e-9);
%! assert_equal (numfaces (S), 10);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # smooth through three, bulging outwards
%! sq = @(a) [-a, -a; a, -a; a, a; -a, a];
%! S = solid.loft ({sq(3), sq(5), sq(3)}, [0, 5, 10]);
%! assert_equal (volume (S) > 2 * 5 / 3 * (36 + 100 + 60), true);
%! assert_equal (numfaces (S), 6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # equal circles give a cylinder
%! c = [5, 0; -5, 0];
%! S = solid.loft ({c, c, c}, [0, 10, 20], {[1, 1], [1, 1], [1, 1]});
%! assert_equal (volume (S), 500 * pi, -1e-8);
%! assert_equal (bbox (S), [-5, -5, 0, 5, 5, 20], 1e-6);
%! assert_equal (isvalid (S), true);

%!testif ; exist ('__occt__') == 3  # a square becoming a circle
%! S = solid.loft ({[-10, -10; 10, -10; 10, 10; -10, 10], [6, 0; -6, 0]}, ...
%!                 [0, 30], {[], [1, 1]});
%! assert_equal (bbox (S), [-10, -10, 0, 10, 10, 30], 1e-6);
%! assert_equal (volume (S) > 30 / 3 * (400 + 36 * pi), true);
%! assert_equal (volume (S) < 30 * 400, true);
%! assert_equal (isvalid (S), true);

%!error<solid.loft: invalid number of input arguments.> solid.loft ({})
%!error<solid.loft: P must be a cell array of at least two profiles.> ...
%! solid.loft ([0, 0; 1, 0; 1, 1], [0, 1])
%!error<solid.loft: P must be a cell array of at least two profiles.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1]}, 0)
%!error<solid.loft: Z must hold one finite real height per profile.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1], [0, 0; 1, 0; 1, 1]}, [0, 1, 2])
%!error<solid.loft: Z must hold one finite real height per profile.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1], [0, 0; 1, 0; 1, 1]}, [0, Inf])
%!error<solid.loft: Z must be strictly increasing.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1], [0, 0; 1, 0; 1, 1]}, [1, 1])
%!error<solid.loft: BULGE must be a cell array with one entry per profile.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1], [0, 0; 1, 0; 1, 1]}, [0, 1], {[]})
%!error<solid.loft: BULGE must be a cell array with one entry per profile.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1], [0, 0; 1, 0; 1, 1]}, [0, 1], [0, 0, 0])
%!error<solid.loft: unknown parameter.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1], [0, 0; 1, 0; 1, 1]}, [0, 1], 'Smooth', 1)
%!error<solid.loft: Ruled must be a logical scalar.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1], [0, 0; 1, 0; 1, 1]}, [0, 1], 'Ruled', 2)
%!error<solid.loft: P\{2\} must enclose a nonzero area.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1], [0, 0; 1, 0; 2, 0]}, [0, 1])
%!error<solid.loft: BULGE\{1\} must hold one finite real value per row of P\{1\}.> ...
%! solid.loft ({[0, 0; 1, 0; 1, 1], [0, 0; 1, 0; 1, 1]}, [0, 1], {[1, 1], []})
