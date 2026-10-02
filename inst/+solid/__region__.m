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


## Internal helper.  Hand a geom.Region to Open CASCADE.
##
## Returns an error message BODY in ERRMSG, empty when R is a scalar
## geom.Region; the caller emits the error under its own name, naming the
## argument NAME.  D is the struct __occt__ reads: the outline and a cell of
## the holes, each as solid.__path__ hands a path over, and the frame of the
## region's plane, rows origin, x axis, y axis and normal.  SPLINES is true
## when the outline or a hole has a spline in it.

function [errmsg, D, SPLINES] = __region__ (R, NAME)

  errmsg = '';
  D = [];
  SPLINES = false;
  if (! isa (R, 'geom.Region') || ! isscalar (R))
    errmsg = sprintf ("%s must be a geom.Region object.", NAME);
    return;
  endif
  D = __data__ (R);
  SPLINES = any (cellfun (@(P) any (! cellfun (@isempty, P.Splines)), ...
                          [{R.Outline}, R.Holes]));

endfunction

%!test
%! R = geom.Region ([0, 0; 10, 0; 10, 5], {[6, 1; 8, 1; 8, 2]});
%! [errmsg, D] = solid.__region__ (R, 'R');
%! assert_equal (errmsg, '');
%! assert_equal (D.outline.vertices, [0, 0, 0; 10, 0, 0; 10, 5, 0]);
%! assert_equal (D.outline.closed, true);
%! assert_equal (D.holes{1}.vertices, [6, 1, 0; 8, 2, 0; 8, 1, 0]);
%! assert_equal (D.frame, [0, 0, 0; 1, 0, 0; 0, 1, 0; 0, 0, 1]);

%!test  # a hole with a spline
%! H = geom.Spline ([5, 0.5; 8, 0.8; 7.5, 2.5], 'Closed', true);
%! [~, D, SPLINES] = solid.__region__ (geom.Region ([0, 0; 10, 0; 10, 5], ...
%!                                                  {H}), 'R');
%! assert_equal (SPLINES, true);
%! assert_equal (D.holes{1}.vertices, [5, 0.5, 0]);

%!test
%! assert_equal (solid.__region__ ([0, 0; 1, 0; 1, 1], 'R'), ...
%!               "R must be a geom.Region object.");
