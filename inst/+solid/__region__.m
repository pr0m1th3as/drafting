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
## argument NAME.  D is the struct __occt__ reads: the outline's vertices,
## a cell of the holes' vertices, and the frame of the region's plane, rows
## origin, x axis, y axis and normal.

function [errmsg, D] = __region__ (R, NAME)

  errmsg = '';
  D = [];
  if (! isa (R, 'geom.Region') || ! isscalar (R))
    errmsg = sprintf ("%s must be a geom.Region object.", NAME);
    return;
  endif
  O = R.Outline;
  D = struct ('outline', O.Vertices, ...
              'holes', {cellfun(@(h) h.Vertices, R.Holes, ...
                                'UniformOutput', false)}, ...
              'frame', [O.Origin; O.XAxis; O.YAxis; O.Normal]);

endfunction

%!test
%! R = geom.Region ([0, 0; 10, 0; 10, 5], {[6, 1; 8, 1; 8, 2]});
%! [errmsg, D] = solid.__region__ (R, 'R');
%! assert_equal (errmsg, '');
%! assert_equal (D.outline, [0, 0, 0; 10, 0, 0; 10, 5, 0]);
%! assert_equal (D.holes, {[6, 1, 0; 8, 2, 0; 8, 1, 0]});
%! assert_equal (D.frame, [0, 0, 0; 1, 0, 0; 0, 1, 0; 0, 0, 1]);

%!test
%! assert_equal (solid.__region__ ([0, 0; 1, 0; 1, 1], 'R'), ...
%!               "R must be a geom.Region object.");
