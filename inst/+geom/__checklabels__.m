## Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>
##
## This file is part of the drafting package for GNU Octave.
##
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the Free
## Software Foundation; either version 3 of the License, or (at your option)
## any later version.
##
## This program is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
## or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
## more details.
##
## You should have received a copy of the GNU General Public License along
## with this program; if not, see <http://www.gnu.org/licenses/>.

## Internal helper.  Check the labels L given for the N segments of a path,
## polyline or region outline: a cell array of N names, each a valid Octave
## identifier as isvarname judges it or a keyword, or '' for a segment left
## unnamed.
## Returns L as a row, empty when every entry is '', and an error message
## body in ERRMSG, empty when L is valid; the caller emits the error under
## its own name.

function [errmsg, L] = __checklabels__ (L, N)

  errmsg = '';
  if (! iscellstr (L))
    errmsg = "Label must be a cell array of character vectors.";
    return;
  endif
  if (numel (L) != N)
    errmsg = sprintf ("Label must have one entry for each of the %d segments.",
                      N);
    return;
  endif
  is_empty = cellfun ('isempty', L);
  if (all (is_empty))
    L = cell (1, 0);
    return;
  endif
  given = L(! is_empty);
  valid = cellfun ('isvarname', given);
  ## A keyword fails isvarname only because it cannot name a variable,
  ## which a label never does; iskeyword is asked of those alone
  valid(! valid) = cellfun ('iskeyword', given(! valid));
  if (! all (valid))
    errmsg = strcat ("Label must contain valid identifiers, one for", ...
                     " each segment, or '' for a segment left unnamed.");
    return;
  endif
  if (! isrow (L))
    L = reshape (L, 1, []);
  endif

endfunction

%!test
%! [errmsg, L] = geom.__checklabels__ ({'web', '', 'flange'}, 3);
%! assert_equal (errmsg, '');
%! assert_equal (L, {'web', '', 'flange'});

%!test
%! [errmsg, L] = geom.__checklabels__ ({''; ''}, 2);
%! assert_equal (errmsg, '');
%! assert_equal (L, cell (1, 0));

%!test
%! [errmsg] = geom.__checklabels__ ({'web'}, 2);
%! assert_equal (errmsg, ...
%!               "Label must have one entry for each of the 2 segments.");

%!test
%! [errmsg, L] = geom.__checklabels__ ({'end', 'web'}, 2);
%! assert_equal (errmsg, '');
%! assert_equal (L, {'end', 'web'});

%!test
%! [errmsg] = geom.__checklabels__ ({'a.b'}, 1);
%! assert_equal (errmsg, strcat ("Label must contain valid identifiers,", ...
%!                               " one for each segment, or '' for a", ...
%!                               " segment left unnamed."));

%!test
%! [errmsg] = geom.__checklabels__ ('web', 1);
%! assert_equal (errmsg, "Label must be a cell array of character vectors.");
