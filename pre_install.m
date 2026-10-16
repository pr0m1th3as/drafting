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

## On Windows, fetch the build of Open CASCADE made with this Octave's own
## compiler and unpack it into src/occt, where src/Makefile finds it and from
## where its DLLs install beside the oct files.  Nothing is fetched where Open
## CASCADE is already in Octave's mingw64 folder or OCCT_INC names one.

function pre_install (desc)

  if (! ispc ())
    return;
  endif
  hdr = fullfile (OCTAVE_HOME (), 'include', 'opencascade', ...
                  'Standard_Version.hxx');
  if (! isempty (getenv ('OCCT_INC')) || exist (hdr, 'file'))
    return;
  endif

  ## One build for each Octave release, since its DLLs need that Octave's
  ## own C++ runtime, and the SHA-256 checksum of each archive
  occt = '8.0.1';
  builds = {'11.1.0', ...
            'a344353a0677949d9b6856672992807a1c7064f18ee136b40b28e5029f5771e9';
            '11.3.0', ...
            '38207d6b65851bd05ef415d186b041477e0aac40b5850b6e9a3cafec9a3c2914'};
  idx = strcmp (builds(:,1), version ());
  if (! any (idx))
    error (strcat ("drafting: no build of Open CASCADE for Octave %s on", ...
                   " Windows; unpack Open CASCADE 7.8 or later into", ...
                   " Octave's mingw64 folder, or set OCCT_INC."), version ());
  endif
  dest = fullfile ('src', 'occt');
  if (exist (fullfile (dest, 'include', 'opencascade', ...
                       'Standard_Version.hxx'), 'file'))
    return;
  endif

  name = sprintf ('occt-%s-octave-%s-w64.tar.gz', occt, version ());
  url = sprintf (strcat ('https://github.com/pr0m1th3as/octave-ci/', ...
                         'releases/download/occt-%s/%s'), occt, name);
  file = fullfile ('src', name);
  printf ("drafting: fetching Open CASCADE %s for Octave %s\n", ...
          occt, version ());
  [~, ok, msg] = urlwrite (url, file);
  if (! ok)
    error ("drafting: Open CASCADE could not be fetched: %s", msg);
  endif
  fid = fopen (file, 'r');
  bytes = fread (fid, Inf, 'uint8=>char')';
  fclose (fid);
  if (! strcmp (hash ('sha256', bytes), builds{idx,2}))
    [~] = unlink (file);
    error ("drafting: the Open CASCADE archive is not the one expected.");
  endif
  untar (file, dest);
  [~] = unlink (file);

endfunction
