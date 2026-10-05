## Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>
##
## This file is part of the cycloidal package for GNU Octave.
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

## Draw the drafting package logo with the drafting package.
##
## Writes drafting.png beside itself.  Kept as a script so the logo is
## reproducible: it is output of the package rather than an image drawn
## somewhere else, which is the point of it being this package's logo.

pkg load drafting

set (0, 'defaultfigurevisible', 'off');

P = [0, 0; 92, 0; 92, 62; 62, 62; 62, 40; 0, 40];

D = draw.Drawing ('drafting');
D = D.polyline (geom.Polyline (P, 'Closed', true));
D = D.circle ([30, 20], 13);

D.Linetype = 'CENTER';
D.Colour = 'red';
D = D.centremark ();

D.Linetype = 'CONTINUOUS';
D.Colour = 'red';
## A single space as the label: the ticks and extension lines say "dimension"
## at this size, where a number would only be a smudge.
D = D.dim (P(1,:), P(2,:), -22, 'horizontal', ' ');
D = D.dim (P(2,:), P(3,:), -22, 'vertical', ' ');

f = figure ('visible', 'off');
ax = axes ('parent', f);
## DimScale enlarges the ornament, which is a model dimension, so the ticks
## still read at logo resolution.
plot (D, 'Axes', ax, 'LineWidth', 3.2, 'FontSize', 1, 'Margin', 0.05, ...
      'DimScale', 3);
axis (ax, 'off');
set (ax, 'position', [0, 0, 1, 1]);
set (f, 'paperunits', 'inches', 'papersize', [2.56, 2.56], ...
     'paperposition', [0, 0, 2.56, 2.56]);
fname = 'drafting.png';
print (f, fullfile (fileparts (mfilename ('fullpath')), fname), '-r100');
close (f);
