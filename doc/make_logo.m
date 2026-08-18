## Draw the drafting package logo with the drafting package.
##
## Writes drafting.png beside itself.  Kept as a script so the logo is
## reproducible: it is output of the package rather than an image drawn
## somewhere else, which is the point of it being this package's logo.

set (0, 'defaultfigurevisible', 'off');

P = [0, 0; 92, 0; 92, 62; 62, 62; 62, 40; 0, 40];

D = draw.Drawing ('drafting');
D = D.polyline (P, true);
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
