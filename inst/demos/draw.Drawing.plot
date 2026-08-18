%!demo
%! ## `plot` renders a drawing at equal aspect, honouring layer, line
%! ## type and colour.  It plots what `entities` produces, which is what the
%! ## file backends write, so a figure shows what the recipient will get.
%!
%! D = draw.Drawing ('plate');
%! D.Layer = 'OUTLINE';
%! D = D.polyline ([0, 0; 80, 0; 80, 50; 0, 50], true);
%! D = D.circle ([20, 25], 8).circle ([60, 25], 8);
%! D.Layer = 'AXES';
%! D.Linetype = 'CENTER';
%! D.Colour = 'red';
%! D = D.centremark ();
%! D = D.line ([-8, 25], [88, 25]);
%! plot (D);
%! title ('a plate, its bores, and their centre lines');

%!demo
%! ## All seven line types render as themselves, because each run is cut into
%! ## its dashes rather than handed to one of the four styles a figure offers.
%!
%! D = draw.Drawing ();
%! y = 0;
%! for lt = draw.linetype ()
%!   D.Linetype = lt{1};
%!   D = D.line ([0, y], [70, y]);
%!   D.Linetype = 'CONTINUOUS';
%!   D = D.text ([74, y - 1], lt{1}, 2.5);
%!   y -= 8;
%! endfor
%! plot (D);
%! title ('CENTER, DASHDOT and PHANTOM stay distinguishable');

%!demo
%! ## An axes handle may lead, as for any plotting function, and `Layers`
%! ## draws only what was asked for --- useful for checking one layer at a time.
%!
%! D = draw.Drawing ();
%! D.Layer = 'PART';   D = D.circle ([0, 0], 20);
%! D.Layer = 'DIMS';   D = D.diam ([0, 0], 20);
%! figure ();
%! subplot (1, 2, 1);
%! plot (gca (), D);
%! title ('both layers');
%! subplot (1, 2, 2);
%! plot (gca (), D, 'Layers', {'PART'});
%! title ('the part alone');
