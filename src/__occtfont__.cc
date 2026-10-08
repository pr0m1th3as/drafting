// Copyright (C) 2026 Andreas Bertsatos <abertsatos@biol.uoa.gr>
//
// This file is part of the drafting package for GNU Octave.
//
// This program is free software; you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation; either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
// or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, see <http://www.gnu.org/licenses/>.

// The outlines of text as Open CASCADE builds them from a font.  The font
// builder is in Open CASCADE's visualization libraries, so this is an
// oct-file of its own, built where they are found, and __occt__ keeps to the
// modelling libraries.

#include <octave/oct.h>

#include <sstream>
#include <string>

#include <BRepBndLib.hxx>
#include <BRepBuilderAPI_Transform.hxx>
#include <BinTools.hxx>
#include <Bnd_Box.hxx>
#include <Font_FontAspect.hxx>
#include <Message.hxx>
#include <Message_Messenger.hxx>
#include <StdPrs_BRepFont.hxx>
#include <StdPrs_BRepTextBuilder.hxx>
#include <Standard_Failure.hxx>
#include <Standard_Version.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Trsf.hxx>

using std::string;

// The message of an Open CASCADE exception, which 8.0 made a std::exception
static const char *
failure (const Standard_Failure& e)
{
#if OCC_VERSION_MAJOR >= 8
  return e.what ();
#else
  return e.GetMessageString ();
#endif
}

// The box round S: left, bottom, right and top
static void
extent (const TopoDS_Shape& s, double& x0, double& y0, double& x1, double& y1)
{
  Bnd_Box b;
  BRepBndLib::Add (s, b);
  double z0, z1;
  b.Get (x0, y0, z0, x1, y1, z1);
}

// [DATA, BOX] = __occtfont__ (CALLER, STR, FONT, STYLE, HEIGHT, STRICT): the
// faces of the outlines of STR, UTF-8, in the font FONT of the style STYLE, 0
// regular, 1 bold, 2 italic, 3 bold italic, scaled so that a capital H is
// HEIGHT high, its baseline on y = 0 and the text starting at x = 0; as the
// bytes of the shape, and its box [left, bottom, right, top].  A font that
// is not found is an error when STRICT, and may fall to an alias otherwise.
DEFUN_DLD (__occtfont__, args, ,
           "-*- texinfo -*-\n\
@deftypefn {} {[@var{data}, @var{box}] =} __occtfont__ (@var{caller}, @dots{})\n\
Undocumented internal function.\n\
@end deftypefn")
{
  if (args.length () != 6)
  {
    print_usage ();
  }
  const string caller = args(0).string_value ();
  const string str = args(1).string_value ();
  const string name = args(2).string_value ();
  const int style = args(3).int_value ();
  const double height = args(4).double_value ();
  const bool strict = args(5).bool_value ();
  Message::DefaultMessenger ()->ChangePrinters ().Clear ();

  const Font_FontAspect aspect[] = {Font_FontAspect_Regular,
                                    Font_FontAspect_Bold,
                                    Font_FontAspect_Italic,
                                    Font_FontAspect_BoldItalic};
  TopoDS_Shape s;
  try
  {
    Handle (StdPrs_BRepFont) font
      = StdPrs_BRepFont::FindAndCreate (name.c_str (), aspect[style], 100,
                                        strict ? Font_StrictLevel_Strict
                                               : Font_StrictLevel_Aliases);
    if (font.IsNull ())
    {
      error ("%s: the font '%s' is not installed.", caller.c_str (),
             name.c_str ());
    }
    font->SetCompositeCurveMode (true);
    StdPrs_BRepTextBuilder builder;

    // A capital H gives the scale and the baseline
    const TopoDS_Shape H = builder.Perform (*font, NCollection_String ("H"));
    double hx0, hy0, hx1, hy1;
    extent (H, hx0, hy0, hx1, hy1);
    if (hy1 <= hy0)
    {
      error ("%s: the font '%s' has no capital H to size the text by.",
             caller.c_str (), name.c_str ());
    }
    s = builder.Perform (*font, NCollection_String (str.c_str ()));
    gp_Trsf t, u;
    t.SetTranslation (gp_Vec (0, -hy0, 0));
    u.SetScale (gp_Pnt (0, 0, 0), height / (hy1 - hy0));
    s = BRepBuilderAPI_Transform (s, u * t, true).Shape ();
  }
  catch (const Standard_Failure& e)
  {
    error ("%s: Open CASCADE could not build the text: %s", caller.c_str (),
           failure (e));
  }

  RowVector box (4, 0.0);
  uint8NDArray data (dim_vector (0, 0));
  if (! s.IsNull ())
  {
    Bnd_Box b;
    BRepBndLib::Add (s, b);
    if (! b.IsVoid ())
    {
      extent (s, box(0), box(1), box(2), box(3));
      std::ostringstream os;
      BinTools::Write (s, os, false, false,
                       BinTools_FormatVersion_CURRENT);
      const string bytes = os.str ();
      data = uint8NDArray (dim_vector (1, bytes.size ()));
      for (size_t i = 0; i < bytes.size (); i++)
      {
        data(i) = static_cast<unsigned char> (bytes[i]);
      }
    }
  }
  return ovl (data, box);
}
