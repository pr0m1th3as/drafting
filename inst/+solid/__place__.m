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

## Internal helper.  Read the optional UCS and 'Anchor' option that place a
## primitive, and return the frame that places it.
##
## ARGS holds the arguments after the primitive's sizes: none, a geom.UCS, and
## for a primitive with more than one anchor, 'Anchor' and its name, with or
## without the UCS.  ANCHORS lists the anchors the primitive offers, its
## default first, and OFFSETS has one row for each, the point in the
## primitive's own coordinates that lands on the UCS origin.
##
## FRAME has the rows origin, x axis, y axis and normal of the frame that the
## primitive's own axes are laid on.  Returns an error message BODY in ERRMSG,
## empty when ARGS is valid; the caller emits the error under its own name.

function [FRAME, errmsg] = __place__ (ARGS, ANCHORS, OFFSETS)

  FRAME = [];
  errmsg = '';

  U = geom.UCS ();
  if (! isempty (ARGS) && (numel (ANCHORS) == 1 || ! ischar (ARGS{1})))
    U = ARGS{1};
    ARGS(1) = [];
    if (! isa (U, 'geom.UCS') || ! isscalar (U))
      errmsg = "U must be a geom.UCS object.";
      return;
    endif
  endif

  k = 1;
  if (! isempty (ARGS))
    if (numel (ARGS) != 2)
      errmsg = "Name/Value arguments must come in pairs.";
      return;
    endif
    if (! ischar (ARGS{1}) || ! strcmp (ARGS{1}, 'Anchor'))
      errmsg = "unknown parameter.";
      return;
    endif
    A = ARGS{2};
    if (ischar (A) && isrow (A))
      k = find (strcmp (A, ANCHORS));
    endif
    if (isempty (k) || ! (ischar (A) && isrow (A)))
      names = sprintf ("'%s', ", ANCHORS{:});
      names = names(1:end-2);
      p = find (names == ',', 1, 'last');
      errmsg = sprintf ("Anchor must be %s or%s.", names(1:p-1), ...
                        names(p+1:end));
      return;
    endif
  endif

  FRAME = [toworld(U, -OFFSETS(k,:)); U.XAxis; U.YAxis; U.Normal];

endfunction

%!test
%! assert_equal (solid.__place__ ({}, {'centroid'}, [0, 0, 0]), ...
%!               [0, 0, 0; 1, 0, 0; 0, 1, 0; 0, 0, 1]);

%!test
%! U = geom.UCS ([0, 0, 1], [1, 2, 3]);
%! F = solid.__place__ ({U, 'Anchor', 'base'}, {'corner', 'base'}, ...
%!                     [0, 0, 0; 5, 10, 0]);
%! assert_equal (F(1,:), [-4, -8, 3]);

%!test
%! [~, errmsg] = solid.__place__ ({'Anchor', 'top'}, ...
%!                                {'corner', 'base', 'centroid'}, zeros (3));
%! assert_equal (errmsg, "Anchor must be 'corner', 'base' or 'centroid'.");
