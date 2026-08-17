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
## @deftypefn  {drafting} {@var{Q} =} geom.transform (@var{P}, @var{T})
## @deftypefnx {drafting} {@var{Q} =} geom.transform (@var{P}, @var{OP}, @var{VAL})
## @deftypefnx {drafting} {@var{Q} =} geom.transform (@var{P}, @var{OP}, @var{VAL}, @var{CENTRE})
##
## Apply a planar transformation to a set of points.
##
## @code{@var{Q} = geom.transform (@var{P}, @var{T})} applies the 3-by-3
## homogeneous matrix @var{T} to every row of the @math{N}-by-2 matrix @var{P}
## and returns the result in the same shape.  @var{T} acts on column vectors
## @code{[x; y; 1]}, which is the usual convention, so transformations compose
## by ordinary matrix multiplication with the last-applied factor on the left.
##
## @code{@var{Q} = geom.transform (@var{P}, @var{OP}, @var{VAL})} builds the
## matrix from a named operation instead.  @var{OP} is one of:
##
## @itemize
## @item @qcode{'translate'} --- @var{VAL} is a 1-by-2 offset
## @code{[@var{dx}, @var{dy}]}.
##
## @item @qcode{'rotate'} --- @var{VAL} is an angle in @strong{degrees},
## counter-clockwise positive.  Degrees rather than radians because this is a
## drafting package and drawings are dimensioned in degrees.
##
## @item @qcode{'scale'} --- @var{VAL} is a scalar factor, or a 1-by-2 pair
## @code{[@var{sx}, @var{sy}]} for an anisotropic scaling.
##
## @item @qcode{'mirror'} --- @var{VAL} is @qcode{'x'} or @qcode{'y'}, naming
## the @emph{axis to reflect about}.  Mirroring about @qcode{'x'} negates the
## @math{y} coordinate, so the point @code{[1, 2]} becomes @code{[1, -2]}.
## @end itemize
##
## @code{@var{Q} = geom.transform (@var{P}, @var{OP}, @var{VAL}, @var{CENTRE})}
## performs the operation about the point @var{CENTRE} rather than the origin.
## It applies to @qcode{'rotate'}, @qcode{'scale'} and @qcode{'mirror'}; a
## translation is unaffected by any centre, so supplying one is an error rather
## than a silently ignored argument.
##
## Unlike most of this namespace, @code{geom.transform} accepts any point set,
## not only a polygon: two points making up a single edge are valid input.
##
## @seealso{geom.bbox, geom.offset}
## @end deftypefn

function Q = transform (P, varargin)

  ## Input validation
  if (nargin < 2 || nargin > 4)
    error ("geom.transform: invalid number of input arguments.");
  endif
  [errmsg, P] = geom.__checkpts__ (P);
  if (! isempty (errmsg))
    error ("geom.transform: %s", errmsg);
  endif

  ## Either an explicit matrix or a named operation
  if (ischar (varargin{1}))
    T = buildmatrix (varargin{:});
  else
    if (numel (varargin) != 1)
      error ("geom.transform: invalid number of input arguments.");
    endif
    T = varargin{1};
    if (! isnumeric (T) || ! isreal (T) || ! isequal (size (T), [3, 3]) ...
        || ! all (isfinite (T(:))))
      error ("geom.transform: T must be a real finite 3-by-3 matrix.");
    endif
  endif

  ## Promote to homogeneous coordinates, transform, and drop the weight.  T
  ## acts on columns, so transposing it lets the row-per-point layout stand.
  Q = [P, ones(rows (P), 1)] * T.';
  Q = Q(:,1:2);

endfunction

## Build the homogeneous matrix for a named operation.  Single consumer, so it
## lives here rather than in the namespace, and it raises under the name of the
## function the caller actually invoked.
function T = buildmatrix (OP, varargin)

  if (numel (varargin) < 1)
    error ("geom.transform: missing VAL for operation '%s'.", OP);
  endif

  VAL = varargin{1};
  hasCentre = numel (varargin) > 1;
  CENTRE = [0, 0];
  if (hasCentre)
    CENTRE = varargin{2};
    if (! isnumeric (CENTRE) || ! isreal (CENTRE) ...
        || ! isequal (size (CENTRE), [1, 2]) || ! all (isfinite (CENTRE)))
      error (strcat ("geom.transform: CENTRE must be a real finite", ...
                     " 1-by-2 vector."));
    endif
  endif

  switch (lower (OP))

    case 'translate'
      if (hasCentre)
        error (strcat ("geom.transform: 'translate' does not take a", ...
                       " CENTRE argument."));
      endif
      if (! isnumeric (VAL) || ! isreal (VAL) ...
          || ! isequal (size (VAL), [1, 2]) || ! all (isfinite (VAL)))
        error (strcat ("geom.transform: VAL must be a real finite 1-by-2", ...
                       " vector for 'translate'."));
      endif
      T = [1, 0, VAL(1); 0, 1, VAL(2); 0, 0, 1];
      return;

    case 'rotate'
      if (! isnumeric (VAL) || ! isreal (VAL) || ! isscalar (VAL) ...
          || ! isfinite (VAL))
        error (strcat ("geom.transform: VAL must be a real finite scalar", ...
                       " angle in degrees for 'rotate'."));
      endif
      M = [cosd(VAL), -sind(VAL), 0; sind(VAL), cosd(VAL), 0; 0, 0, 1];

    case 'scale'
      if (! isnumeric (VAL) || ! isreal (VAL) || ! all (isfinite (VAL(:))) ...
          || ! (isscalar (VAL) || isequal (size (VAL), [1, 2])))
        error (strcat ("geom.transform: VAL must be a real finite scalar", ...
                       " or 1-by-2 vector for 'scale'."));
      endif
      if (isscalar (VAL))
        VAL = [VAL, VAL];
      endif
      M = [VAL(1), 0, 0; 0, VAL(2), 0; 0, 0, 1];

    case 'mirror'
      if (! ischar (VAL) || ! isrow (VAL) || ! any (strcmpi (VAL, {'x', 'y'})))
        error (strcat ("geom.transform: VAL must be 'x' or 'y' for", ...
                       " 'mirror'."));
      endif
      if (strcmpi (VAL, 'x'))
        M = [1, 0, 0; 0, -1, 0; 0, 0, 1];
      else
        M = [-1, 0, 0; 0, 1, 0; 0, 0, 1];
      endif

    otherwise
      error ("geom.transform: unknown operation '%s'.", OP);

  endswitch

  ## Conjugate by a translation so the operation acts about CENTRE
  toOrigin = [1, 0, -CENTRE(1); 0, 1, -CENTRE(2); 0, 0, 1];
  fromOrigin = [1, 0, CENTRE(1); 0, 1, CENTRE(2); 0, 0, 1];
  T = fromOrigin * M * toOrigin;

endfunction

%!demo
%! ## The four named operations, each shown against the original.  A centre may
%! ## be given so the operation happens about a point rather than the origin.
%!
%! P = [0, 0; 30, 0; 30, 10; 10, 10; 10, 20; 0, 20];
%! D = draw.Drawing ().polyline (P, true);
%! D.Colour = 'red';
%! D = D.polyline (geom.transform (P, 'translate', [45, 0]), true);
%! D.Colour = 'blue';
%! D = D.polyline (geom.transform (P, 'rotate', 90, [15, 10]), true);
%! D.Colour = 'green';
%! D = D.polyline (geom.transform (P, 'scale', 0.5, [15, 10]), true);
%! D.Colour = 'magenta';
%! D = D.polyline (geom.transform (P, 'mirror', 'y'), true);
%! draw.plot (D);
%! title ('translate, rotate about a point, scale, mirror');

%!demo
%! ## A 3-by-3 homogeneous matrix does anything the named operations do and
%! ## composes by ordinary multiplication, last-applied on the left.
%!
%! P = [0, 0; 20, 0; 20, 10];
%! T = [1, 0, 50; 0, 1, 0; 0, 0, 1] * [0, -1, 0; 1, 0, 0; 0, 0, 1];
%! geom.transform (P, T)

%!test  # explicit matrix: translation
%! T = [1, 0, 10; 0, 1, 20; 0, 0, 1];
%! assert_equal (geom.transform ([1, 2; 3, 4], T), [11, 22; 13, 24], 1e-12);

%!test  # named translation agrees with the explicit matrix
%! P = [1, 2; 3, 4];
%! T = [1, 0, 10; 0, 1, 20; 0, 0, 1];
%! assert_equal (geom.transform (P, 'translate', [10, 20]), ...
%!               geom.transform (P, T), 1e-12);

%!test  # rotation is in degrees and counter-clockwise
%! assert_equal (geom.transform ([1, 0], 'rotate', 90), [0, 1], 1e-12);
%! assert_equal (geom.transform ([1, 0], 'rotate', 180), [-1, 0], 1e-12);
%! assert_equal (geom.transform ([1, 0], 'rotate', -90), [0, -1], 1e-12);

%!test  # rotation about a centre leaves that centre fixed
%! C = [5, 7];
%! assert_equal (geom.transform (C, 'rotate', 37, C), C, 1e-12);

%!test  # four 90-degree rotations are the identity
%! P = [0, 0; 4, 0; 4, 3; 0, 3];
%! Q = P;
%! for ii = 1:4
%!   Q = geom.transform (Q, 'rotate', 90);
%! endfor
%! assert_equal (Q, P, 1e-9);

%!test  # isotropic and anisotropic scaling
%! assert_equal (geom.transform ([2, 3], 'scale', 2), [4, 6], 1e-12);
%! assert_equal (geom.transform ([2, 3], 'scale', [2, 10]), [4, 30], 1e-12);

%!test  # scaling about a centre leaves that centre fixed
%! C = [100, 200];
%! assert_equal (geom.transform (C, 'scale', 3, C), C, 1e-12);

%!test  # mirroring names the axis reflected about
%! assert_equal (geom.transform ([1, 2], 'mirror', 'x'), [1, -2], 1e-12);
%! assert_equal (geom.transform ([1, 2], 'mirror', 'y'), [-1, 2], 1e-12);

%!test  # mirroring twice is the identity
%! P = [0, 0; 4, 0; 4, 3];
%! assert_equal (geom.transform (geom.transform (P, 'mirror', 'x'), ...
%!                               'mirror', 'x'), P, 1e-12);

%!test  # mirroring about a centre line holds that line fixed
%! P = [3, 50; 9, 50];
%! assert_equal (geom.transform (P, 'mirror', 'x', [0, 50]), P, 1e-12);

%!test  # a mirror reverses polygon orientation, a rotation does not
%! P = [0, 0; 4, 0; 4, 3; 0, 3];
%! Q = geom.transform (P, 'mirror', 'x');
%! assert_equal (sign (geom.signedarea (Q)), -1);
%! assert_equal (sign (geom.signedarea (geom.transform (P, 'rotate', 30))), 1);

%!test  # rotation preserves area, scaling multiplies it by the determinant
%! P = [0, 0; 4, 0; 4, 3; 0, 3];
%! A = geom.signedarea (P);
%! assert_equal (geom.signedarea (geom.transform (P, 'rotate', 30)), A, 1e-9);
%! assert_equal (geom.signedarea (geom.transform (P, 'scale', [2, 3])), ...
%!               6 * A, 1e-9);

%!test  # the operation name is case-insensitive
%! assert_equal (geom.transform ([1, 2], 'TRANSLATE', [1, 1]), [2, 3], 1e-12);

%!error<geom.transform: invalid number of input arguments.> ...
%! geom.transform ([1, 2])
%!error<geom.transform: invalid number of input arguments.> ...
%! geom.transform ([1, 2], eye (3), 1)
%!error<geom.transform: P must be an N-by-2 matrix of point coordinates.> ...
%! geom.transform ([1, 2, 3], eye (3))
%!error<geom.transform: T must be a real finite 3-by-3 matrix.> ...
%! geom.transform ([1, 2], eye (2))
%!error<geom.transform: T must be a real finite 3-by-3 matrix.> ...
%! geom.transform ([1, 2], Inf (3))
%!error<geom.transform: missing VAL for operation 'rotate'.> ...
%! geom.transform ([1, 2], 'rotate')
%!error<geom.transform: unknown operation 'shear'.> ...
%! geom.transform ([1, 2], 'shear', 1)
%!error<geom.transform: 'translate' does not take a CENTRE argument.> ...
%! geom.transform ([1, 2], 'translate', [1, 1], [0, 0])
%!error<geom.transform: VAL must be a real finite 1-by-2 vector for 'translate'.> ...
%! geom.transform ([1, 2], 'translate', 5)
%!error<geom.transform: VAL must be a real finite scalar angle in degrees for 'rotate'.> ...
%! geom.transform ([1, 2], 'rotate', [1, 2])
%!error<geom.transform: VAL must be a real finite scalar or 1-by-2 vector for 'scale'.> ...
%! geom.transform ([1, 2], 'scale', [1, 2, 3])
%!error<geom.transform: VAL must be 'x' or 'y' for 'mirror'.> ...
%! geom.transform ([1, 2], 'mirror', 'z')
%!error<geom.transform: CENTRE must be a real finite 1-by-2 vector.> ...
%! geom.transform ([1, 2], 'rotate', 90, [0, 0, 0])
